import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/nest_destination.dart';
import '../models/nest_item.dart';
import '../models/nest_transfer.dart';
import '../models/nest_transfer_mode.dart';

/// Quem mexe nos arquivos pelo Nest.
///
/// Interface, como os repositórios do projeto, e pelo mesmo motivo prático: um
/// teste de widget roda num relógio falso, onde a resposta de uma leitura de
/// disco **nunca chega** — o teste do painel trava esperando o tamanho de um
/// arquivo. Com o contrato aqui, a tela é verificada contra uma imitação em
/// memória e o disco de verdade é assunto do teste do [LocalNestFileService].
abstract interface class NestFileService {
  /// Lê o que o cartão precisa mostrar. `null` quando não há nada no caminho.
  Future<NestItem?> inspect(String path);

  Future<bool> exists(String path);

  /// Manda os itens para o destino, um a um.
  Future<NestTransfer> send({
    required List<NestItem> items,
    required NestDestination destination,
    required NestTransferMode mode,
  });

  /// Desfaz o que [send] fez, e devolve quantos itens voltaram.
  Future<int> undo(NestTransfer transfer);
}

/// A implementação sobre o sistema de arquivos.
///
/// Fica fora do ViewModel pelo motivo de sempre — a regra da casa é que
/// nenhuma lógica de negócio mora em widget, e aqui vale duas vezes: copiar e
/// mover arquivo tem três casos que só aparecem em produção e precisam de teste
/// próprio, sem tela nenhuma em volta.
///
/// Os três:
///
/// - **Nome já ocupado no destino.** Sobrescrever seria perder um arquivo sem
///   perguntar, então o arquivo chega como `contrato 2.pdf`, do mesmo jeito que
///   o Finder resolve. É também por isso que [NestMovement] guarda os dois
///   caminhos: o destino não se deriva da origem.
/// - **Mover entre volumes diferentes.** O `rename` do sistema não atravessa
///   volume — falha com `EXDEV` —, e é justamente o caso de arrastar do pen
///   drive para o Mac. O plano de queda é copiar e apagar.
/// - **Pasta com conteúdo.** `File.copy` não existe para diretório; a árvore é
///   percorrida à mão.
class LocalNestFileService implements NestFileService {
  LocalNestFileService({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// Quantos sufixos tentar antes de desistir de achar um nome livre.
  ///
  /// Um teto qualquer é melhor que um laço sem fim: se mil `contrato N.pdf`
  /// existem na pasta, o problema não é o nome.
  static const _maxNameAttempts = 1000;

  /// Lê do disco o que o cartão precisa mostrar.
  ///
  /// Devolve `null` quando não há nada naquele caminho — quem chama decide se
  /// isso é um item que não entra na prateleira ou um que acabou de sumir dela.
  @override
  Future<NestItem?> inspect(String path) async {
    final stat = await FileStat.stat(path);
    if (stat.type == FileSystemEntityType.notFound) return null;

    final isDirectory = stat.type == FileSystemEntityType.directory;

    return NestItem(
      path: path,
      isDirectory: isDirectory,
      // Medir uma pasta é percorrê-la inteira, e o cartão mostra "Pasta" no
      // lugar do número — não há para que pagar a caminhada.
      sizeInBytes: isDirectory ? 0 : stat.size,
      modifiedAt: stat.modified,
    );
  }

  @override
  Future<bool> exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  /// Manda os itens para o destino, um a um.
  ///
  /// Um a um, e não tudo ou nada: nove arquivos chegarem e um falhar é melhor
  /// que os dez ficarem parados porque um sumiu enquanto esperava. O que falhou
  /// volta em [NestTransfer.failures], com o motivo em português.
  @override
  Future<NestTransfer> send({
    required List<NestItem> items,
    required NestDestination destination,
    required NestTransferMode mode,
  }) async {
    final folder = Directory(destination.path);

    if (!await folder.exists()) {
      return NestTransfer(
        at: _now(),
        mode: mode,
        destinationPath: destination.path,
        failures: [
          for (final item in items)
            NestFailure(path: item.path, reason: 'a pasta de destino sumiu'),
        ],
      );
    }

    final movements = <NestMovement>[];
    final failures = <NestFailure>[];

    for (final item in items) {
      try {
        final target = await _place(item, folder, mode);
        movements.add(NestMovement(source: item.path, destination: target));
      } on _NestFileError catch (error) {
        failures.add(NestFailure(path: item.path, reason: error.reason));
      } on FileSystemException catch (error) {
        failures.add(NestFailure(path: item.path, reason: _describe(error)));
      }
    }

    return NestTransfer(
      at: _now(),
      mode: mode,
      destinationPath: destination.path,
      movements: movements,
      failures: failures,
    );
  }

  /// Desfaz o que [send] fez, e devolve quantos itens voltaram.
  ///
  /// Uma transferência movida volta para a origem; uma copiada tem as cópias
  /// apagadas. Apagar aqui é seguro porque o arquivo foi criado por nós, num
  /// nome que estava livre — nunca por cima de algo que já existia.
  ///
  /// Na ordem inversa da ida, para que dois arquivos de mesmo nome voltem cada
  /// um ao seu lugar: o segundo virou `nome 2.pdf` justamente porque o primeiro
  /// estava lá.
  @override
  Future<int> undo(NestTransfer transfer) async {
    var restored = 0;

    for (final movement in transfer.movements.reversed) {
      try {
        if (transfer.mode == NestTransferMode.move) {
          await _restore(movement);
        } else {
          await _discard(movement.destination);
        }
        restored++;
      } on FileSystemException {
        // O arquivo já foi mexido por fora desde a transferência. Desfazer é
        // uma cortesia, não uma promessa: o que der para voltar volta, e o
        // resto fica onde está, sem derrubar os outros.
      }
    }

    return restored;
  }

  Future<String> _place(
    NestItem item,
    Directory folder,
    NestTransferMode mode,
  ) async {
    if (!await exists(item.path)) {
      throw const _NestFileError('não está mais no lugar');
    }

    final target = await _freeNameIn(folder.path, p.basename(item.path));

    if (mode == NestTransferMode.move) {
      await _move(item.path, target, isDirectory: item.isDirectory);
    } else {
      await _copy(item.path, target, isDirectory: item.isDirectory);
    }

    return target;
  }

  Future<void> _move(
    String source,
    String target, {
    required bool isDirectory,
  }) async {
    try {
      if (isDirectory) {
        await Directory(source).rename(target);
      } else {
        await File(source).rename(target);
      }
    } on FileSystemException catch (error) {
      if (!_isCrossDevice(error)) rethrow;

      // Volumes diferentes: o sistema não renomeia através deles. Copiar e
      // apagar é o que o Finder faz, e nesta ordem — se a cópia falhar, o
      // original ainda está lá.
      await _copy(source, target, isDirectory: isDirectory);
      await _delete(source, isDirectory: isDirectory);
    }
  }

  Future<void> _copy(
    String source,
    String target, {
    required bool isDirectory,
  }) async {
    if (!isDirectory) {
      await File(source).copy(target);
      return;
    }

    await _copyTree(Directory(source), Directory(target));
  }

  Future<void> _copyTree(Directory source, Directory target) async {
    await target.create(recursive: true);

    await for (final entity in source.list(followLinks: false)) {
      final destination = p.join(target.path, p.basename(entity.path));

      if (entity is Directory) {
        await _copyTree(entity, Directory(destination));
      } else if (entity is File) {
        await entity.copy(destination);
      } else if (entity is Link) {
        // O atalho é copiado como atalho: resolver o alvo transformaria um
        // apontador de 4 KB na coisa apontada, que pode ser uma biblioteca
        // inteira.
        await Link(destination).create(await entity.target());
      }
    }
  }

  Future<void> _delete(String path, {required bool isDirectory}) async {
    if (isDirectory) {
      await Directory(path).delete(recursive: true);
      return;
    }

    await File(path).delete();
  }

  /// Leva o arquivo de volta para onde estava.
  ///
  /// Se alguma coisa ocupou o lugar da origem nesse meio-tempo, o arquivo volta
  /// para a mesma pasta com o nome livre seguinte — voltar ao lado do impostor
  /// é melhor que não voltar, e melhor ainda que apagá-lo.
  Future<void> _restore(NestMovement movement) async {
    final isDirectory =
        await FileSystemEntity.type(movement.destination, followLinks: false) ==
        FileSystemEntityType.directory;

    final target = await exists(movement.source)
        ? await _freeNameIn(
            p.dirname(movement.source),
            p.basename(movement.source),
          )
        : movement.source;

    await _move(movement.destination, target, isDirectory: isDirectory);
  }

  Future<void> _discard(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;

    await _delete(path, isDirectory: type == FileSystemEntityType.directory);
  }

  /// O primeiro nome livre na pasta, no estilo do Finder: `contrato.pdf`,
  /// `contrato 2.pdf`, `contrato 3.pdf`.
  Future<String> _freeNameIn(String folder, String name) async {
    var candidate = p.join(folder, name);
    if (!await exists(candidate)) return candidate;

    final extension = p.extension(name);
    final stem = name.substring(0, name.length - extension.length);

    for (var index = 2; index < _maxNameAttempts; index++) {
      candidate = p.join(folder, '$stem $index$extension');
      if (!await exists(candidate)) return candidate;
    }

    throw const _NestFileError('a pasta já tem arquivos demais com esse nome');
  }

  /// `EXDEV` — a origem e o destino estão em volumes diferentes.
  static bool _isCrossDevice(FileSystemException error) =>
      error.osError?.errorCode == 18;

  static String _describe(FileSystemException error) =>
      switch (error.osError?.errorCode) {
        2 => 'não está mais no lugar',
        13 => 'sem permissão',
        28 => 'não há espaço no destino',
        30 => 'o destino é somente leitura',
        _ => 'o sistema recusou',
      };
}

/// Recusa nossa, não do sistema — já vem com a frase que a tela mostra.
class _NestFileError implements Exception {
  const _NestFileError(this.reason);

  final String reason;
}

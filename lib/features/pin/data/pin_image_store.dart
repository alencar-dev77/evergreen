import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../models/pin_image.dart';
import 'clipboard_repository.dart';

/// A pasta onde moram as imagens copiadas no Pin.
///
/// Interface pelo motivo do `EchoAudioStore` e do `NestFileService`: teste de
/// widget roda no relógio falso do binding, e nele uma conversa assíncrona com
/// o disco nunca termina. A implementação de verdade é síncrona de propósito.
abstract interface class PinImageStore {
  /// Guarda a imagem e devolve o que a linha do histórico precisa saber dela.
  ///
  /// Copiar de novo a mesma imagem cai no mesmo arquivo (o nome é o hash do
  /// conteúdo), e ele não é escrito outra vez.
  PinImage save(CapturedImage image);

  /// O caminho absoluto de um arquivo — é o que vai ao nativo para colar.
  String pathOf(String fileName);

  bool exists(String fileName);

  /// O que a tela desenha, decodificada no tamanho em que vai aparecer.
  ///
  /// [cacheWidth] reduz pela largura — a miniatura, que recorta no quadrado.
  /// [fitWithin] cabe a imagem inteira num quadrado desse lado — o preview: só
  /// pela largura, uma captura de página inteira (1200×20000) decodificaria
  /// na altura cheia, quase 100 MB de memória para um cartão de 300 pontos.
  ImageProvider providerOf(String fileName, {int? cacheWidth, int? fitWithin});

  void delete(String fileName);

  /// Os nomes que estão na pasta agora.
  List<String> list();
}

/// A pasta `Pin/Imagens`, ao lado de `Reuniões`, `Backups` e `Exportações`.
///
/// Dentro da pasta do aplicativo pelo mesmo motivo das outras: ali o macOS não
/// pede permissão. E **fora do banco** — o backup é uma cópia do banco, e as
/// imagens não entram nele.
class LocalPinImageStore implements PinImageStore {
  LocalPinImageStore(this.directory);

  final Directory directory;

  @override
  PinImage save(CapturedImage image) {
    final file = File(pathOf(image.fileName));
    if (!file.existsSync()) {
      directory.createSync(recursive: true);
      file.writeAsBytesSync(image.bytes, flush: true);
    }

    return image.toImage();
  }

  @override
  String pathOf(String fileName) => p.join(directory.path, fileName);

  @override
  bool exists(String fileName) => File(pathOf(fileName)).existsSync();

  @override
  ImageProvider providerOf(
    String fileName, {
    int? cacheWidth,
    int? fitWithin,
  }) => sizedProvider(
    FileImage(File(pathOf(fileName))),
    cacheWidth: cacheWidth,
    fitWithin: fitWithin,
  );

  @override
  void delete(String fileName) {
    final file = File(pathOf(fileName));
    if (file.existsSync()) file.deleteSync();
  }

  @override
  List<String> list() {
    if (!directory.existsSync()) return const [];

    return [
      for (final entity in directory.listSync())
        if (entity is File) p.basename(entity.path),
    ];
  }
}

/// [provider] decodificado no tamanho pedido — ver
/// [PinImageStore.providerOf]. Compartilhado com a imitação do teste.
ImageProvider sizedProvider(
  ImageProvider provider, {
  int? cacheWidth,
  int? fitWithin,
}) {
  if (fitWithin != null) {
    return ResizeImage(
      provider,
      width: fitWithin,
      height: fitWithin,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }
  if (cacheWidth != null) {
    return ResizeImage(provider, width: cacheWidth, allowUpscaling: false);
  }
  return provider;
}

/// Quem apaga a imagem que ficou sem linha.
///
/// A regra do áudio do Echo: **arquivo que nenhuma linha quer é lixo**.
/// Apagar o item, o teto do histórico e o "Limpar histórico" só apagam a
/// linha; o arquivo sai na varredura seguinte. Ninguém precisa lembrar de
/// apagar a imagem em cada um desses caminhos.
class PinImageJanitor {
  const PinImageJanitor({
    required ClipboardRepository repository,
    required PinImageStore store,
  }) : _repository = repository,
       _store = store;

  final ClipboardRepository _repository;
  final PinImageStore _store;

  void sweep() {
    final wanted = _repository.imageFiles();

    for (final name in _store.list()) {
      if (!wanted.contains(name)) _store.delete(name);
    }
  }
}

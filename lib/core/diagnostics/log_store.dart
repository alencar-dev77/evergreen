import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Onde o registro de erros do Evergreen é escrito.
///
/// Interface pelo mesmo motivo do `NestFileService`: teste de widget roda no
/// relógio falso do binding, onde a resposta de uma leitura de disco **nunca
/// chega**, e a tela que espera pelas últimas linhas trava sem erro. O disco de
/// verdade é assunto do teste do [LocalLogStore].
abstract interface class LogStore {
  /// Acrescenta um bloco de texto já formatado. Nunca lança: o registro existe
  /// para quando as coisas dão errado, e ele próprio dar errado não pode
  /// derrubar mais nada.
  void append(String text);

  /// As últimas [count] linhas, da mais antiga para a mais nova.
  Future<List<String>> tail(int count);

  /// Abre a pasta do registro no Finder.
  Future<void> reveal();

  /// O caminho da pasta como se escreve para uma pessoa (`~/Library/…`).
  String get directoryLabel;
}

/// O registro em arquivo, com rotação por tamanho.
///
/// `evergreen.log` é o arquivo da vez; ao passar de [maxBytes] ele vira
/// `evergreen.1.log`, o `.1` vira `.2`, e o que passar de [keep] arquivos sai.
/// Três de 1 MB guardam meses de erro de um app que normalmente não erra, e
/// nunca crescem a ponto de aparecer em "Espaço em disco".
///
/// **Só um engine roda a rotação** ([rotates]): a janela 0 e o Hub escrevem no
/// mesmo arquivo, e dois isolates renomeando ao mesmo tempo perderiam linhas.
/// O Hub só acrescenta, até o dobro de [maxBytes] — se a janela 0 renomeou o
/// arquivo no meio, a próxima linha dele abre o arquivo novo pelo caminho,
/// que é o que se quer. As linhas
/// são escritas com `append` de uma vez só, e o macOS não intercala escritas
/// pequenas em modo de acréscimo.
class LocalLogStore implements LogStore {
  LocalLogStore({
    required Directory directory,
    this.rotates = true,
    this.maxBytes = 1024 * 1024,
    this.keep = 3,
  }) : _directory = directory;

  final Directory _directory;
  final bool rotates;
  final int maxBytes;
  final int keep;

  static const _baseName = 'evergreen';

  Directory get directory => _directory;

  File _fileAt(int index) => File(
    p.join(
      _directory.path,
      index == 0 ? '$_baseName.log' : '$_baseName.$index.log',
    ),
  );

  @override
  String get directoryLabel {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return _directory.path;

    return _directory.path.startsWith(home)
        ? '~${_directory.path.substring(home.length)}'
        : _directory.path;
  }

  /// Síncrono de propósito: um erro registrado logo antes de o processo cair
  /// precisa estar no disco quando ele cair, e uma escrita assíncrona ainda
  /// estaria na fila.
  @override
  void append(String text) {
    try {
      _directory.createSync(recursive: true);
      final current = _fileAt(0);
      if (current.existsSync()) {
        final size = current.lengthSync();
        final fits = size + utf8.encode(text).length <= maxBytes;
        if (rotates && size > 0 && !fits) _rotate();
        // Quem não roda tem teto: um laço de erro no Hub com a janela 0
        // calada faria o arquivo crescer sem fim. Acima do dobro, ele espera
        // a janela 0 rodar — a próxima linha dela abre espaço.
        if (!rotates && size > maxBytes * 2) return;
      }
      current.writeAsStringSync(text, mode: FileMode.append);
    } on FileSystemException {
      // Disco cheio, pasta sem permissão: perde-se a linha, e só ela.
    }
  }

  void _rotate() {
    final oldest = _fileAt(keep - 1);
    if (oldest.existsSync()) oldest.deleteSync();

    for (var index = keep - 2; index >= 0; index--) {
      final file = _fileAt(index);
      if (file.existsSync()) file.renameSync(_fileAt(index + 1).path);
    }
  }

  @override
  Future<List<String>> tail(int count) async {
    final lines = <String>[];

    // Do arquivo da vez para os antigos, até juntar o bastante: logo depois
    // de uma rotação, o atual tem duas linhas e a história está no `.1`.
    for (var index = 0; index < keep && lines.length < count; index++) {
      final file = _fileAt(index);
      if (!file.existsSync()) continue;

      final content = await file.readAsLines();
      lines.insertAll(0, content.where((line) => line.isNotEmpty));
    }

    return lines.length <= count ? lines : lines.sublist(lines.length - count);
  }

  /// `open` do próprio macOS, como o "Mostrar no Finder" dos backups. A pasta
  /// é criada antes, porque pedir ao Finder uma pasta que não existe abre um
  /// alerta de erro no lugar dela.
  @override
  Future<void> reveal() async {
    _directory.createSync(recursive: true);
    await Process.run('open', [_directory.path]);
  }
}

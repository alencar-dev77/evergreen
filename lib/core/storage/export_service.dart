import 'dart:io';

import 'package:path/path.dart' as p;

/// Um texto do Evergreen escrito num arquivo, para sair daqui.
///
/// Genérico de propósito: hoje quem usa é o Echo (o resumo e a transcrição de
/// uma reunião), e o Focus tem o mesmo problema à espera. O que o serviço sabe
/// é escrever um texto com um nome livre numa pasta e mostrar o arquivo no
/// Finder; **o que** vai dentro é assunto de quem chama.
///
/// Isto não contradiz a regra de que o Evergreen não traduz os dados dele para
/// ninguém. A exportação em JSON que saiu era o banco inteiro virado um segundo
/// formato, escrito sem ninguém pedir, para um programa que nunca apareceu.
/// Aqui é um documento por vez, pedido no botão, do texto que está na tela — e
/// nada disto é lido de volta pelo aplicativo.
///
/// Interface pelo mesmo motivo do `NestFileService`: teste de widget roda no
/// relógio falso do binding, onde a resposta de uma escrita em disco **nunca
/// chega**, e a tela que espera por ela trava sem erro e sem mensagem. O disco
/// de verdade é assunto do teste do [LocalExportService].
abstract interface class ExportService {
  /// Escreve [content] em `<baseName>.<extension>` e devolve o arquivo criado.
  ///
  /// O nome é **escolhido livre**, nunca sobrescrito: exportar a mesma reunião
  /// duas vezes depois de refazer o resumo deixa as duas versões na pasta, e é
  /// justamente para comparar uma com a outra que se refaz um resumo.
  Future<File> write({
    required String baseName,
    required String content,
    String extension,
    bool reveal,
  });

  /// Mostra o arquivo no Finder, selecionado dentro da pasta.
  Future<void> reveal(String path);

  /// O caminho da pasta como se escreve para uma pessoa (`~/Library/…`).
  String get directoryLabel;
}

/// A implementação sobre o sistema de arquivos.
///
/// **A pasta fica dentro do aplicativo, e o Finder é a interface.** Mesma razão
/// dos backups: `~/Documents` e `~/Downloads` fazem o macOS pedir permissão, e
/// um "salvar como" de verdade (`NSSavePanel`) seria código nativo novo para
/// resolver o que abrir o Finder já resolve. Como a pasta é funda demais para
/// alguém achá-la sozinho, [write] termina **mostrando o arquivo** — é o que
/// completa a ação, e de lá a pessoa arrasta para onde quiser.
class LocalExportService implements ExportService {
  LocalExportService({required Directory directory}) : _directory = directory;

  final Directory _directory;

  Directory get directory => _directory;

  @override
  String get directoryLabel {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return _directory.path;

    return _directory.path.startsWith(home)
        ? '~${_directory.path.substring(home.length)}'
        : _directory.path;
  }

  @override
  Future<File> write({
    required String baseName,
    required String content,
    String extension = 'md',
    bool reveal = true,
  }) async {
    _directory.createSync(recursive: true);

    final file = _freeNameFor(baseName, extension);
    await file.writeAsString(content);

    if (reveal) await this.reveal(file.path);

    return file;
  }

  /// `open -R` do próprio macOS, como o `reveal` do backup: é uma linha de
  /// processo e o Evergreen não roda em sandbox (ver `Release.entitlements`).
  @override
  Future<void> reveal(String path) => Process.run('open', ['-R', path]);

  /// `nome.md`, `nome-2.md`, `nome-3.md`…
  File _freeNameFor(String baseName, String extension) {
    var file = File(p.join(_directory.path, '$baseName.$extension'));
    var attempt = 2;

    while (file.existsSync()) {
      file = File(p.join(_directory.path, '$baseName-$attempt.$extension'));
      attempt++;
    }

    return file;
  }
}

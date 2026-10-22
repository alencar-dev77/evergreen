import 'dart:io';

/// Quem acha o LM Studio no disco e liga o servidor dele.
///
/// **O Evergreen nunca liga o servidor sozinho**: este é o único ponto em que
/// ele abre o processo de outro programa, e só quando a pessoa clica em
/// "Ligar". Interface pelo motivo do `NestFileService` — no relógio falso do
/// teste de widget a resposta de um processo nunca chega.
abstract interface class LmStudioLauncher {
  /// O `lms` existe nesta máquina?
  bool get isInstalled;

  /// Roda `lms server start` e devolve se ele disse que deu certo.
  Future<bool> startServer();
}

/// O `lms` de verdade, em `~/.lmstudio/bin/lms` — onde o LM Studio o instala.
class ProcessLmStudioLauncher implements LmStudioLauncher {
  const ProcessLmStudioLauncher();

  static String? get _path {
    final home = Platform.environment['HOME'];
    return home == null ? null : '$home/.lmstudio/bin/lms';
  }

  @override
  bool get isInstalled {
    final path = _path;
    return path != null && File(path).existsSync();
  }

  @override
  Future<bool> startServer() async {
    final path = _path;
    if (path == null) return false;

    try {
      final result = await Process.run(path, const [
        'server',
        'start',
      ]).timeout(const Duration(seconds: 30));
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }
}

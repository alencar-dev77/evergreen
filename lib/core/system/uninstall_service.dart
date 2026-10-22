import 'package:flutter/services.dart';

import '../diagnostics/app_log.dart';

/// Tira o Evergreen da máquina: dos Ajustes do Sistema, do disco e da pasta
/// Aplicativos.
///
/// Interface pelo motivo do `NestFileService`: a tela que pede a confirmação é
/// testada com uma imitação, e a de verdade **encerra o processo** — um teste
/// que a chamasse levaria a suíte junto.
abstract interface class UninstallService {
  /// Apaga tudo e encerra. Quando dá certo, não volta: o processo termina do
  /// lado nativo. Voltar é sinal de que o lado nativo não atendeu.
  Future<void> uninstall();
}

/// A conversa com o `UninstallChannel` (`MainFlutterWindow.swift`), que é quem
/// sabe o que apagar e em que ordem.
class ChannelUninstallService implements UninstallService {
  ChannelUninstallService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('uninstall');

  final MethodChannel _channel;

  @override
  Future<void> uninstall() async {
    try {
      await _channel.invokeMethod<void>('uninstall');
    } on PlatformException catch (error) {
      AppLog.channelError('uninstall', 'uninstall', error);
    } on MissingPluginException {
      // Sem lado nativo: em teste, ou fora do macOS.
    }
  }
}

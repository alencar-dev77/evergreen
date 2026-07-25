import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import 'window_kind.dart';

/// Abre e reutiliza a janela do painel principal (Hub).
///
/// O Hub é criado sob demanda, na primeira vez que o usuário pede por ele —
/// não faz sentido pagar por um engine Flutter em memória enquanto ninguém
/// abriu as configurações.
class HubWindow {
  HubWindow._();

  static final instance = HubWindow._();

  /// Fila de aberturas, para que duas chamadas em sequência rápida não criem
  /// duas janelas — o atalho global é fácil de apertar duas vezes, e a segunda
  /// execução leria a lista de janelas antes de a primeira ter criado a sua.
  Future<void> _pending = Future<void>.value();

  /// Traz o Hub para frente, criando a janela se ainda não existir.
  Future<void> open() {
    return _pending = _pending.then((_) => _open()).catchError((Object _) {});
  }

  /// Não guarda o controller entre chamadas: fechar o Hub destrói a sub-janela
  /// no lado nativo, e um cache aqui apontaria para um windowId morto — o
  /// `show()` seguinte estourava com "failed to find target window". Consultar
  /// `getAll()` a cada abertura é barato e é a única fonte que reflete o que
  /// realmente existe.
  Future<void> _open() async {
    final existing = await _findExisting();

    if (existing != null) {
      try {
        await existing.show();
        return;
      } on PlatformException {
        // A janela morreu entre o getAll e o show (fechada nesse instante).
        // Segue para criar uma nova.
      }
    }

    final controller = await WindowController.create(
      const WindowConfiguration(
        arguments: 'hub',
        hiddenAtLaunch: true,
      ),
    );

    await controller.show();
  }

  /// Procura uma janela do Hub já aberta.
  Future<WindowController?> _findExisting() async {
    final windows = await WindowController.getAll();

    for (final window in windows) {
      if (WindowKind.fromArguments(window.arguments) == WindowKind.hub) {
        return window;
      }
    }

    return null;
  }
}

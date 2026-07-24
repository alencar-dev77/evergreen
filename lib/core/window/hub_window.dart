import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'window_kind.dart';

/// Abre e reutiliza a janela do painel principal (Hub).
///
/// O Hub é criado sob demanda, na primeira vez que o usuário pede por ele —
/// não faz sentido pagar por um engine Flutter em memória enquanto ninguém
/// abriu as configurações.
class HubWindow {
  HubWindow._();

  static final instance = HubWindow._();

  WindowController? _controller;

  /// Traz o Hub para frente, criando a janela se ainda não existir.
  Future<void> open() async {
    final existing = _controller ?? await _findExisting();

    if (existing != null) {
      _controller = existing;
      await existing.show();
      return;
    }

    _controller = await WindowController.create(
      const WindowConfiguration(
        arguments: 'hub',
        hiddenAtLaunch: true,
      ),
    );

    await _controller!.show();
  }

  /// Procura uma janela do Hub já aberta — cobre o caso de a referência local
  /// ter se perdido (por exemplo, após um hot restart).
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

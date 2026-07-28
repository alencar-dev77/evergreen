import 'package:flutter/services.dart';

/// Canal nativo que posiciona a janela do Hub antes de ela aparecer.
///
/// Não tem equivalente em Flutter puro: o `window_manager` age sobre a janela
/// principal (o overlay) e o `WindowController` do `desktop_multi_window` só
/// expõe `show`/`hide`. A implementação e o porquê da regra ("a tela onde está
/// o cursor") estão em `macos/Runner/MainFlutterWindow.swift`.
abstract final class HubWindowChannel {
  static const _channel = MethodChannel('hub_window');

  /// Leva o Hub para a tela onde o cursor está, se ele estiver escondido.
  ///
  /// Chamar antes de exibir a janela. Falhas são engolidas de propósito: uma
  /// janela mal posicionada é um problema menor que um atalho que não abre as
  /// preferências.
  static Future<void> moveToActiveDisplay() async {
    try {
      await _channel.invokeMethod('moveToActiveDisplay');
    } on PlatformException {
      // Sem canal nativo (ou sem janela ainda): segue com a posição atual.
    } on MissingPluginException {
      // Idem — acontece em teste, onde não há lado nativo.
    }
  }
}

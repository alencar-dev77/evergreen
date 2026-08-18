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

  /// Alarga a janela para abrir a região de leitura à direita — ou a devolve ao
  /// tamanho anterior, com [width] em zero.
  ///
  /// A largura vem do Dart porque quem sabe o tamanho da região é quem a
  /// desenha; o lado nativo só sabe somar isso à janela sem jogá-la para fora
  /// da tela.
  ///
  /// Falhas são engolidas como no [moveToActiveDisplay]: sem o lado nativo a
  /// região ainda abre, apenas dividindo a largura que a janela já tem.
  static Future<void> setDetailWidth(double width) async {
    try {
      await _channel.invokeMethod('setDetailWidth', {'width': width});
    } on PlatformException {
      // Sem janela nativa: a região abre dentro da largura atual.
    } on MissingPluginException {
      // Em teste não há lado nativo — e o golden roda com a janela do tamanho
      // que o próprio teste pediu.
    }
  }
}

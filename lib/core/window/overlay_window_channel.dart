import 'package:flutter/services.dart';

/// Canal nativo que exibe a janela flutuante sem ativar o Evergreen.
///
/// Não tem equivalente em Flutter puro: o `show()` do `window_manager` chama
/// `NSApp.activate(ignoringOtherApps: true)`, e é essa chamada que faz o app
/// anterior perder e retomar o foco a cada abertura de painel. A implementação
/// e o porquê de cada linha estão em `macos/Runner/MainFlutterWindow.swift`.
abstract final class OverlayWindowChannel {
  static const _channel = MethodChannel('overlay_window');

  /// Põe o painel na frente e entrega o teclado a ele.
  ///
  /// Devolve `false` quando o lado nativo não respondeu — em teste, onde ele
  /// não existe, ou numa janela que ainda não nasceu. Quem chama decide o que
  /// fazer com isso; engolir em silêncio aqui seria um atalho que não abre.
  static Future<bool> show() async {
    try {
      await _channel.invokeMethod('show');
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Leva a janela para baixo do recorte da câmera: topo da janela no topo da
  /// tela, centrada no recorte.
  ///
  /// Devolve o tamanho do recorte, ou `null` quando não há um (ou o lado nativo
  /// não respondeu) — e aí quem chamou põe a janela no lugar de sempre.
  static Future<Size?> positionAtNotch() async {
    try {
      final notch = await _channel.invokeMapMethod<String, Object?>(
        'positionAtNotch',
      );
      final width = notch?['width'] as num?;
      final height = notch?['height'] as num?;
      if (width == null || height == null) return null;

      return Size(width.toDouble(), height.toDouble());
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

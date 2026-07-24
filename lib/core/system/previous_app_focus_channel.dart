import 'package:flutter/services.dart';

/// Canal nativo que guarda qual app estava em foco antes do overlay do Pin
/// roubar o foco, para devolvê-lo explicitamente ao fechar.
///
/// Não tem equivalente em Flutter puro: rastrear e reativar o app frontmost
/// do macOS é uma operação de `NSWorkspace`/`NSRunningApplication`, só
/// acessível via AppKit (`macos/Runner/MainFlutterWindow.swift`).
class PreviousAppFocusChannel {
  PreviousAppFocusChannel._();

  static const _channel = MethodChannel('previous_app_focus');

  /// Chamar antes de ativar o overlay, enquanto o app anterior ainda é o
  /// frontmost do sistema.
  static Future<void> capture() => _channel.invokeMethod('capture');

  /// Chamar ao esconder o overlay, para devolver o foco ao app capturado.
  static Future<void> restore() => _channel.invokeMethod('restore');

  /// Devolve o foco ao app capturado e cola nele (⌘V sintético).
  ///
  /// Usado só quando o usuário seleciona um item com o auto-colar ligado.
  /// Lança [PlatformException] com código `accessibility_denied` se a permissão
  /// de Acessibilidade não estiver concedida — o chamador decide se ignora
  /// (o item já está na área de transferência de qualquer forma).
  static Future<void> restoreAndPaste() =>
      _channel.invokeMethod('restoreAndPaste');

  /// `true` se o Evergreen já tem permissão de Acessibilidade.
  static Future<bool> hasAccessibilityPermission() async =>
      await _channel.invokeMethod<bool>('hasAccessibilityPermission') ?? false;

  /// Pede a permissão de Acessibilidade, abrindo o diálogo do sistema se ainda
  /// não foi concedida. Retorna o estado atual da permissão.
  static Future<bool> requestAccessibilityPermission() async =>
      await _channel.invokeMethod<bool>('requestAccessibilityPermission') ??
      false;
}

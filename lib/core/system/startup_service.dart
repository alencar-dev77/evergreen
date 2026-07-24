import 'dart:io';

import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path/path.dart' as p;

/// Controla se o Evergreen inicia junto com o macOS.
///
/// O canal nativo vive em `macos/Runner/MainFlutterWindow.swift` e usa
/// `SMAppService`. O sistema pode recusar o registro — builds de
/// desenvolvimento, app fora de /Applications, ou o usuário tendo desativado o
/// item em Ajustes. Por isso toda operação aqui devolve o **estado real** em vez
/// de assumir que deu certo.
class StartupService {
  StartupService._();

  static final instance = StartupService._();

  static const _appName = 'Evergreen';

  bool _isConfigured = false;

  void configure() {
    if (_isConfigured) return;

    launchAtStartup.setup(appName: _appName, appPath: _bundlePath());
    _isConfigured = true;
  }

  /// Estado real do item de início no sistema.
  Future<bool> isEnabled() async {
    configure();

    try {
      return await launchAtStartup.isEnabled();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Tenta aplicar [enabled] e devolve o que o sistema de fato passou a valer.
  Future<bool> setEnabled({required bool enabled}) async {
    configure();

    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } on PlatformException {
      // Sistema recusou; o `isEnabled` abaixo revela o estado que sobrou.
    } on MissingPluginException {
      return false;
    }

    return isEnabled();
  }

  /// `.../Evergreen.app/Contents/MacOS/Evergreen` → `.../Evergreen.app`
  String _bundlePath() {
    final executable = Platform.resolvedExecutable;
    if (!Platform.isMacOS) return executable;

    return p.dirname(p.dirname(p.dirname(executable)));
  }
}

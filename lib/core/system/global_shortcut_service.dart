import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Registra os atalhos globais dos módulos do Evergreen.
///
/// "Global" significa a nível de sistema: o atalho dispara mesmo com outro
/// aplicativo em foco, que é o requisito central do Pin.
class GlobalShortcutService {
  GlobalShortcutService._();

  static final instance = GlobalShortcutService._();

  /// Atalho padrão do Pin: `⌘⇧C`.
  static final pinShortcut = HotKey(
    identifier: 'evergreen.pin.toggle',
    key: PhysicalKeyboardKey.keyC,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Pin como key-caps, para a tela de config.
  static const pinShortcutKeys = <String>['⌘', '⇧', 'C'];

  /// Deve rodar uma única vez, antes de registrar qualquer atalho.
  Future<void> initialize() async {
    // Atalhos do sistema sobrevivem a um hot restart do engine; limpar evita
    // registros duplicados durante o desenvolvimento.
    await hotKeyManager.unregisterAll();
  }

  Future<void> registerPinToggle(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      pinShortcut,
      keyDownHandler: (_) => onPressed(),
    );
  }

  Future<void> dispose() => hotKeyManager.unregisterAll();
}

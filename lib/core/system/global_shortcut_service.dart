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

  /// Atalho padrão do Focus: `⌘⇧X`.
  static final focusShortcut = HotKey(
    identifier: 'evergreen.focus.toggle',
    key: PhysicalKeyboardKey.keyX,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Focus como key-caps.
  static const focusShortcutKeys = <String>['⌘', '⇧', 'X'];

  /// Atalho padrão do Awake: `⌘⇧D`.
  ///
  /// `D` de *display*, a tela que ele mantém acesa. `⌘⇧A` seria o mnemônico do
  /// nome, mas é "ir para Aplicativos" no Finder — e atalho global não pode
  /// tomar uma tecla que os outros apps usam.
  static final awakeShortcut = HotKey(
    identifier: 'evergreen.awake.toggle',
    key: PhysicalKeyboardKey.keyD,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Awake como key-caps.
  static const awakeShortcutKeys = <String>['⌘', '⇧', 'D'];

  /// Atalho padrão das preferências: `⌘⇧,`.
  ///
  /// `⌘,` é a convenção de preferências do macOS, mas como atalho global ele
  /// roubaria a tecla de todos os outros apps. O `⇧` promove a convenção ao
  /// prefixo da casa (`⌘⇧`) sem trocar o mnemônico.
  static final hubShortcut = HotKey(
    identifier: 'evergreen.hub.open',
    key: PhysicalKeyboardKey.comma,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Hub como key-caps.
  static const hubShortcutKeys = <String>['⌘', '⇧', ','];

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

  Future<void> registerFocusToggle(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      focusShortcut,
      keyDownHandler: (_) => onPressed(),
    );
  }

  Future<void> registerAwakeToggle(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      awakeShortcut,
      keyDownHandler: (_) => onPressed(),
    );
  }

  /// Abre — nunca esconde. Diferente dos painéis flutuantes, o Hub é uma janela
  /// comum: no macOS, um atalho que a alcança traz ela para a frente.
  Future<void> registerHubOpen(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      hubShortcut,
      keyDownHandler: (_) => onPressed(),
    );
  }

  Future<void> dispose() => hotKeyManager.unregisterAll();
}

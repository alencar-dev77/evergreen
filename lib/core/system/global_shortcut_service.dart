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

  /// Atalho padrão do Focus: `⌘⇧F`.
  static final focusShortcut = HotKey(
    identifier: 'evergreen.focus.toggle',
    key: PhysicalKeyboardKey.keyF,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Focus como key-caps.
  static const focusShortcutKeys = <String>['⌘', '⇧', 'F'];

  /// Atalho padrão do Awake: `⌘⇧X`.
  ///
  /// Sem mnemônico, e de propósito: `⌘⇧A` é "ir para Aplicativos" no Finder e
  /// `⌘⇧D` passou a ser o Leaf, então sobrou a tecla que ninguém disputa. Em
  /// atalho global, não colidir vale mais que lembrar o nome — o `X` é o que
  /// resta depois de descartar o que os outros apps já usam.
  static final awakeShortcut = HotKey(
    identifier: 'evergreen.awake.toggle',
    key: PhysicalKeyboardKey.keyX,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Awake como key-caps.
  static const awakeShortcutKeys = <String>['⌘', '⇧', 'X'];

  /// Atalho padrão do Leaf: `⌘⇧D`.
  static final leafShortcut = HotKey(
    identifier: 'evergreen.leaf.toggle',
    key: PhysicalKeyboardKey.keyD,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Leaf como key-caps.
  static const leafShortcutKeys = <String>['⌘', '⇧', 'D'];

  /// Atalho padrão do Echo: `⌘⇧E`.
  ///
  /// `E` de Echo, e livre onde importa: `⌘⇧T` seria mnemônico de transcrever,
  /// mas como atalho global roubaria "reabrir aba" de todo navegador — e
  /// reunião acontece dentro do navegador.
  static final echoShortcut = HotKey(
    identifier: 'evergreen.echo.toggle',
    key: PhysicalKeyboardKey.keyE,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Echo como key-caps.
  static const echoShortcutKeys = <String>['⌘', '⇧', 'E'];

  /// Atalho padrão do Nest: `⌘⇧R`.
  ///
  /// Era `⌘⇧S`, de *shelf*, e a letra saiu de circulação: `⌘⇧S` é o "Salvar
  /// como" que qualquer app pode ter, e como atalho global ele sequestra o de
  /// todos. `R` fecha a fila do prefixo da casa — `C`, `D`, `E`, `F`, `X` e
  /// `R` — ao preço conhecido de passar na frente do "recarregar ignorando o
  /// cache" do navegador.
  static final nestShortcut = HotKey(
    identifier: 'evergreen.nest.toggle',
    key: PhysicalKeyboardKey.keyR,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Representação do atalho do Nest como key-caps.
  static const nestShortcutKeys = <String>['⌘', '⇧', 'R'];

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

  Future<void> registerLeafToggle(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      leafShortcut,
      keyDownHandler: (_) => onPressed(),
    );
  }

  Future<void> registerEchoToggle(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      echoShortcut,
      keyDownHandler: (_) => onPressed(),
    );
  }

  Future<void> registerNestToggle(Future<void> Function() onPressed) async {
    await hotKeyManager.register(
      nestShortcut,
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

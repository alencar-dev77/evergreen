import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

/// Ações que o menu da barra de status pode disparar.
enum MenuBarAction {
  openPin('open_pin', 'Pin', '⌘⇧C'),
  openFocus('open_focus', 'Focus', '⌘⇧F'),
  openLeaf('open_leaf', 'Leaf', '⌘⇧D'),
  openAwake('open_awake', 'Awake', '⌘⇧X'),
  openEcho('open_echo', 'Echo', '⌘⇧E'),
  openHub('open_hub', 'Preferências', '⌘⇧,'),
  quit('quit', 'Encerrar Evergreen');

  const MenuBarAction(this.key, this.label, [this.shortcut]);

  final String key;
  final String label;

  /// Atalho global que chega ao mesmo lugar, quando existe.
  final String? shortcut;

  /// Como o item se apresenta no menu.
  ///
  /// O atalho vai no próprio texto porque o `tray_manager` não expõe
  /// `keyEquivalent` — sem isso, o único lugar permanente do app na tela não
  /// ensinaria nenhum dos três atalhos.
  String get menuLabel => shortcut == null ? label : '$label   $shortcut';

  static MenuBarAction? fromKey(String? key) {
    for (final action in values) {
      if (action.key == key) return action;
    }
    return null;
  }
}

/// Ícone do Evergreen na barra de menus do macOS.
///
/// É a única presença permanente do app na tela — de onde o usuário abre o
/// painel do Pin, chega nas configurações e encerra o Evergreen.
class MenuBarService with TrayListener {
  MenuBarService._();

  static final instance = MenuBarService._();

  static const _iconPath = 'assets/icons/tray_icon.png';

  void Function(MenuBarAction action)? _onAction;

  /// Contagem da sessão de foco, quando há uma.
  String? _sessionLabel;

  /// Quanto falta da trava do Awake ("38 min", "sem limite"), quando ligada.
  String? _awakeDetail;

  /// Há quanto tempo o Echo está gravando, quando está.
  String? _echoLabel;

  /// Ponto que anuncia a trava do Awake ligada.
  ///
  /// Um caractere, e não um número: a contagem do Focus já ocupa o título, e
  /// dois relógios lado a lado na barra de menus viram ruído. Quanto falta fica
  /// no item do menu, a um clique. Ponto e não emoji — o título é desenhado em
  /// modo template, junto do ícone monocromático.
  static const _awakeMark = '●';

  Future<void> initialize({
    required void Function(MenuBarAction action) onAction,
  }) async {
    _onAction = onAction;
    trayManager.addListener(this);

    await trayManager.setIcon(_iconPath, isTemplate: true);
    await trayManager.setToolTip('Evergreen');
    await trayManager.setContextMenu(_buildMenu());
  }

  /// Mostra a contagem da sessão de foco ao lado do ícone.
  ///
  /// É onde o Focus vive enquanto o painel está fechado: a barra de menus é o
  /// lugar nativo do macOS para um estado que corre em segundo plano, e evita
  /// deixar uma janela flutuante ocupando a tela por 25 minutos. [label] nulo
  /// devolve o ícone ao estado silencioso.
  Future<void> setSessionLabel(String? label) {
    _sessionLabel = label;
    return _applyTitle();
  }

  /// Anuncia a trava do Awake: o ponto no título e o tempo restante no menu.
  ///
  /// [detail] nulo significa desligado. O menu é reconstruído a cada mudança —
  /// é a única forma de o `tray_manager` atualizar rótulo e marca de seleção de
  /// um item, e acontece no máximo uma vez por minuto.
  Future<void> setAwakeDetail(String? detail) async {
    final wasOn = _awakeDetail != null;
    _awakeDetail = detail;

    await _applyTitle();
    // Só o rótulo do item muda a cada minuto; a marca de seleção, só ao ligar
    // e desligar. Reconstruir sempre custaria um menu novo por minuto sem que
    // nada além do texto mudasse — mas é o texto que responde "quanto falta".
    if (wasOn || detail != null) await trayManager.setContextMenu(_buildMenu());
  }

  /// Anuncia a gravação do Echo na barra de menus.
  ///
  /// É onde a reunião vive enquanto o painel está fechado — o caso normal. O
  /// círculo é a convenção universal de "gravando", e vem antes da contagem
  /// porque é ele que responde "está gravando?"; o tempo só responde "há
  /// quanto".
  Future<void> setEchoLabel(String? label) {
    _echoLabel = label;
    return _applyTitle();
  }

  /// Marca da gravação em curso.
  ///
  /// Vazado, enquanto o do Awake é cheio: os dois podem aparecer ao mesmo
  /// tempo (uma reunião longa é justamente quando a tela não pode apagar), e
  /// dois pontos idênticos lado a lado não diriam qual é qual.
  static const _recordingMark = '◉';

  Future<void> _applyTitle() {
    final parts = <String>[
      if (_awakeDetail != null) _awakeMark,
      if (_echoLabel != null) '$_recordingMark $_echoLabel',
      ?_sessionLabel,
    ];

    return trayManager.setTitle(parts.join(' '));
  }

  /// "Awake   ⌘⇧X" desligado; "Awake · 38 min   ⌘⇧X" ligado.
  String get _awakeMenuLabel {
    const action = MenuBarAction.openAwake;
    final detail = _awakeDetail;
    if (detail == null) return action.menuLabel;

    return '${action.label} · $detail   ${action.shortcut}';
  }

  Menu _buildMenu() => Menu(
    items: [
      MenuItem(label: 'Evergreen', disabled: true),
      MenuItem(
        key: MenuBarAction.openPin.key,
        label: MenuBarAction.openPin.menuLabel,
      ),
      MenuItem(
        key: MenuBarAction.openFocus.key,
        label: MenuBarAction.openFocus.menuLabel,
      ),
      MenuItem(
        key: MenuBarAction.openLeaf.key,
        label: MenuBarAction.openLeaf.menuLabel,
      ),
      // Ligado, o item vira "Awake · 38 min   ⌘⇧X": é onde quem viu o ponto no
      // ícone vai procurar quanto falta. Sem marca de seleção, apesar de ser um
      // estado ligado/desligado — clicar aqui abre o painel, como nos outros
      // módulos, e um item marcado prometeria que o clique desliga a trava.
      MenuItem(key: MenuBarAction.openAwake.key, label: _awakeMenuLabel),
      MenuItem(
        key: MenuBarAction.openEcho.key,
        label: MenuBarAction.openEcho.menuLabel,
      ),
      MenuItem(
        key: MenuBarAction.openHub.key,
        label: MenuBarAction.openHub.menuLabel,
      ),
      MenuItem.separator(),
      MenuItem(
        key: MenuBarAction.quit.key,
        label: MenuBarAction.quit.menuLabel,
      ),
    ],
  );

  @override
  void onTrayIconMouseDown() {
    // No macOS o clique esquerdo também deve abrir o menu.
    if (Platform.isMacOS) {
      trayManager.popUpContextMenu();
      return;
    }
    _onAction?.call(MenuBarAction.openPin);
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = MenuBarAction.fromKey(menuItem.key);
    if (action != null) _onAction?.call(action);
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}

import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

import 'global_shortcut_slot.dart';
import 'shortcut_binding.dart';

/// Ações que o menu da barra de status pode disparar.
///
/// A ordem dos valores é a ordem do menu: a lista dos módulos, as
/// preferências, e encerrar. Um módulo desligado sai da lista e os de baixo
/// sobem — o menu mostra o que a pessoa usa, não o catálogo.
enum MenuBarAction {
  openPin('open_pin', 'Pin', GlobalShortcutSlot.pin),
  openFocus('open_focus', 'Focus', GlobalShortcutSlot.focus),
  openLeaf('open_leaf', 'Leaf', GlobalShortcutSlot.leaf),
  openAwake('open_awake', 'Awake', GlobalShortcutSlot.awake),
  openEcho('open_echo', 'Echo', GlobalShortcutSlot.echo),
  openNest('open_nest', 'Nest', GlobalShortcutSlot.nest),
  openHub('open_hub', 'Preferências', GlobalShortcutSlot.hub),
  quit('quit', 'Encerrar Evergreen', null);

  const MenuBarAction(this.key, this.label, this.slot);

  final String key;
  final String label;

  /// O atalho global que chega ao mesmo lugar, quando existe.
  ///
  /// Guarda o **slot**, não a combinação: a combinação é preferência e muda
  /// enquanto o app roda. Era um texto constante aqui dentro até a v0.14, e
  /// essa era a terceira cópia da mesma tecla — foi o que fez o Nest, que
  /// nunca chegou a aparecer neste menu, ficar meses com `⌘⇧S` escrito num
  /// lugar e outra tecla registrada no sistema.
  final GlobalShortcutSlot? slot;

  /// Como o item se apresenta no menu, dada a combinação em vigor.
  ///
  /// O atalho vai no próprio texto porque o `tray_manager` não expõe
  /// `keyEquivalent` — sem isso, o único lugar permanente do app na tela não
  /// ensinaria atalho nenhum.
  String labelWith(ShortcutBinding? binding) =>
      binding == null ? label : '$label   ${binding.compact}';

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

  /// Os itens de módulo que o menu mostra, na ordem. Ver [setLayout].
  ///
  /// Começa com todos: o menu existe desde o primeiro quadro, e as preferências
  /// só são lidas alguns passos depois na inicialização. Um menu que nascesse
  /// vazio esperando o disco piscaria a cada abertura do app.
  List<MenuBarAction> _modules = MenuBarAction.values
      .where((action) => action != MenuBarAction.openHub)
      .where((action) => action != MenuBarAction.quit)
      .toList();

  /// As combinações em vigor, para escrever ao lado de cada item.
  Map<GlobalShortcutSlot, ShortcutBinding> _bindings = {
    for (final slot in GlobalShortcutSlot.values) slot: slot.fallback,
  };

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

  /// Diz quais módulos aparecem no menu e com que tecla.
  ///
  /// Chamado na inicialização e a cada mudança nas preferências. Reconstruir o
  /// menu inteiro é o único jeito de o `tray_manager` mudar rótulo ou lista de
  /// itens — o mesmo caminho que a trava do Awake já usava para atualizar o
  /// tempo restante.
  Future<void> setLayout({
    required List<MenuBarAction> modules,
    required Map<GlobalShortcutSlot, ShortcutBinding> bindings,
  }) async {
    _modules = modules;
    _bindings = bindings;

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
  String _awakeMenuLabel(ShortcutBinding? binding) {
    const action = MenuBarAction.openAwake;
    final detail = _awakeDetail;
    if (detail == null) return action.labelWith(binding);

    final shortcut = binding == null ? '' : '   ${binding.compact}';
    return '${action.label} · $detail$shortcut';
  }

  Menu _buildMenu() => Menu(
    items: [
      MenuItem(label: 'Evergreen', disabled: true),
      for (final action in _modules) _itemFor(action),
      _itemFor(MenuBarAction.openHub),
      MenuItem.separator(),
      _itemFor(MenuBarAction.quit),
    ],
  );

  MenuItem _itemFor(MenuBarAction action) {
    final binding = action.slot == null ? null : _bindings[action.slot];

    return MenuItem(
      key: action.key,
      // Ligado, o item do Awake vira "Awake · 38 min   ⌘⇧X": é onde quem viu o
      // ponto no ícone vai procurar quanto falta. Sem marca de seleção, apesar
      // de ser um estado ligado/desligado — clicar aqui abre o painel, como nos
      // outros módulos, e um item marcado prometeria que o clique desliga a
      // trava.
      label: action == MenuBarAction.openAwake
          ? _awakeMenuLabel(binding)
          : action.labelWith(binding),
    );
  }

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

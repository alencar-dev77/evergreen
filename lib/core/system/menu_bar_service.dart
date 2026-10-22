import 'package:tray_manager/tray_manager.dart';

import 'global_shortcut_slot.dart';
import 'shortcut_binding.dart';

/// Ações que o menu da barra de status pode disparar.
///
/// A ordem dos valores é a ordem do menu: a versão nova (quando há), a lista
/// dos módulos, as preferências, e as duas saídas — desinstalar e encerrar. Um módulo
/// desligado sai da lista e os de baixo sobem — o menu mostra o que a pessoa
/// usa, não o catálogo.
enum MenuBarAction {
  update('Atualizar o Evergreen…', null),
  openPin('Pin', GlobalShortcutSlot.pin),
  openFocus('Focus', GlobalShortcutSlot.focus),
  openLeaf('Leaf', GlobalShortcutSlot.leaf),
  openAwake('Awake', GlobalShortcutSlot.awake),
  openEcho('Echo', GlobalShortcutSlot.echo),
  openNest('Nest', GlobalShortcutSlot.nest),
  openHub('Preferências', GlobalShortcutSlot.hub),
  uninstall('Desinstalar Evergreen…', null),
  quit('Encerrar Evergreen', null);

  const MenuBarAction(this.label, this.slot);

  final String label;

  /// O atalho global que chega ao mesmo lugar, quando existe.
  ///
  /// Guarda o **slot**, não a combinação: a combinação é preferência e muda
  /// enquanto o app roda. Era um texto constante aqui dentro até a v0.14, e
  /// essa era a terceira cópia da mesma tecla — foi o que fez o Nest, que
  /// nunca chegou a aparecer neste menu, ficar meses com `⌘⇧S` escrito num
  /// lugar e outra tecla registrada no sistema.
  final GlobalShortcutSlot? slot;

  /// Abre um módulo — e por isso entra e sai do menu com ele.
  bool get isModule =>
      this != update && this != openHub && this != uninstall && this != quit;

  /// Como o item se apresenta no menu, dada a combinação em vigor.
  ///
  /// O atalho vai no próprio texto, e não no `accelerator` do item, porque foi
  /// assim que o menu nasceu: o `tray_manager` até a 0.5 não expunha
  /// `keyEquivalent`. A 0.7 passou a expor; trocar o texto por ele é uma
  /// mudança de desenho do menu, não da biblioteca. Sem o atalho aqui, o único
  /// lugar permanente do app na tela não ensinaria atalho nenhum.
  String labelWith(ShortcutBinding? binding) =>
      binding == null ? label : '$label   ${binding.compact}';
}

/// Uma linha do menu, antes de virar item nativo.
///
/// Sem [action], a linha é só texto — o "Evergreen" do topo, apagado.
final class MenuBarEntry {
  const MenuBarEntry.item(this.label, {this.action}) : isSeparator = false;

  const MenuBarEntry.separator()
    : label = '',
      action = null,
      isSeparator = true;

  final String label;
  final MenuBarAction? action;
  final bool isSeparator;

  @override
  bool operator ==(Object other) =>
      other is MenuBarEntry &&
      other.label == label &&
      other.action == action &&
      other.isSeparator == isSeparator;

  @override
  int get hashCode => Object.hash(label, action, isSeparator);

  @override
  String toString() => isSeparator ? '—' : '$label → $action';
}

/// O que a barra de menus mostra: o título ao lado do ícone e as linhas do
/// menu.
///
/// Separado do [MenuBarService] porque é a parte que tem regra — que módulo
/// aparece, que tecla vai ao lado, o que o título junta — e porque o serviço
/// cria um ícone de verdade na barra de menus, coisa que teste nenhum deve
/// fazer.
class MenuBarContent {
  /// Os itens de módulo que o menu mostra, na ordem. Ver
  /// [MenuBarService.setLayout].
  ///
  /// Começa com todos: o menu existe desde o primeiro quadro, e as preferências
  /// só são lidas alguns passos depois na inicialização. Um menu que nascesse
  /// vazio esperando o disco piscaria a cada abertura do app.
  List<MenuBarAction> modules = MenuBarAction.values
      .where((action) => action.isModule)
      .toList();

  /// As combinações em vigor, para escrever ao lado de cada item.
  Map<GlobalShortcutSlot, ShortcutBinding> bindings = {
    for (final slot in GlobalShortcutSlot.values) slot: slot.fallback,
  };

  /// Contagem da sessão de foco, quando há uma.
  String? sessionLabel;

  /// Quanto falta da trava do Awake ("38 min", "sem limite"), quando ligada.
  String? awakeDetail;

  /// Há quanto tempo o Echo está gravando, quando está.
  String? echoLabel;

  /// O módulo cujo relógio a ilha do notch está mostrando —
  /// [MenuBarAction.openEcho] ou [MenuBarAction.openFocus] —, ou `null` sem
  /// ilha na tela.
  ///
  /// Esse relógio sai do título: os dois ficam a um palmo um do outro, no topo
  /// da mesma tela, e o mesmo minuto escrito duas vezes é ruído. Só o que a
  /// ilha mostra sai — ela mostra uma coisa só, e com a reunião nela a sessão
  /// de foco continua ao lado do ícone. Sem recorte (a tampa fechou), a ilha
  /// some e o relógio volta para cá — e com outro monitor ligado ele nem sai:
  /// a barra de menus aparece em todas as telas, a ilha só na do notch, e na
  /// outra o relógio da barra é o único.
  MenuBarAction? inNotch;

  /// Ponto que anuncia a trava do Awake ligada.
  ///
  /// Um caractere, e não um número: a contagem do Focus já ocupa o título, e
  /// dois relógios lado a lado na barra de menus viram ruído. Quanto falta fica
  /// no item do menu, a um clique. Ponto e não emoji — o título é desenhado em
  /// modo template, junto do ícone monocromático.
  static const awakeMark = '●';

  /// Marca da gravação em curso.
  ///
  /// Vazado, enquanto o do Awake é cheio: os dois podem aparecer ao mesmo
  /// tempo (uma reunião longa é justamente quando a tela não pode apagar), e
  /// dois pontos idênticos lado a lado não diriam qual é qual.
  static const recordingMark = '◉';

  /// A versão nova anunciada pelo Sparkle ("1.0.3"), ou `null` sem nenhuma.
  ///
  /// Vira o primeiro item do menu, logo abaixo do "Evergreen", com a bolinha
  /// que no Hub acende o botão "Aplicativo". Não vai para o título ao lado do
  /// ícone: ali o `●` já quer dizer "o Awake está ligado", e uma versão nova não
  /// é algo que precisa ser lembrado a cada olhada para a barra.
  String? updateVersion;

  /// O texto ao lado do ícone; vazio quando nada está rodando.
  String title() {
    final parts = <String>[
      if (awakeDetail != null) awakeMark,
      if (echoLabel != null && inNotch != MenuBarAction.openEcho)
        '$recordingMark $echoLabel',
      if (inNotch != MenuBarAction.openFocus) ?sessionLabel,
    ];

    return parts.join(' ');
  }

  List<MenuBarEntry> entries() => [
    const MenuBarEntry.item('Evergreen'),
    if (updateVersion case final version?) ...[
      // As reticências, como no desinstalar: o clique abre o Hub nas
      // novidades, e é lá que se confirma.
      MenuBarEntry.item(
        '$awakeMark Atualizar para a $version…',
        action: MenuBarAction.update,
      ),
      const MenuBarEntry.separator(),
    ],
    for (final action in modules) _entryFor(action),
    _entryFor(MenuBarAction.openHub),
    const MenuBarEntry.separator(),
    // As reticências avisam que o clique ainda pergunta: ele abre o Hub na
    // confirmação, porque desinstalar não acontece num clique só.
    _entryFor(MenuBarAction.uninstall),
    _entryFor(MenuBarAction.quit),
  ];

  MenuBarEntry _entryFor(MenuBarAction action) {
    final binding = action.slot == null ? null : bindings[action.slot];

    // Ligado, o item do Awake vira "Awake · 38 min   ⌘⇧X": é onde quem viu o
    // ponto no ícone vai procurar quanto falta. Sem marca de seleção, apesar
    // de ser um estado ligado/desligado — clicar aqui abre o painel, como nos
    // outros módulos, e um item marcado prometeria que o clique desliga a
    // trava.
    final label = action == MenuBarAction.openAwake
        ? _awakeLabel(binding)
        : action.labelWith(binding);

    return MenuBarEntry.item(label, action: action);
  }

  /// "Awake   ⌘⇧X" desligado; "Awake · 38 min   ⌘⇧X" ligado.
  String _awakeLabel(ShortcutBinding? binding) {
    const action = MenuBarAction.openAwake;
    final detail = awakeDetail;
    if (detail == null) return action.labelWith(binding);

    final shortcut = binding == null ? '' : '   ${binding.compact}';
    return '${action.label} · $detail$shortcut';
  }
}

/// Ícone do Evergreen na barra de menus do macOS.
///
/// É a única presença permanente do app na tela — de onde o usuário abre o
/// painel do Pin, chega nas configurações e encerra o Evergreen.
///
/// Fala com a API nativa do `tray_manager` (o `nativeapi`, por FFI), e não com
/// a ponte `legacy.dart` da 0.5: a ponte é `@Deprecated` e vai sair numa versão
/// seguinte.
class MenuBarService {
  MenuBarService._();

  static final instance = MenuBarService._();

  static const _iconPath = 'assets/icons/tray_icon.png';

  final _content = MenuBarContent();

  void Function(MenuBarAction action)? _onAction;

  /// Guardado num campo porque o wrapper que o coletor de lixo leva solta o
  /// objeto nativo — e um `TrayIcon` solto some da barra.
  TrayIcon? _tray;

  /// Só para ser solta no [dispose]: o lado nativo guarda a própria cópia.
  Image? _icon;
  ListenerId? _trayListener;

  _NativeMenu? _menu;

  Future<void> initialize({
    required void Function(MenuBarAction action) onAction,
  }) async {
    _onAction = onAction;

    // A imagem antes do ícone: sem ela, sobraria um item vazio na barra de
    // menus, e o erro interromperia a inicialização que vem depois — os
    // atalhos globais entre elas.
    final icon = ImageAsset.fromAsset(_iconPath);
    if (icon == null) {
      throw ArgumentError.value(_iconPath, 'iconPath', 'Ícone não encontrado');
    }
    final tray = TrayIcon.create();
    if (tray == null) {
      icon.dispose();
      throw StateError('Não deu para criar o ícone da barra');
    }

    final menu = _NativeMenu.create(
      onAction: (action) => _onAction?.call(action),
    )..show(_content.entries());

    tray
      ..isIconTemplate = true
      ..icon = icon
      ..setTooltip('Evergreen')
      // O menu é entregue uma vez só, e nunca trocado — ver [_NativeMenu].
      ..setContextMenu(menu.menu)
      // O clique esquerdo abre o menu do lado nativo, sem ida e volta ao Dart.
      ..setContextMenuTrigger(ContextMenuTrigger.clicked)
      ..setVisible(true);

    // O direito, que o gatilho não cobre, chega por aqui. E este listener
    // sustenta também o esquerdo: o lado nativo só liga o clique do botão
    // quando o ícone ganha o primeiro listener. Sem ele, os dois cliques
    // param — sem erro nenhum.
    _trayListener = tray.addListener((event) {
      if (event is TrayIconRightClickedEvent) tray.openContextMenu();
    });

    _tray = tray;
    _icon = icon;
    _menu = menu;
    _applyTitle();
  }

  /// Diz quais módulos aparecem no menu e com que tecla.
  ///
  /// Chamado na inicialização e a cada mudança nas preferências.
  Future<void> setLayout({
    required List<MenuBarAction> modules,
    required Map<GlobalShortcutSlot, ShortcutBinding> bindings,
  }) async {
    _content
      ..modules = modules
      ..bindings = bindings;

    _menu?.show(_content.entries());
  }

  /// Mostra a contagem da sessão de foco ao lado do ícone.
  ///
  /// É onde o Focus vive enquanto o painel está fechado: a barra de menus é o
  /// lugar nativo do macOS para um estado que corre em segundo plano, e evita
  /// deixar uma janela flutuante ocupando a tela por 25 minutos. [label] nulo
  /// devolve o ícone ao estado silencioso.
  Future<void> setSessionLabel(String? label) async {
    _content.sessionLabel = label;
    _applyTitle();
  }

  /// Anuncia a trava do Awake: o ponto no título e o tempo restante no menu.
  ///
  /// [detail] nulo significa desligado. Acontece no máximo uma vez por minuto
  /// — e pode acontecer com o menu aberto na tela, que é por que o item é
  /// renomeado, e não refeito.
  /// Anuncia a versão nova no menu — ver [MenuBarContent.updateVersion].
  Future<void> setUpdateVersion(String? version) async {
    if (_content.updateVersion == version) return;
    _content.updateVersion = version;

    _menu?.show(_content.entries());
  }

  Future<void> setAwakeDetail(String? detail) async {
    _content.awakeDetail = detail;

    _applyTitle();
    _menu?.show(_content.entries());
  }

  /// Anuncia a gravação do Echo na barra de menus.
  ///
  /// É onde a reunião vive enquanto o painel está fechado — o caso normal. O
  /// círculo é a convenção universal de "gravando", e vem antes da contagem
  /// porque é ele que responde "está gravando?"; o tempo só responde "há
  /// quanto".
  Future<void> setEchoLabel(String? label) async {
    _content.echoLabel = label;
    _applyTitle();
  }

  /// Diz qual relógio a ilha do notch já mostra. Ver [MenuBarContent.inNotch].
  Future<void> setInNotch(MenuBarAction? action) async {
    _content.inNotch = action;
    _applyTitle();
  }

  void _applyTitle() {
    final title = _content.title();
    _tray?.setTitle(title.isEmpty ? null : title);
  }

  Future<void> dispose() async {
    final tray = _tray;
    final listener = _trayListener;
    if (tray != null && listener != null) tray.removeListener(listener);

    tray?.setContextMenu(null);
    _menu?.dispose();
    tray?.dispose();
    _icon?.dispose();

    _tray = null;
    _icon = null;
    _trayListener = null;
    _menu = null;
  }
}

/// O menu nativo da barra, que é **um objeto só durante toda a vida do app**.
///
/// Trocar o `Menu` do ícone com ele aberto deixa o ícone preso a um menu morto:
/// o `TrayIcon.setContextMenu` do `nativeapi` tira do menu antigo o listener
/// que, ao fechar, devolve o clique ao ícone — e o menu aberto fecha sem
/// ninguém para isso. Daí em diante cada clique mostra o menu velho, com itens
/// que não fazem nada, até reiniciar o app. E o menu fica aberto enquanto o
/// Dart roda (o laço do Flutter corre nos modos comuns): o minuto do Awake vira
/// com ele na tela.
///
/// Por isso [show] nunca troca o menu. Mesma forma, só os rótulos mudam, e o
/// item é renomeado no lugar — o caso de todo minuto. Forma nova (um módulo
/// desligado), o mesmo menu é esvaziado e repovoado.
final class _NativeMenu {
  _NativeMenu._(this.menu, this._onAction);

  final Menu menu;
  final void Function(MenuBarAction action) _onAction;

  var _entries = const <MenuBarEntry>[];

  /// Um por linha de [_entries]; nulo nos separadores.
  final _items = <(MenuItem, ListenerId?)?>[];

  static _NativeMenu create({
    required void Function(MenuBarAction action) onAction,
  }) {
    final menu = Menu.create();
    if (menu == null) throw StateError('Não deu para criar o menu da barra');
    return _NativeMenu._(menu, onAction);
  }

  void show(List<MenuBarEntry> entries) {
    if (_sameShape(entries)) {
      for (var i = 0; i < entries.length; i++) {
        final item = _items[i];
        if (item != null && _entries[i].label != entries[i].label) {
          item.$1.label = entries[i].label;
        }
      }
    } else {
      menu.clear();
      _releaseItems();
      for (final entry in entries) {
        _add(entry);
      }
    }
    _entries = entries;
  }

  bool _sameShape(List<MenuBarEntry> entries) {
    if (entries.length != _entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isSeparator != _entries[i].isSeparator ||
          entries[i].action != _entries[i].action) {
        return false;
      }
    }
    return true;
  }

  void _add(MenuBarEntry entry) {
    if (entry.isSeparator) {
      menu.addSeparator();
      _items.add(null);
      return;
    }

    final item = MenuItem.createWithLabelAndType(
      entry.label,
      MenuItemType.normal,
    );
    if (item == null) throw StateError('Não deu para criar "${entry.label}"');

    final action = entry.action;
    item.isEnabled = action != null;
    final listener = action == null
        ? null
        : item.addListener((event) {
            if (event is MenuItemClickedEvent) _onAction(action);
          });

    _items.add((item, listener));
    menu.addItem(item);
  }

  /// Solta os itens na hora, mesmo vindo de dentro do clique de um deles: os
  /// listeners do `nativeapi` chegam ao Dart depois de o callback nativo
  /// voltar, e o evento traz o que precisa consigo.
  void _releaseItems() {
    for (final entry in _items) {
      if (entry == null) continue;
      final (item, listener) = entry;
      if (listener != null) item.removeListener(listener);
      item.dispose();
    }
    _items.clear();
  }

  void dispose() {
    menu.clear();
    _releaseItems();
    menu.dispose();
  }
}

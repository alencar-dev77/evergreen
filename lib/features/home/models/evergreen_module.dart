import '../../../core/system/global_shortcut_slot.dart';
import '../../../core/system/menu_bar_service.dart';
import '../../../core/window/overlay_panel.dart';
import '../../../shared/widgets/eg_icon.dart';

/// Os módulos que compõem a suíte Evergreen.
///
/// O Hub lista todos, inclusive os que ainda não existem — o roadmap fica
/// visível dentro do próprio produto, e adicionar um módulo novo é acrescentar
/// um valor aqui.
enum EvergreenModule {
  pin(
    name: 'Pin',
    tagline: 'Gerenciador de área de transferência',
    description:
        'Registra tudo que você copia e devolve em um atalho. Com busca e '
        'itens fixados.',
    icon: EgIconData.clipboard,
    status: ModuleStatus.available,
    shortcutSlot: GlobalShortcutSlot.pin,
    panel: OverlayPanel.pin,
  ),
  focus(
    name: 'Focus',
    tagline: 'Cronômetro de foco',
    description:
        'Ciclos de foco e pausa, com o registro do que foi feito em cada '
        'sessão.',
    icon: EgIconData.timer,
    status: ModuleStatus.available,
    shortcutSlot: GlobalShortcutSlot.focus,
    panel: OverlayPanel.focus,
  ),
  leaf(
    name: 'Leaf',
    tagline: 'Anotações rápidas',
    description:
        'Até nove anotações curtas, todas à vista de uma vez. Para o que '
        'precisa sair da cabeça agora.',
    icon: EgIconData.note,
    status: ModuleStatus.available,
    shortcutSlot: GlobalShortcutSlot.leaf,
    panel: OverlayPanel.leaf,
  ),
  awake(
    name: 'Awake',
    tagline: 'Mantém a tela acesa',
    description:
        'Impede o Mac de apagar a tela e dormir pelo tempo que você '
        'escolher, sem mexer nas configurações de energia.',
    icon: EgIconData.sun,
    status: ModuleStatus.available,
    shortcutSlot: GlobalShortcutSlot.awake,
    panel: OverlayPanel.awake,
  ),
  echo(
    name: 'Echo',
    tagline: 'Transcrição de reuniões',
    description:
        'Grava a reunião, separa a sua voz da dos outros e devolve em '
        'texto. O resumo sai do modelo do próprio Mac.',
    icon: EgIconData.microphone,
    status: ModuleStatus.available,
    shortcutSlot: GlobalShortcutSlot.echo,
    panel: OverlayPanel.echo,
  ),
  nest(
    name: 'Nest',
    tagline: 'Prateleira de arquivos',
    description:
        'Junte arquivos de pastas diferentes numa prateleira e mande todos '
        'para o mesmo lugar de uma vez.',
    icon: EgIconData.tray,
    status: ModuleStatus.available,
    shortcutSlot: GlobalShortcutSlot.nest,
    panel: OverlayPanel.nest,
  ),
  track(
    name: 'Track',
    tagline: 'O dia reconstruído',
    description:
        'Responde "o que eu fiz hoje" com o que os outros módulos já '
        'gravaram. Não captura nada: só lê.',
    icon: EgIconData.track,
    status: ModuleStatus.available,
  );

  const EvergreenModule({
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.status,
    this.shortcutSlot,
    this.panel,
    // ignore: unused_element_parameter
    this.plannedFor,
  });

  final String name;

  /// Uma linha que resume o módulo, exibida na barra lateral.
  final String tagline;

  /// Texto completo, exibido no painel do módulo.
  final String description;

  final EgIconData icon;
  final ModuleStatus status;

  /// Versão em que o módulo deve chegar; `null` para os já disponíveis.
  final String? plannedFor;

  /// O atalho global que abre o módulo, quando ele tem um.
  ///
  /// O Track não tem: ele só existe dentro do Hub, e a janela que o contém já
  /// tem o atalho dela. É este campo que faz a seção "Atalho global" aparecer
  /// na tela de um módulo e não na do outro.
  final GlobalShortcutSlot? shortcutSlot;

  /// O painel flutuante do módulo, quando ele tem um.
  ///
  /// Anda junto do [shortcutSlot] hoje, mas são coisas diferentes: o slot é
  /// como se pede o painel, e este é o painel. Um módulo que só existisse no
  /// menu da barra teria um sem o outro.
  final OverlayPanel? panel;

  bool get isAvailable => status == ModuleStatus.available;

  /// O identificador do valor no enum: `pin`, `echo`, `nest`.
  ///
  /// Existe porque o [name] deste enum **não** é o que `.name` costuma ser: o
  /// campo declarado aqui sombreia o do `Enum`, e `module.name` devolve o nome
  /// de exibição ("Pin"). O cast reencontra o de baixo.
  ///
  /// A distinção importa porque isto é **chave de preferência no disco**:
  /// derivá-la do nome de exibição faria a preferência de quem desligou o Pin
  /// sumir no dia em que alguém trocasse o rótulo do módulo na barra lateral.
  String get id => (this as Enum).name;

  /// O item deste módulo no menu da barra de status, quando ele tem um.
  ///
  /// Derivado do [shortcutSlot] em vez de ser um campo à parte: o item do menu
  /// e o atalho global são a mesma porta vista de dois lugares, e um módulo com
  /// um sem o outro seria uma porta pela metade.
  MenuBarAction? get menuBarAction {
    final slot = shortcutSlot;
    if (slot == null) return null;

    for (final action in MenuBarAction.values) {
      if (action.slot == slot) return action;
    }
    return null;
  }

  /// O módulo dono deste painel.
  static EvergreenModule of(OverlayPanel panel) =>
      values.firstWhere((module) => module.panel == panel);
}

enum ModuleStatus { available, planned }

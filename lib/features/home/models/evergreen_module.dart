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
        'Registra tudo que você copia e devolve em um atalho. Histórico local, '
        'busca instantânea e itens fixados.',
    icon: EgIconData.clipboard,
    status: ModuleStatus.available,
  ),
  focus(
    name: 'Focus',
    tagline: 'Cronômetro de foco',
    description:
        'Ciclos de foco e pausa, com o registro do que foi feito em cada '
        'sessão. Histórico local e nada de notificação inútil.',
    icon: EgIconData.timer,
    status: ModuleStatus.available,
  ),
  leaf(
    name: 'Leaf',
    tagline: 'Anotações rápidas',
    description:
        'Uma parede de até nove anotações curtas, todas à vista de uma vez. '
        'Para o que precisa sair da cabeça agora e ser resolvido depois.',
    icon: EgIconData.note,
    status: ModuleStatus.available,
  ),
  awake(
    name: 'Awake',
    tagline: 'Mantém a tela acesa',
    description:
        'Impede o Mac de apagar a tela e dormir pelo tempo que você escolher. '
        'Nada de mexer nas configurações de energia por causa de uma reunião.',
    icon: EgIconData.sun,
    status: ModuleStatus.available,
  ),
  echo(
    name: 'Echo',
    tagline: 'Transcrição de reuniões',
    description:
        'Grava a reunião, separa a sua voz da dos outros e devolve tudo em '
        'texto. O resumo sai do modelo do próprio Mac — nada sobe para '
        'lugar nenhum.',
    icon: EgIconData.microphone,
    status: ModuleStatus.available,
  ),
  trail(
    name: 'Trail',
    tagline: 'O dia reconstruído',
    description:
        'Responde "o que eu fiz hoje" com o que os outros módulos já '
        'gravaram: quanto você focou, quantas reuniões gravou e o que passou '
        'pela área de transferência. Não captura nada — só lê.',
    icon: EgIconData.trail,
    status: ModuleStatus.available,
  );

  const EvergreenModule({
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.status,
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

  bool get isAvailable => status == ModuleStatus.available;
}

enum ModuleStatus { available, planned }

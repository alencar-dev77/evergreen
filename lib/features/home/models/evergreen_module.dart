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
  shelf(
    name: 'Shelf',
    tagline: 'Área temporária de arquivos',
    description:
        'Um lugar para largar arquivos enquanto você os move de um app para outro.',
    icon: EgIconData.tray,
    status: ModuleStatus.planned,
    plannedFor: 'v0.3',
  );

  const EvergreenModule({
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.status,
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

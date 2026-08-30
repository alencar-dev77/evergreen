import '../../../core/system/global_shortcut_slot.dart';
import '../../../core/system/shortcut_binding.dart';
import 'evergreen_module.dart';

/// Quais módulos estão ligados e com que tecla cada um abre.
///
/// Duas preferências de aplicativo que nasceram juntas porque são a mesma
/// pergunta feita duas vezes — "isto aqui é meu?". Ninguém usa os sete módulos;
/// quem usa três não quer os outros quatro no menu da barra, e quem usa os sete
/// não necessariamente concorda com as teclas que a casa escolheu.
///
/// **Nada aqui apaga nada.** Desligar um módulo fecha as portas dele — some do
/// menu, o atalho para de valer, a tela do módulo fica apagada — e o banco
/// continua exatamente onde estava. Religar devolve o histórico como ele
/// ficou, e é isso que faz o interruptor ser uma decisão barata em vez de uma
/// pergunta de sim ou não com um diálogo na frente.
class ModuleSettings {
  const ModuleSettings({this.disabled = const {}, this.custom = const {}});

  /// Os módulos **desligados**.
  ///
  /// Guardar o que está desligado, e não o que está ligado, é o que faz um
  /// módulo novo nascer ligado sem ninguém precisar migrar preferência
  /// nenhuma: o conjunto vazio é o estado de fábrica, e um valor que não está
  /// no conjunto está ligado.
  final Set<EvergreenModule> disabled;

  /// Os atalhos que a pessoa gravou por cima do padrão.
  ///
  /// Pela mesma razão: quem não gravou nada não tem entrada aqui, e o padrão do
  /// slot continua sendo o padrão mesmo depois de ele mudar numa versão nova.
  final Map<GlobalShortcutSlot, ShortcutBinding> custom;

  bool isEnabled(EvergreenModule module) => !disabled.contains(module);

  /// A combinação em vigor: a gravada, ou a de fábrica.
  ShortcutBinding bindingFor(GlobalShortcutSlot slot) =>
      custom[slot] ?? slot.fallback;

  /// A combinação deste slot foi trocada? É o que decide se "Restaurar padrão"
  /// aparece.
  bool isCustom(GlobalShortcutSlot slot) => custom.containsKey(slot);

  /// Todos os atalhos em vigor, inclusive os de módulos desligados.
  ///
  /// É o mapa que a conferência de conflito usa: a tecla de um módulo desligado
  /// continua sendo *dele*, e deixar outro módulo tomá-la faria os dois
  /// disputarem a mesma combinação no dia em que o primeiro voltasse a ligar.
  Map<GlobalShortcutSlot, ShortcutBinding> get allBindings => {
    for (final slot in GlobalShortcutSlot.values) slot: bindingFor(slot),
  };

  /// Os atalhos que devem estar registrados no sistema agora.
  ///
  /// Módulo desligado fica de fora — é a metade da promessa do interruptor que
  /// o sistema operacional precisa cumprir. O Hub nunca sai: ele é a única
  /// porta para religar qualquer coisa, e um atalho de preferências que
  /// dependesse de uma preferência seria uma armadilha.
  Map<GlobalShortcutSlot, ShortcutBinding> get activeBindings => {
    for (final slot in GlobalShortcutSlot.values)
      if (slot == GlobalShortcutSlot.hub || _isSlotEnabled(slot))
        slot: bindingFor(slot),
  };

  bool _isSlotEnabled(GlobalShortcutSlot slot) {
    for (final module in EvergreenModule.values) {
      if (module.shortcutSlot == slot) return isEnabled(module);
    }
    return true;
  }

  ModuleSettings copyWith({
    Set<EvergreenModule>? disabled,
    Map<GlobalShortcutSlot, ShortcutBinding>? custom,
  }) {
    return ModuleSettings(
      disabled: disabled ?? this.disabled,
      custom: custom ?? this.custom,
    );
  }
}

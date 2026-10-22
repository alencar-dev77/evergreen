/// Os módulos que têm alguma coisa no notch.
///
/// Três, e cada um com um uso diferente dele: o Nest o usa como **porta** (o
/// arquivo levado até lá chama a prateleira), o Echo e o Focus o usam como
/// **vitrine** (o que está rodando aparece em volta dele). O Awake ficou de
/// fora por decisão: a trava já tem o seu lugar na barra de menus, e o notch é
/// para o que se acompanha.
enum NotchModule {
  nest('nest'),
  echo('echo'),
  focus('focus');

  const NotchModule(this.id);

  /// A chave no disco e no canal. Estável: renomear o valor do enum não pode
  /// apagar a preferência de ninguém.
  final String id;

  static NotchModule? fromId(String? id) {
    for (final module in values) {
      if (module.id == id) return module;
    }
    return null;
  }
}

/// O que cada módulo faz no notch.
///
/// Tudo ligado por padrão: o notch só aparece com alguma coisa acontecendo, e
/// em Mac sem recorte nada disto existe. Desligar é para quem não quer.
class NotchSettings {
  const NotchSettings({this.disabled = const {}});

  /// Os módulos que a pessoa tirou do notch. Guarda-se o que **difere do
  /// padrão**, como nas preferências de módulo: um módulo novo no notch nasce
  /// ligado para quem já usa o app.
  final Set<NotchModule> disabled;

  bool isEnabled(NotchModule module) => !disabled.contains(module);

  NotchSettings copyWith(NotchModule module, {required bool enabled}) =>
      NotchSettings(
        disabled: enabled
            ? ({...disabled}..remove(module))
            : {...disabled, module},
      );
}

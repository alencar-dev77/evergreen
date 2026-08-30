import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../models/evergreen_module.dart';
import '../viewmodels/module_settings_view_model.dart';

/// O interruptor mestre de um módulo, no topo da tela dele.
///
/// Fica **acima de tudo**, inclusive da lista do módulo, e é a única coisa que
/// escapa da ordem fixa de tópicos: ele não é uma preferência do módulo, é a
/// pergunta que decide se as preferências do módulo importam.
///
/// Ele mora aqui, e não no menu da barra de status, por uma razão prática: o
/// menu é o lugar de **usar** o Evergreen, e um interruptor de configuração no
/// meio da lista de módulos seria mais uma coisa para errar na pressa. E mora
/// na tela do próprio módulo, e não numa lista central de módulos, porque a
/// pergunta "eu uso isto?" se responde olhando para o que o módulo faz — que é
/// exatamente o que está logo abaixo.
///
/// O módulo desligado **continua na barra lateral**, apagado. É o que impede o
/// beco sem saída: se sumisse da lista, o interruptor de religar estaria dentro
/// da tela que sumiu.
class ModuleSwitchSection extends ConsumerWidget {
  const ModuleSwitchSection({super.key, required this.module});

  final EvergreenModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(moduleSettingsViewModelProvider);
    final isEnabled = settings.isEnabled(module);

    return EgSettingsCard(
      title: 'Módulo',
      children: [
        EgSettingsRow.toggle(
          label: 'Usar o ${module.name}',
          description: _description,
          value: isEnabled,
          onChanged: (value) => ref
              .read(moduleSettingsViewModelProvider.notifier)
              .setEnabled(module, enabled: value),
        ),
      ],
    );
  }

  /// O que o interruptor faz, dito por módulo.
  ///
  /// Genérico não serve: "desliga o módulo" não responde a pergunta que a
  /// pessoa tem na cabeça, que é *o que para de acontecer*. No Pin é a captura
  /// da área de transferência; no Nest, o arraste e o chacoalhar. E as duas
  /// frases finais são iguais em todos porque a promessa é a mesma: nada é
  /// apagado, e o atalho volta a ser de quem estava usando ele.
  String get _description {
    final specific = switch (module) {
      EvergreenModule.pin => 'para de registrar o que você copia',
      EvergreenModule.focus => 'não inicia sessões novas',
      EvergreenModule.leaf => 'a parede não abre',
      EvergreenModule.awake => 'a trava é solta e o Mac volta a dormir',
      EvergreenModule.echo => 'não grava reuniões',
      EvergreenModule.nest => 'a prateleira não recebe arquivos',
      EvergreenModule.track => 'para de reconstruir o dia',
    };

    // O Track não tem painel, então não tem item de menu nem atalho global:
    // prometer que os dois somem seria descrever um módulo que não é este.
    final doors = module.shortcutSlot == null
        ? ''
        : ', sai do menu da barra e o atalho para de valer';

    return 'Desligado, $specific$doors. Nada é apagado.';
  }
}

/// O corpo de uma tela de módulo desligado: à vista, apagado e sem resposta.
///
/// Apagado e não escondido, pela mesma razão que um controle desabilitado do
/// Focus continua na tela: quem desligou precisa ver o que está deixando de
/// usar para decidir se quer de volta. Uma tela que ficasse em branco não
/// diria nem o que o módulo faz nem o que ele já guardou.
///
/// Três camadas, e cada uma responde por uma forma de alcançar o conteúdo: o
/// [Opacity] diz que está desligado, o [IgnorePointer] tira o mouse e o
/// [ExcludeFocus] tira o teclado — sem o terceiro, um Tab ainda entraria na
/// tela apagada e mexeria num controle invisível de tão claro.
class ModuleGate extends StatelessWidget {
  const ModuleGate({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;

    return ExcludeFocus(
      child: IgnorePointer(
        // A árvore de acessibilidade acompanha: sem isto o leitor de tela leria
        // uma tela inteira de controles que não respondem a nada.
        child: ExcludeSemantics(
          child: Opacity(opacity: AppOpacities.disabled, child: child),
        ),
      ),
    );
  }
}

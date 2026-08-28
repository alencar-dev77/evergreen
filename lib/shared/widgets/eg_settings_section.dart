import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_section_label.dart';

/// A pilha de tópicos de uma tela de preferências.
///
/// Existe porque o vão **entre** tópicos é do conjunto, não de cada tópico. A
/// seção guardava esse vão embaixo de si, e isso tinha dois efeitos: o último
/// tópico da tela empurrava um respiro que ninguém pediu contra o rodapé do
/// scroll, e o tamanho da separação ficava impossível de mudar sem mexer em
/// todas as telas.
///
/// A separação é maior que qualquer vão de dentro de um tópico — e essa é a
/// regra inteira. Com 32px, um tópico de três linhas altas (rótulo, descrição
/// de três linhas, controle) tinha vãos internos quase do tamanho do vão entre
/// tópicos, e a tela virava uma coluna contínua de texto onde nada agrupava com
/// nada. Agrupar é o que o espaço faz aqui; ele não está decorando.
class EgSettingsPage extends StatelessWidget {
  const EgSettingsPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.giant),
          children[i],
        ],
      ],
    );
  }
}

/// Agrupa linhas de configuração sob um header em caixa alta.
///
/// O header cola no conteúdo dele (`xs` abaixo) enquanto a distância para o
/// tópico anterior é a da [EgSettingsPage]: é essa diferença — e não uma linha
/// divisória a mais — que diz onde um assunto acaba e outro começa. As linhas
/// já usam divisor entre si, e um divisor no limite do tópico ficaria idêntico
/// a eles, ou seja, não separaria nada.
class EgSettingsSection extends StatelessWidget {
  const EgSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;

  /// Controle que manda no que a seção mostra — o recorte de período do Track.
  ///
  /// Na linha do header, e não acima do conteúdo: ele governa a seção inteira,
  /// e uma linha própria para ele o faria parecer mais um item da lista abaixo.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_header(), ...children],
    );
  }

  Widget _header() {
    if (trailing == null) {
      return EgSectionLabel(
        title,
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: EgSectionLabel(title)),
          trailing!,
        ],
      ),
    );
  }
}

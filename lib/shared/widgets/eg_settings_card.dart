import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import '../../core/design/tokens/eg_squircle.dart';
import 'eg_section_label.dart';

/// A pilha de cartões de uma tela de preferências.
///
/// O vão **entre** cartões é do conjunto, não de cada cartão: um cartão que
/// guardasse respiro embaixo de si empurraria um vão que ninguém pediu contra
/// o rodapé do scroll, e mudar a separação exigiria mexer em todas as telas.
class EgSettingsPage extends StatelessWidget {
  const EgSettingsPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxl),
          children[i],
        ],
      ],
    );
  }
}

/// Um assunto de uma tela de preferências: o rótulo fora, as linhas dentro.
///
/// **É o que matou a escada de pares soltos.** Antes, cada linha atravessava a
/// largura inteira da tela com o rótulo encostado à esquerda e o controle
/// encostado à direita, e entre os dois havia 400 px de nada — linha após
/// linha, a tela virava uma escada em que nenhum par pertencia a nenhum
/// grupo. Dentro de um cartão de largura de coluna, o controle fica a um
/// palmo do rótulo que ele responde, e o cartão diz quais linhas são o mesmo
/// assunto.
///
/// O rótulo fica **fora** do cartão, e não dentro: dentro ele seria mais uma
/// linha, e a primeira linha de um cartão é conteúdo. Fora, ele é a etiqueta
/// da gaveta.
///
/// Os divisores são do cartão, e não das linhas. Uma linha que decide sozinha
/// se tem divisor embaixo obriga cada tela a saber qual é a última — era o
/// `showDivider: needsPermission` espalhado pelas telas, uma condição que
/// existia só para não sobrar um traço no pé do grupo.
class EgSettingsCard extends StatelessWidget {
  const EgSettingsCard({
    super.key,
    this.title,
    required this.children,
    this.trailing,
  });

  /// A etiqueta do assunto, em caixa alta e mono. `null` num cartão que não
  /// precisa se anunciar — o único do Leaf, por exemplo.
  final String? title;

  /// Controle que manda no que o cartão mostra — o recorte de período do
  /// Track.
  ///
  /// Na linha do rótulo, e não acima do conteúdo: ele governa o cartão
  /// inteiro, e uma linha própria o faria parecer mais um item da lista.
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[_header(), const SizedBox(height: AppSpacing.sm)],
        // O recorte é o que faz o divisor morrer na borda do cartão em vez de
        // atravessá-la, e o que impede a primeira linha de vazar pelo canto
        // arredondado quando ela tem fundo próprio.
        ClipPath(
          clipper: ShapeBorderClipper(shape: eg.shapes.cardShape),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: eg.colors.surface,
              shape: EgSquircle.shape(eg.shapes.radiusCard, side: eg.edge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: eg.shapes.hairline,
                      color: eg.colors.edge,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    if (trailing == null) return EgSectionLabel(title!);

    return Row(
      children: [
        Expanded(child: EgSectionLabel(title!)),
        trailing!,
      ],
    );
  }
}

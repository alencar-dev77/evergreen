import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import '../../core/design/tokens/eg_squircle.dart';
import 'eg_section_label.dart';
import 'eg_settings_row.dart';

/// O que um cartão faz com o que já existe.
///
/// O tom não é decoração: ele é o aviso que chega **antes** de a pessoa ler o
/// rótulo. Um cartão de ajuste e um cartão que apaga coisas não podem ser a
/// mesma superfície com um botão vermelho no canto — quem varre a tela vê a
/// superfície primeiro, e é ali que o alerta tem de estar.
enum EgCardTone {
  /// Ajustes: a superfície de sempre.
  neutral,

  /// Ações sem volta. Fundo e borda em vermelho de baixa opacidade — nunca a
  /// cor cheia, que gritaria mais alto que a ação principal de qualquer tela.
  destructive;

  Color surfaceOf(EgTokens eg) => switch (this) {
    EgCardTone.neutral => eg.colors.surface,
    EgCardTone.destructive => eg.colors.error.withValues(alpha: 0.06),
  };

  BorderSide edgeOf(EgTokens eg) => switch (this) {
    EgCardTone.neutral => eg.edge,
    EgCardTone.destructive => BorderSide(
      color: eg.colors.error.withValues(alpha: 0.22),
      width: eg.shapes.hairline,
    ),
  };

  /// A cor do rótulo da seção, para a etiqueta acompanhar o cartão.
  Color? labelOf(EgTokens eg) => switch (this) {
    EgCardTone.neutral => null,
    EgCardTone.destructive => eg.colors.error.withValues(alpha: 0.85),
  };
}

/// A pilha de cartões de uma tela de preferências.
///
/// **Uma coluna, sempre.** Foram duas — par à esquerda, ímpar à direita —, e o
/// preço era o zigue-zague: o assunto seguinte ficava *ao lado* do atual e não
/// abaixo dele, de modo que correr a tela de cima a baixo deixava de ser um
/// movimento e passava a ser um vaivém. Em uma coluna, a ordem em que a tela
/// foi escrita é a ordem em que ela é lida.
///
/// A rolagem que isso traz é o preço aceito, e é o menor dos dois: rolar é
/// previsível, procurar não. Meia largura também era onde as listas — as
/// reuniões do Echo, os destinos do Nest — não caíam bem, e era o x de cada
/// cartão que mudava quando a região de leitura estreitava o conteúdo.
///
/// O vão **entre** cartões é do conjunto, não de cada cartão: um cartão que
/// guardasse respiro embaixo de si empurraria um vão que ninguém pediu contra
/// o rodapé do scroll, e mudar a separação exigiria mexer em todas as telas.
class EgSettingsPage extends StatelessWidget {
  const EgSettingsPage({
    super.key,
    required this.children,
    this.banner,
    this.footer,
  });

  /// A linha do pé da tela, abaixo de tudo e fora da pilha.
  ///
  /// É onde vai a promessa da casa — "seus dados ficam neste Mac" — e o link de
  /// novidades: coisas que valem para a tela inteira e não pertencem a
  /// assunto nenhum.
  final Widget? footer;

  /// O que vai acima da pilha, encostado no topo da tela.
  ///
  /// É a faixa de estado: ela responde por *a tela inteira*, e não por um dos
  /// assuntos dela. Como primeiro cartão, ela passaria a se ler como mais um
  /// assunto, com rótulo de gaveta e tudo.
  final Widget? banner;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[
          banner!,
          const SizedBox(height: AppSpacing.xxl),
        ],
        _column(children),
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.huge),
          footer!,
        ],
      ],
    );
  }

  static Widget _column(List<Widget> cards) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.xxl),
        cards[i],
      ],
    ],
  );
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
    this.tone = EgCardTone.neutral,
  });

  /// O que este cartão faz com o que já existe — ver [EgCardTone].
  final EgCardTone tone;

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
        if (title != null) ...[
          _header(eg),
          const SizedBox(height: AppSpacing.sm),
        ],
        // O recorte é o que faz o divisor morrer na borda do cartão em vez de
        // atravessá-la, e o que impede a primeira linha de vazar pelo canto
        // arredondado quando ela tem fundo próprio.
        //
        // **A luz e a sombra vêm por fora do recorte**, e é por isso que são
        // duas camadas: a sombra de contato precisa cair *fora* do cartão, e
        // um `ClipPath` recortaria justamente ela.
        DecoratedBox(
          decoration: ShapeDecoration(
            color: tone.surfaceOf(eg),
            shape: EgSquircle.shape(
              eg.shapes.radiusCard,
              side: tone.edgeOf(eg),
            ),
            shadows: eg.elevations.card,
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: eg.shapes.cardShape),
            child: DecoratedBox(
              // A linha de luz de 1px no topo interno: é ela que faz o cartão
              // parecer pegar luz de cima em vez de ser um retângulo chapado. O
              // Flutter não tem sombra interna, então elevação se desenha com
              // luz — a mesma solução da linha selecionada.
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color:
                        eg.elevations.rowInnerHairline ??
                        const Color(0x00000000),
                    width: eg.shapes.hairline,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    // O divisor atravessa o cartão de ponta a ponta, por baixo
                    // do respiro: recuado nas duas pontas ele viraria um traço
                    // solto no meio, e não a linha que separa dois assuntos.
                    if (i > 0)
                      Container(
                        height: eg.shapes.hairline,
                        color: tone.edgeOf(eg).color,
                      ),
                    _padded(eg, children[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// O respiro é do cartão, e não de cada coisa que entra nele.
  ///
  /// Era o que faltava: a linha de configuração trazia o próprio recuo, mas
  /// tudo o que não é linha — a faixa de dias do Focus, a lista de destinos do
  /// Nest, o bloco de permissões do Echo — chegava encostado na borda, porque
  /// ninguém tinha dito a essas peças que agora elas moram dentro de um
  /// cartão.
  ///
  /// A linha continua respondendo pela própria altura (é o piso de 38/46 que
  /// dá o ritmo), então ela recebe só o recuo lateral. O resto recebe os dois.
  Widget _padded(EgTokens eg, Widget child) => Padding(
    padding: child is EgSettingsRow
        ? EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH)
        : EdgeInsets.symmetric(
            horizontal: eg.shapes.rowPaddingH,
            vertical: eg.shapes.rowPaddingV + AppSpacing.xxs,
          ),
    child: child,
  );

  Widget _header(EgTokens eg) {
    final label = EgSectionLabel(title!, color: tone.labelOf(eg));

    if (trailing == null) return label;

    return Row(
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}

import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_toggle.dart';

/// Linha de configuração: o rótulo à esquerda, o controle à direita, dentro de
/// um [EgSettingsCard].
///
/// **A altura é 38 sem explicação embaixo, 46 com ela** — mínima, não fixa.
/// É o que faz duas colunas de cartões lado a lado alinharem: sem um piso, cada
/// cartão acharia um ritmo próprio conforme o que tivesse dentro. Mínima, e não
/// travada, porque um controle largo demais para a coluna precisa poder quebrar
/// em vez de estourar a linha — o seletor de cinco durações do Focus é
/// exatamente esse caso.
///
/// A linha **não desenha divisor**: quem separa é o cartão. Era o que obrigava
/// cada tela a saber qual das suas linhas era a última.
class EgSettingsRow extends StatelessWidget {
  const EgSettingsRow({
    super.key,
    required this.label,
    required this.trailing,
    this.description,
  }) : _alwaysStacked = false,
       _stretchTrailing = false;

  /// Atalho para a linha mais comum: rótulo + interruptor.
  EgSettingsRow.toggle({
    super.key,
    required this.label,
    required bool value,
    ValueChanged<bool>? onChanged,
    this.description,
  }) : trailing = EgToggle(value: value, onChanged: onChanged),
       _alwaysStacked = false,
       _stretchTrailing = false;

  /// A linha cuja resposta é um texto que a pessoa escreve.
  ///
  /// O campo desce para baixo do rótulo e ocupa a largura toda, em vez de ir
  /// para a coluna da direita onde moram os outros controles. Quem decide é o
  /// tamanho da resposta: um seletor cabe ao lado do rótulo, um texto de três
  /// linhas não — espremido ele mostraria meia frase por vez e faria escrever
  /// numa fresta.
  const EgSettingsRow.field({
    super.key,
    required this.label,
    required Widget field,
    this.description,
  }) : trailing = field,
       _alwaysStacked = true,
       _stretchTrailing = true;

  final String label;
  final Widget trailing;

  /// A explicação de uma linha sob o rótulo.
  ///
  /// Uma linha, e é para valer: em `footnote` sobre `textTertiary` ela existe
  /// para quem parou naquela linha, não para quem está varrendo a tela. Se
  /// precisa de três linhas para se explicar, o ajuste é que está confuso.
  final String? description;

  /// O controle desce para baixo do rótulo mesmo numa coluna larga.
  final bool _alwaysStacked;

  /// E, descendo, ocupa a linha inteira — o que vale para um campo de texto e
  /// não vale para um seletor, que tem a largura das opções dele.
  final bool _stretchTrailing;

  /// Largura abaixo da qual o controle desce para baixo do rótulo.
  ///
  /// Baixo de propósito: dentro de um cartão de coluna o rótulo e o controle
  /// ficam a um palmo um do outro, que é o ponto. Empilhar só quando nem isso
  /// couber.
  static const _stackBelow = 200.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = _alwaysStacked || constraints.maxWidth < _stackBelow;

        // O rótulo é o nome do controle, e os dois só significam alguma coisa
        // juntos: fundidos, o leitor de tela anuncia "Iniciar com o macOS,
        // ativado" numa parada só. Separados, ele lê um texto solto e, depois,
        // um interruptor sem nome — que é o mesmo que não anunciar.
        return MergeSemantics(
          child: stacked
              ? Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: eg.shapes.rowPaddingH,
                    vertical: eg.shapes.rowPaddingV,
                  ),
                  child: _stacked(context),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: description == null
                        ? eg.shapes.rowHeight
                        : eg.shapes.rowHeightWithFootnote,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: eg.shapes.rowPaddingH,
                      vertical: AppSpacing.xxs,
                    ),
                    child: _inline(context),
                  ),
                ),
        );
      },
    );
  }

  Widget _inline(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _label(context)),
        const SizedBox(width: AppSpacing.md),
        // `Flexible`, e não o controle solto: sem uma restrição de largura, um
        // controle que sabe quebrar (o `Wrap` do segmented) nunca quebra —
        // ele se mede pelo conteúdo e estoura a linha.
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    return Column(
      crossAxisAlignment: _stretchTrailing
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        _label(context),
        const SizedBox(height: AppSpacing.sm),
        // Alinhado à esquerda, sob o rótulo que ele responde — e não centrado
        // nem à direita, que seria o controle procurando um lugar em vez de
        // pertencer a um.
        if (_stretchTrailing)
          trailing
        else
          Align(alignment: Alignment.centerLeft, child: trailing),
      ],
    );
  }

  Widget _label(BuildContext context) {
    final eg = context.eg;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duas linhas antes de truncar: a altura da linha é um piso, não uma
        // trava, e um rótulo cortado no meio da palavra é pior que uma linha
        // de 46 pt virando 60. Quem tem de encolher é a microcópia, e isso se
        // resolve escrevendo, não recortando.
        Text(
          label,
          style: eg.text.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (description != null)
          Text(
            description!,
            style: eg.text.footnote.copyWith(color: eg.colors.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

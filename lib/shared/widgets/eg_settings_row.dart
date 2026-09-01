import 'dart:math' as math;

import 'package:flutter/rendering.dart';
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
/// travada, porque o controle que não cabe ao lado do texto desce para baixo
/// dele e a linha cresce — ver [_LabelAndControl], que é quem mede e decide.
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

  /// O mínimo que o rótulo guarda para si — e, com ele, o que decide se o
  /// controle cabe ao lado do texto ou desce para baixo dele.
  static const _labelFloor = 116.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    // O rótulo é o nome do controle, e os dois só significam alguma coisa
    // juntos: fundidos, o leitor de tela anuncia "Iniciar com o macOS,
    // ativado" numa parada só. Separados, ele lê um texto solto e, depois,
    // um interruptor sem nome — que é o mesmo que não anunciar.
    return MergeSemantics(
      child: _alwaysStacked
          // Só o recuo vertical, como na linha comum: o lateral é do cartão, e
          // pedi-lo de novo aqui empurrava a linha do campo de texto 12 px para
          // dentro. O rótulo dela ficava desalinhado de todos os outros
          // rótulos do cartão — visível numa captura de tela, invisível em
          // qualquer teste que não meça o x.
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: eg.shapes.rowPaddingV),
              child: _stacked(context),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: description == null
                    ? eg.shapes.rowHeight
                    : eg.shapes.rowHeightWithFootnote,
              ),
              // O recuo lateral é do cartão; aqui fica só o vertical, que
              // é o que impede o texto de encostar no divisor.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: _LabelAndControl(
                  children: [_label(context), trailing],
                ),
              ),
            ),
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

/// O layout de uma linha de configuração: o rótulo e o controle, lado a lado
/// **ou** um sobre o outro — e quem decide é o tamanho que o controle pede.
///
/// **Um seletor nunca quebra em duas fileiras.** Ele é uma fila de opções, e
/// uma fila em dois andares deixa de se ler como uma escolha entre poucas
/// coisas: "PT-BR PT-PT EN" numa linha e "ES" na de baixo parece um item
/// esquecido, não a quarta opção. Quando a fila não cabe ao lado do texto, ela
/// **desce inteira** para debaixo dele, onde tem a largura do cartão.
///
/// Isso não se resolve com `Row` e `Flexible`, porque a decisão depende de uma
/// medida que só o layout conhece: quanto o controle pediria se ninguém o
/// apertasse. É o que este render object faz — pergunta a largura intrínseca
/// do controle antes de repartir a linha. O `Wrap` de dentro do seletor
/// continua lá, como último recurso para o controle que não cabe nem na
/// largura toda.
class _LabelAndControl extends MultiChildRenderObjectWidget {
  const _LabelAndControl({required super.children});

  @override
  _RenderLabelAndControl createRenderObject(BuildContext context) =>
      _RenderLabelAndControl();
}

class _LabelAndControlData extends ContainerBoxParentData<RenderBox> {}

class _RenderLabelAndControl extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LabelAndControlData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LabelAndControlData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LabelAndControlData) {
      child.parentData = _LabelAndControlData();
    }
  }

  @override
  void performLayout() {
    final label = firstChild!;
    final control = childAfter(label)!;
    final available = constraints.maxWidth;

    // A largura que o controle pediria sem ninguém apertando: é ela, e não a
    // que ele aceita, que diz se a fila cabe ao lado do texto.
    final wanted = control.getMaxIntrinsicWidth(double.infinity);
    final besideBudget = available - EgSettingsRow._labelFloor - AppSpacing.md;

    if (wanted <= besideBudget) {
      control.layout(
        BoxConstraints(maxWidth: math.max(0, besideBudget)),
        parentUsesSize: true,
      );
      label.layout(
        BoxConstraints(
          maxWidth: math.max(0, available - AppSpacing.md - control.size.width),
        ),
        parentUsesSize: true,
      );

      size = constraints.constrain(
        Size(available, math.max(label.size.height, control.size.height)),
      );

      // Centrados um no outro: o controle é a resposta do rótulo, e responde
      // na altura dele, não no topo da linha.
      _offsetOf(label).offset = Offset(0, (size.height - label.size.height) / 2);
      _offsetOf(control).offset = Offset(
        available - control.size.width,
        (size.height - control.size.height) / 2,
      );
      return;
    }

    label.layout(BoxConstraints(maxWidth: available), parentUsesSize: true);
    control.layout(BoxConstraints(maxWidth: available), parentUsesSize: true);

    size = constraints.constrain(
      Size(
        available,
        label.size.height + AppSpacing.sm + control.size.height,
      ),
    );

    // Encostado à esquerda, debaixo do rótulo que ele responde — a mesma
    // regra do controle empilhado de um campo de texto.
    _offsetOf(label).offset = Offset.zero;
    _offsetOf(control).offset = Offset(0, label.size.height + AppSpacing.sm);
  }

  _LabelAndControlData _offsetOf(RenderBox child) =>
      child.parentData! as _LabelAndControlData;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

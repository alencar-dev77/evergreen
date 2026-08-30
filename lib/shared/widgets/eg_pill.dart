import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_hoverable.dart';
import 'eg_surface.dart';

/// O tom de uma pílula — o significado dela, não a cor.
///
/// Quem chama diz o que a pílula quer dizer; qual verde, qual âmbar e qual
/// azul é assunto do tema. É o que impede um "em andamento" âmbar numa tela e
/// verde na vizinha.
enum EgPillTone {
  /// Ligado, ativo, presente. O accent.
  positive,

  /// Em curso, sendo processado, tempo de reunião.
  ember,

  /// Informação neutra que ainda assim precisa de cor — arquivo, sistema.
  tide,

  /// Sem cor própria: uma contagem, um rótulo.
  neutral;

  Color colorOf(EgTokens eg) => switch (this) {
    EgPillTone.positive => eg.colors.accent,
    EgPillTone.ember => eg.colors.ember,
    EgPillTone.tide => eg.colors.tide,
    EgPillTone.neutral => eg.colors.textTertiary,
  };

  /// A cor do rótulo: clara o bastante para se ler sobre o fundo a 13%.
  Color labelOf(EgTokens eg) => switch (this) {
    EgPillTone.positive => eg.colors.accentLight,
    EgPillTone.ember => eg.colors.ember,
    EgPillTone.tide => eg.colors.tide,
    EgPillTone.neutral => eg.colors.textSecondary,
  };
}

/// Uma pílula: bolinha de estado, rótulo, e nada mais.
///
/// O fundo é a própria cor do tom a 13% e a borda a 30% — nunca a cor cheia.
/// Cheia, ela viraria um botão, e uma pílula **não é clicável**: ela informa.
/// Quando precisa ser clicável (o filtro de uma lista), quem responde é o
/// [EgFilterPills], que tem estado de escolha.
class EgPill extends StatelessWidget {
  const EgPill({
    super.key,
    required this.label,
    this.tone = EgPillTone.neutral,
    this.showDot = true,
  });

  final String label;
  final EgPillTone tone;

  /// A bolinha de 5 pt à esquerda. Desligue quando a pílula for um rótulo, e
  /// não um estado — uma bolinha ao lado de "nada é gravado aqui" prometeria
  /// um estado que muda.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final color = tone.colorOf(eg);

    return Container(
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: eg.shapes.chipAll,
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: eg.shapes.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            EgStatusDot(color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: eg.text.footnote.copyWith(color: tone.labelOf(eg)),
            ),
          ),
        ],
      ),
    );
  }

  static const _height = 26.0;
}

/// A bolinha de estado de 5 pt.
///
/// Sozinha ela é o menor jeito de dizer "ligado" que existe na interface, e é
/// por isso que ela aparece na barra lateral, na faixa de estado e dentro da
/// pílula: é sempre a mesma coisa, do mesmo tamanho, com a mesma cor.
class EgStatusDot extends StatelessWidget {
  const EgStatusDot({super.key, required this.color, this.size = 5});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A fileira de filtros de uma lista — `Tudo · Fixados · Links`.
///
/// **Abaixo do campo de busca, nunca ao lado dele.** Ao lado, elas dividem a
/// linha com o texto digitado, e some justamente quando a busca cresce, que é
/// quando filtrar mais ajuda.
class EgFilterPills<T> extends StatelessWidget {
  const EgFilterPills({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.countOf,
    this.onGlass = false,
    this.height = _height,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;

  /// A contagem impressa ao lado do rótulo, em mono. `null` — ou um retorno
  /// nulo — some com ela.
  final String? Function(T)? countOf;

  final ValueChanged<T> onSelected;

  /// A fileira mora sobre o vidro de um painel flutuante.
  final bool onGlass;

  /// A altura da pílula. O padrão é a do filtro; a aba de tela é um degrau
  /// acima, porque ela governa a tela inteira e não só uma lista.
  final double height;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final style = onGlass ? eg.surfaces.glassRow : eg.surfaces.row;

    return Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final value in values)
          EgInteractiveSurface(
            onTap: () => onSelected(value),
            style: style,
            isSelected: value == selected,
            borderRadius: eg.shapes.chipAll,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH),
            semanticLabel: labelOf(value),
            builder: (context, state) => _label(context, value, state, style),
          ),
      ],
    );
  }

  Widget _label(
    BuildContext context,
    T value,
    EgInteraction state,
    EgSurfaceStyle style,
  ) {
    final eg = context.eg;
    final isSelected = value == selected;
    final count = countOf?.call(value);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labelOf(value),
          style: (isSelected ? eg.text.bodyStrong : eg.text.bodyCompact)
              .copyWith(
                color: style.foregroundFor(state, isSelected: isSelected),
              ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            count,
            style: eg.text.monoSmall.copyWith(color: eg.colors.textTertiary),
          ),
        ],
      ],
    );
  }

  static const _height = 24.0;
}

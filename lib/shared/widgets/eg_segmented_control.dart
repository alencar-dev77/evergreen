import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_icon.dart';
import 'eg_surface.dart';
import '../../core/design/eg_tokens.dart';

/// Seletor de opção única em formato de pílulas.
///
/// Usado onde um toggle não basta mas um dropdown seria pesado demais — por
/// exemplo, o tamanho do histórico do Pin.
///
/// O foco vive no controle inteiro, não em cada segmento: quando ele está
/// focado, ← e → trocam a opção. É como um segmented control nativo se comporta
/// e evita que o Tab pare em cada pílula.
class EgSegmentedControl<T> extends StatefulWidget {
  const EgSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.bare = false,
    this.focusable = true,
    this.iconOf,
  });

  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;

  /// Sem a caixa em volta — só as pílulas.
  ///
  /// É a variante de dentro de um painel que já é uma superfície: a caixa ali
  /// seria um card dentro de um card (ver `anti-patterns.md`). Mesma ideia do
  /// `bare` do [EgSearchField], que perde a moldura ao virar a linha do topo do
  /// overlay.
  final bool bare;

  /// Entra na navegação por Tab e responde a ← / →.
  ///
  /// Desligue onde o teclado já pertence a outra coisa — no overlay do Pin o
  /// foco é sempre do campo de busca, e o Tab abre o preview; ali quem anda
  /// pela fila é o `⌘←` / `⌘→` do próprio painel.
  final bool focusable;

  /// O ícone de cada opção, para quando os rótulos não cabem numa linha.
  ///
  /// Sem ele, o controle quebra linha (ver o `Wrap` em [build]). Com ele, a
  /// fila que não cabe fica numa linha só: as opções que têm ícone mostram só
  /// o ícone, e a escolhida mostra ícone e rótulo — é a fila do Pin com todos
  /// os tipos no histórico, que quebrava e deixava "Imagens" sozinha embaixo.
  /// Opção sem ícone (o "Tudo") continua com o rótulo. Onde os rótulos cabem,
  /// nada muda.
  final EgIconData? Function(T option)? iconOf;

  @override
  State<EgSegmentedControl<T>> createState() => _EgSegmentedControlState<T>();
}

class _EgSegmentedControlState<T> extends State<EgSegmentedControl<T>> {
  bool _isFocused = false;

  void _setFocused(bool value) {
    if (_isFocused == value) return;
    setState(() => _isFocused = value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;

    final current = widget.options.indexOf(widget.value);
    if (current < 0) return KeyEventResult.ignored;

    final next = (current + delta).clamp(0, widget.options.length - 1);
    if (next != current) widget.onChanged(widget.options[next]);

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final control = _control();
    if (!widget.focusable) return control;

    return Focus(
      onFocusChange: _setFocused,
      onKeyEvent: _handleKey,
      child: control,
    );
  }

  /// Os rótulos inteiros cabem em [maxWidth]?
  ///
  /// A conta é a do `Wrap` numa linha: cada rótulo no estilo em que ele vai
  /// aparecer, mais o padding da pílula e o vão entre elas.
  bool _labelsFit(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final padding = 2 * _Segment.horizontalPadding(bare: widget.bare);
    final spacing = widget.bare ? AppSpacing.xxs : 0.0;

    var width = widget.bare ? 0.0 : 2 * AppSpacing.xxxs;
    for (final (index, option) in widget.options.indexed) {
      final painter = TextPainter(
        text: TextSpan(
          text: widget.labelOf(option),
          style: option == widget.value
              ? context.eg.text.bodyEmphasis
              : context.eg.text.caption,
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += painter.width + padding + (index == 0 ? 0 : spacing);
      painter.dispose();
    }

    return width <= maxWidth;
  }

  Widget _control() {
    if (widget.iconOf == null) return _box(compact: false);

    return LayoutBuilder(
      builder: (context, constraints) => _box(
        compact:
            constraints.hasBoundedWidth &&
            !_labelsFit(context, constraints.maxWidth),
      ),
    );
  }

  Widget _box({required bool compact}) {
    return AnimatedContainer(
      duration: AppDurations.instant,
      curve: AppDurations.curve,
      padding: widget.bare
          ? EdgeInsets.zero
          : const EdgeInsets.all(AppSpacing.xxxs),
      decoration: widget.bare
          ? null
          : BoxDecoration(
              color: context.eg.colors.surface,
              borderRadius: context.eg.shapes.segmentAll,
              border: context.eg.borderAll,
              boxShadow: _isFocused ? context.eg.elevations.focusRing : null,
            ),
      // `Wrap`, e não `Row`: com cinco opções (as durações do Focus) o
      // controle pede uns 460px, e numa janela estreita ele sozinho não cabe
      // na coluna. Quebrando linha, as opções continuam todas visíveis e
      // clicáveis — rolar ou recortar esconderia opção, que num seletor é o
      // mesmo que apagá-la. Onde há largura, nada muda: a fila cabe inteira
      // numa linha só.
      child: Wrap(
        // Sem a caixa, as pílulas precisam de um vão entre elas: encostadas,
        // duas superfícies de seleção vizinhas leriam como uma só.
        spacing: widget.bare ? AppSpacing.xxs : 0,
        runSpacing: AppSpacing.xxxs,
        children: [
          for (final option in widget.options)
            _Segment(
              label: widget.labelOf(option),
              isSelected: option == widget.value,
              onTap: () => widget.onChanged(option),
              bare: widget.bare,
              icon: compact ? widget.iconOf!(option) : null,
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.bare = false,
    this.icon,
  });

  static double horizontalPadding({required bool bare}) =>
      bare ? AppSpacing.xs : AppSpacing.md;

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Sem a caixa em volta, a pílula respira menos por dentro: o vão entre as
  /// pílulas já as separa, e o padding largo existia para elas não encostarem
  /// na moldura. São 8px por pílula — o que decide se a fila do Pin cabe numa
  /// linha só quando o histórico tem os seis tipos, e uma segunda linha com uma
  /// pílula órfã custaria mais altura do que ela vale num painel que se lê de
  /// relance.
  final bool bare;

  /// Na fila compacta: o ícone no lugar do rótulo, e ao lado dele na opção
  /// escolhida. `null` é o rótulo de sempre.
  final EgIconData? icon;

  @override
  Widget build(BuildContext context) {
    // Fora da navegação por Tab: o foco vive no controle inteiro, e as setas é
    // que trocam a opção. Um ponto de parada por pílula faria o Tab andar três
    // vezes para atravessar uma preferência só.
    //
    // A opção escolhida usa accent em baixa opacidade — o mesmo tratamento de
    // seleção da lista e da sidebar, resolvido na matriz (`EgSurfaces.segment`)
    // e não aqui. Preenchimento verde sólido puxaria o olho para uma
    // preferência que não é a ação principal de tela nenhuma.
    return EgInteractiveSurface(
      onTap: onTap,
      focusable: false,
      style: context.eg.surfaces.segment,
      isSelected: isSelected,
      // Concêntrico com o container: 6px do pai menos os 2px de padding.
      borderRadius: context.eg.shapes.segmentAll,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding(bare: bare),
        vertical: AppSpacing.xxs,
      ),
      // Só o ícone na tela, então quem diz o nome ao leitor de tela é a
      // superfície. Com o rótulo visível, ele mesmo é a etiqueta.
      semanticLabel: icon == null ? null : label,
      builder: (context, state) {
        final style = isSelected
            ? context.eg.text.bodyEmphasis
            : context.eg.text.caption;
        final color = context.eg.surfaces.segment.foregroundFor(
          state,
          isSelected: isSelected,
        );
        final text = Text(label, style: style.copyWith(color: color));

        final glyph = icon;
        if (glyph == null) return text;

        // A altura da linha do rótulo, para a pílula de ícone não ficar mais
        // baixa que a do "Tudo" ao lado dela.
        final iconRow = SizedBox(
          height: style.fontSize! * style.height!,
          child: Center(
            widthFactor: 1,
            child: EgIcon(glyph, size: AppIconSizes.xs, color: color),
          ),
        );
        if (!isSelected) return iconRow;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconRow,
            const SizedBox(width: AppSpacing.xxs),
            text,
          ],
        );
      },
    );
  }
}

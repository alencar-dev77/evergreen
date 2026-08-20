import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_surface.dart';

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

  Widget _control() {
    return AnimatedContainer(
      duration: AppDurations.instant,
      curve: AppDurations.curve,
      padding: widget.bare
          ? EdgeInsets.zero
          : const EdgeInsets.all(AppSpacing.xxxs),
      decoration: widget.bare
          ? null
          : BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadii.badgeAll,
              border: AppBorders.all,
              boxShadow: _isFocused ? AppShadows.focusRing : null,
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
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Fora da navegação por Tab: o foco vive no controle inteiro, e as setas é
    // que trocam a opção. Um ponto de parada por pílula faria o Tab andar três
    // vezes para atravessar uma preferência só.
    //
    // A opção escolhida usa accent em baixa opacidade — o mesmo tratamento de
    // seleção da lista e da sidebar. Preenchimento verde sólido puxaria o olho
    // para uma preferência que não é a ação principal de tela nenhuma.
    return EgInteractiveSurface(
      onTap: onTap,
      focusable: false,
      style: EgSurfaceStyle.segment,
      isSelected: isSelected,
      // Concêntrico com o container: 6px do pai menos os 2px de padding.
      borderRadius: AppRadii.badgeSmallAll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      builder: (context, state) {
        final style = isSelected
            ? AppTypography.captionSmallEmphasis
            : AppTypography.captionSmall;

        return Text(
          label,
          style: style.copyWith(
            color: EgSurfaceStyle.segment.foregroundFor(
              state,
              isSelected: isSelected,
            ),
          ),
        );
      },
    );
  }
}

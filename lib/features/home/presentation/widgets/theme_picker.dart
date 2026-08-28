import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_theme_id.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_surface.dart';

/// O seletor de aparência: as duas peles, lado a lado, mostradas em vez de
/// nomeadas.
///
/// Uma pílula escrita "Apple" não responde à única pergunta que importa aqui —
/// *como fica?*. A miniatura responde: cada uma é desenhada **com os tokens do
/// tema que representa**, então ela não é uma ilustração que alguém precisa
/// lembrar de atualizar; é o próprio tema, pequeno. Mexer numa cor do Apple
/// muda a miniatura dele no mesmo commit.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});

  final AppThemeId value;
  final ValueChanged<AppThemeId> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final theme in AppThemeId.values) ...[
          if (theme != AppThemeId.values.first)
            const SizedBox(width: AppSpacing.md),
          _ThemeOption(
            theme: theme,
            isSelected: theme == value,
            onTap: () => onChanged(theme),
          ),
        ],
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeId theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgHoverable(
      onTap: onTap,
      selected: isSelected ? true : null,
      semanticLabel: 'Aparência ${theme.label}',
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EgSurface(
            state: state,
            isSelected: isSelected,
            style: eg.surfaces.card,
            borderRadius: eg.shapes.cardAll,
            padding: EdgeInsets.zero,
            child: _Thumbnail(theme: theme),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            theme.label,
            style: isSelected
                ? eg.text.captionSmallEmphasis.copyWith(color: eg.colors.accent)
                : eg.text.captionSmall,
          ),
        ],
      ),
    );
  }
}

/// A janela do Evergreen em miniatura, pintada pelo tema que ela representa.
///
/// Quatro elementos, que são os quatro que mudam de verdade entre as peles: o
/// fundo, a sidebar, uma linha selecionada e uma linha comum. Não é uma
/// captura de tela reduzida — em 96px uma captura vira borrão, e o que se
/// precisa comparar aqui é a cor e a densidade, não o conteúdo.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.theme});

  final AppThemeId theme;

  static const _width = 108.0;
  static const _height = 68.0;

  @override
  Widget build(BuildContext context) {
    // Os tokens **do tema desenhado**, não os do tema em vigor: é isto que faz
    // a miniatura do Apple continuar sendo o Apple enquanto o app está no
    // Evergreen.
    final eg = EgTokens.of(theme);

    return SizedBox(
      width: _width,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: eg.gradients.windowBackground),
        child: Row(
          children: [
            // A sidebar.
            Container(
              width: _width * 0.3,
              decoration: BoxDecoration(
                color: eg.colors.sidebar,
                border: Border(
                  right: BorderSide(
                    color: eg.colors.border,
                    width: eg.shapes.hairline,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Line(eg: eg, isSelected: true),
                    const SizedBox(height: AppSpacing.xxs),
                    _Line(eg: eg, isSelected: false),
                    const SizedBox(height: AppSpacing.xxs),
                    _Line(eg: eg, isSelected: false, short: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma linha da lista da miniatura — e é ela que carrega a diferença mais
/// visível entre as duas peles: a seleção suave com aresta do Evergreen e a
/// seleção sólida em accent do Apple.
class _Line extends StatelessWidget {
  const _Line({required this.eg, required this.isSelected, this.short = false});

  final EgTokens eg;
  final bool isSelected;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final gradient = eg.colors.selectionGradient;

    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: short ? 0.6 : 1,
        child: Container(
          height: 9,
          decoration: BoxDecoration(
            color: isSelected
                ? (gradient == null ? eg.colors.selection : null)
                : eg.colors.card,
            gradient: isSelected && gradient != null
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient,
                  )
                : null,
            borderRadius: eg.shapes.rowAll,
            border: isSelected && eg.shapes.selectionEdge > 0
                ? Border(
                    left: BorderSide(
                      color: eg.colors.accent,
                      width: eg.shapes.selectionEdge,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

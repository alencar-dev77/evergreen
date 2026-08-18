@Tags(['preview'])
library;

import 'package:evergreen/core/design/app_colors.dart';
import 'package:evergreen/core/design/app_metrics.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/design/app_typography.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_hoverable.dart';
import 'package:evergreen/shared/widgets/eg_icon.dart';
import 'package:evergreen/shared/widgets/eg_key_cap.dart';
import 'package:evergreen/shared/widgets/eg_nav_tile.dart';
import 'package:evergreen/shared/widgets/eg_segmented_control.dart';
import 'package:evergreen/shared/widgets/eg_surface.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_fonts.dart';

/// A folha de estados do design system, em uma imagem.
///
/// Cada coluna da matriz (`EgSurfaceStyle`) aparece com os seis estados lado a
/// lado, e abaixo dela os componentes reais nos estados que uma imagem
/// consegue mostrar — inclusive hover e pressed, simulados com ponteiros de
/// verdade em widgets diferentes ao mesmo tempo.
///
/// Serve para a conferência que texto nenhum faz: ver, de uma vez, se
/// "selecionado" continua distinto de "hover" em todos os componentes, e se
/// nenhum deles ficou sem um dos estados obrigatórios. Fora da suíte padrão,
/// como os outros goldens de preview:
///
/// ```
/// flutter test --run-skipped -t preview --update-goldens
/// ```
void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('matriz de estado dos componentes', (tester) async {
    tester.view.physicalSize = const Size(2000, 1240);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const ColoredBox(
          color: AppColors.background,
          child: _StateMatrixGallery(),
        ),
      ),
    );

    // Hover e pressed em componentes diferentes, no mesmo quadro: são dois
    // ponteiros independentes, e é assim que a imagem mostra os dois estados
    // sem precisar de dois goldens.
    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await hover.addPointer(
      location: tester.getCenter(find.byKey(const Key('toggle-hover'))),
    );
    addTearDown(hover.removePointer);

    final press = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('button-pressed'))),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_StateMatrixGallery),
      matchesGoldenFile('goldens/design_state_matrix.png'),
    );

    await press.up();
    await tester.pumpAndSettle();
  });
}

class _StateMatrixGallery extends StatelessWidget {
  const _StateMatrixGallery();

  static const _styles = <String, EgSurfaceStyle>{
    'row': EgSurfaceStyle.row,
    'ghost': EgSurfaceStyle.ghost,
    'card': EgSurfaceStyle.card,
    'segment': EgSurfaceStyle.segment,
    'primary': EgSurfaceStyle.primary,
    'secondary': EgSurfaceStyle.secondary,
    'destructive': EgSurfaceStyle.destructive,
  };

  static const _states = <String, EgInteraction>{
    'repouso': EgInteraction(),
    'hover': EgInteraction(isHovered: true),
    'pressed': EgInteraction(isPressed: true),
    'foco': EgInteraction(isFocused: true),
    'selecionado': EgInteraction(),
    'desabilitado': EgInteraction(),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Matriz de estado', style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Toda superfície interativa do Evergreen resolve o próprio fundo '
            'por esta tabela.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _header(),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in _styles.entries) ...[
            _row(entry.key, entry.value),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xxl),
          const _Components(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const SizedBox(width: _labelWidth),
        for (final name in _states.keys)
          SizedBox(
            width: _cellWidth,
            child: Text(name.toUpperCase(), style: AppTypography.overline),
          ),
      ],
    );
  }

  Widget _row(String name, EgSurfaceStyle style) {
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(name, style: AppTypography.bodyCompactEmphasis),
        ),
        for (final entry in _states.entries)
          SizedBox(
            width: _cellWidth,
            child: _cell(style, entry.key, entry.value),
          ),
      ],
    );
  }

  Widget _cell(EgSurfaceStyle style, String name, EgInteraction state) {
    final isSelected = name == 'selecionado';
    final isEnabled = name != 'desabilitado';

    // A coluna sem estado selecionado deixa a célula vazia em vez de repetir o
    // repouso: o buraco na tabela é a informação.
    if (isSelected && style.selected == null) {
      return Text('—', style: AppTypography.captionXS);
    }

    return Opacity(
      opacity: isEnabled ? 1 : style.disabledOpacity,
      child: EgSurface(
        state: state,
        style: style,
        isSelected: isSelected,
        isEnabled: isEnabled,
        width: _swatchWidth,
        height: 34,
        alignment: Alignment.center,
        child: Text(
          'Rótulo',
          style: AppTypography.bodyCompactEmphasis.copyWith(
            color: style.foregroundFor(
              state,
              isSelected: isSelected,
              isEnabled: isEnabled,
            ),
          ),
        ),
      ),
    );
  }

  static const _labelWidth = 108.0;
  static const _cellWidth = 138.0;
  static const _swatchWidth = 122.0;
}

/// Os componentes reais, nos estados que uma imagem estática alcança — mais o
/// hover e o pressed que o teste injeta.
class _Components extends StatelessWidget {
  const _Components();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('Botões', [
          Row(
            children: [
              EgButton(label: 'Primário', onPressed: () {}),
              const SizedBox(width: AppSpacing.sm),
              EgButton(
                key: const Key('button-pressed'),
                label: 'Pressionado',
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              EgButton.secondary(label: 'Secundário', onPressed: () {}),
              const SizedBox(width: AppSpacing.sm),
              EgButton.destructive(label: 'Excluir', onPressed: () {}),
              const SizedBox(width: AppSpacing.sm),
              const EgButton(label: 'Indisponível'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              EgIconButton(icon: EgIconData.star, onPressed: () {}),
              const SizedBox(width: AppSpacing.sm),
              const EgShortcutDisplay(keys: ['⌘', '⇧', 'C']),
            ],
          ),
        ]),
        const SizedBox(width: AppSpacing.huge),
        _group('Switch', [
          Row(
            children: [
              EgToggle(value: true, onChanged: (_) {}),
              const SizedBox(width: AppSpacing.md),
              EgToggle(
                key: const Key('toggle-hover'),
                value: false,
                onChanged: (_) {},
              ),
              const SizedBox(width: AppSpacing.md),
              const EgToggle(value: true),
              const SizedBox(width: AppSpacing.md),
              const EgToggle(value: false),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          EgSegmentedControl<String>(
            value: '30 min',
            options: const ['15 min', '30 min', '1 h'],
            labelOf: (option) => option,
            onChanged: (_) {},
          ),
        ]),
        const SizedBox(width: AppSpacing.huge),
        _group('Navegação', [
          SizedBox(
            width: 232,
            child: Column(
              children: [
                EgNavTile(
                  icon: EgIconData.evergreen,
                  title: 'Pin',
                  subtitle: 'Histórico da área de transferência',
                  isSelected: true,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.xxs),
                EgNavTile(
                  icon: EgIconData.timer,
                  title: 'Focus',
                  subtitle: 'Cronômetro de foco',
                  isSelected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTypography.overline),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }
}

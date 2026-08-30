@Tags(['preview'])
library;

import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/core/design/app_metrics.dart';
import 'package:evergreen/core/design/app_theme.dart';
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

  /// A folha de todos os estados de todas as famílias.
  ///
  /// É o que prende a matriz: um hover que sumiu, uma seleção sem contraste ou
  /// uma linha de luz que deixou de acender não quebram teste nenhum de
  /// comportamento — quebram esta imagem.
  testWidgets('matriz de estado dos componentes', (tester) async {
      tester.view.physicalSize = const Size(2000, 1240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: ColoredBox(
            color: EgTokens.evergreen().colors.canvas,
            child: const _StateMatrixGallery(),
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

  static Map<String, EgSurfaceStyle> _stylesOf(BuildContext context) {
    final surfaces = context.eg.surfaces;

    return {
      'row': surfaces.row,
      'ghost': surfaces.ghost,
      'card': surfaces.card,
      'segment': surfaces.segment,
      'primary': surfaces.primary,
      'secondary': surfaces.secondary,
      'destructive': surfaces.destructive,
    };
  }

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
          Text('Matriz de estado', style: context.eg.text.display),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Toda superfície interativa do Evergreen resolve o próprio fundo '
            'por esta tabela.',
            style: context.eg.text.caption,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _header(context),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in _stylesOf(context).entries) ...[
            _row(context, entry.key, entry.value),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xxl),
          const _Components(),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: _labelWidth),
        for (final name in _states.keys)
          SizedBox(
            width: _cellWidth,
            child: Text(name.toUpperCase(), style: context.eg.text.overline),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String name, EgSurfaceStyle style) {
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(name, style: context.eg.text.bodyEmphasis),
        ),
        for (final entry in _states.entries)
          SizedBox(
            width: _cellWidth,
            child: _cell(context, style, entry.key, entry.value),
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    EgSurfaceStyle style,
    String name,
    EgInteraction state,
  ) {
    final isSelected = name == 'selecionado';
    final isEnabled = name != 'desabilitado';

    // A coluna sem estado selecionado deixa a célula vazia em vez de repetir o
    // repouso: o buraco na tabela é a informação.
    if (isSelected && style.selected == null) {
      return Text('—', style: context.eg.text.footnote);
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
          style: context.eg.text.bodyEmphasis.copyWith(
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
        _group(context, 'Botões', [
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
        _group(context, 'Switch', [
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
        _group(context, 'Navegação', [
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

  Widget _group(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: context.eg.text.overline),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }
}

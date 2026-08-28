import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_theme_id.dart';
import 'eg_tokens.dart';

/// Monta o `ThemeData` de um tema do Evergreen.
///
/// Todas as janelas (Hub e overlays) usam o mesmo, e é assim que os seis
/// módulos parecem o mesmo aplicativo — inclusive na hora de trocar de
/// aparência, que troca as duas ao mesmo tempo.
///
/// Este arquivo **não escolhe cor nenhuma**: ele traduz os tokens do
/// [EgTokens] para os campos que o Material exige. Quem tem valores é
/// `themes/evergreen_tokens.dart` e `themes/apple_tokens.dart`.
abstract final class AppTheme {
  static ThemeData build([AppThemeId id = AppThemeId.evergreen]) {
    final base = ThemeData.dark(useMaterial3: true);
    final eg = EgTokens.of(id);
    final colors = eg.colors;

    return base.copyWith(
      extensions: [eg],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.error,
        outline: colors.border,
      ),
      textTheme: _textTheme(base.textTheme, eg),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: eg.shapes.hairline,
        space: eg.shapes.hairline,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.textSelection,
        selectionHandleColor: colors.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(colors.border),
        trackColor: const WidgetStatePropertyAll(Color(0x00000000)),
        crossAxisMargin: 2,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x00000000),
      hoverColor: colors.hover,
      visualDensity: VisualDensity.compact,
    );
  }

  static TextTheme _textTheme(TextTheme base, EgTokens eg) => base.copyWith(
    displayLarge: eg.text.screenTitle,
    headlineMedium: eg.text.sectionTitle,
    titleMedium: eg.text.panelTitle,
    titleSmall: eg.text.bodyEmphasis,
    bodyLarge: eg.text.body,
    bodyMedium: eg.text.bodyCompact,
    bodySmall: eg.text.caption,
    labelSmall: eg.text.overline,
    labelLarge: eg.text.button,
  );
}

/// Remove o glow de overscroll do Material e habilita arraste do scroll com o
/// mouse — o comportamento esperado num app desktop.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => RawScrollbar(
    controller: details.controller,
    thumbColor: context.eg.colors.border,
    radius: const Radius.circular(3),
    thickness: 6,
    crossAxisMargin: 2,
    child: child,
  );
}

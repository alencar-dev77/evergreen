import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'eg_tokens.dart';

/// Monta o `ThemeData` do Evergreen.
///
/// Todas as janelas (Hub e overlays) usam o mesmo, e é assim que os sete
/// módulos parecem o mesmo aplicativo.
///
/// Este arquivo **não escolhe cor nenhuma**: ele traduz os tokens do
/// [EgTokens] para os campos que o Material exige. Quem tem valores é
/// `themes/evergreen_tokens.dart`.
abstract final class AppTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    final eg = EgTokens.evergreen();
    final colors = eg.colors;

    return base.copyWith(
      extensions: [eg],
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.error,
        outline: colors.line,
      ),
      textTheme: _textTheme(base.textTheme, eg),
      dividerTheme: DividerThemeData(
        color: colors.line,
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
        thumbColor: WidgetStatePropertyAll(colors.line),
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
    displayLarge: eg.text.display,
    headlineMedium: eg.text.title,
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
    thumbColor: context.eg.colors.line,
    radius: const Radius.circular(3),
    thickness: 6,
    crossAxisMargin: 2,
    child: child,
  );
}

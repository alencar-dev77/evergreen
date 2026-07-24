import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Tema único do Evergreen. Todas as janelas (Hub e overlays) o compartilham,
/// garantindo que os módulos pareçam o mesmo aplicativo.
abstract final class AppTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.greenPrimary,
        onPrimary: AppColors.background,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        outline: AppColors.border,
      ),
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.greenPrimary,
        selectionColor: Color(0x4022C55E),
        selectionHandleColor: AppColors.greenPrimary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: const WidgetStatePropertyAll(AppColors.border),
        trackColor: const WidgetStatePropertyAll(Color(0x00000000)),
        crossAxisMargin: 2,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x00000000),
      hoverColor: AppColors.hover,
      visualDensity: VisualDensity.compact,
    );
  }

  static TextTheme _textTheme(TextTheme base) => base.copyWith(
        displayLarge: AppTypography.screenTitle,
        headlineMedium: AppTypography.sectionTitle,
        titleMedium: AppTypography.panelTitle,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.bodyCompact,
        bodySmall: AppTypography.caption,
        labelSmall: AppTypography.overline,
        labelLarge: AppTypography.button,
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
  ) =>
      child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      RawScrollbar(
        controller: details.controller,
        thumbColor: AppColors.border,
        radius: const Radius.circular(3),
        thickness: 6,
        crossAxisMargin: 2,
        child: child,
      );
}

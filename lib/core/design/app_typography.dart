import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Escala tipográfica do Evergreen.
///
/// Fonte: Inter, com fallback para SF Pro Display / sistema. Como o app é
/// macOS-first, o fallback nativo já entrega a leitura correta mesmo sem o
/// arquivo da Inter empacotado.
abstract final class AppTypography {
  static const fontFamily = 'Inter';

  static const fontFamilyFallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    '.AppleSystemUIFont',
    'Helvetica Neue',
  ];

  static const _base = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );

  /// Título de tela — 700 / 32px.
  static final screenTitle = _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
    height: 1.2,
  );

  /// Cabeçalho de seção — 600 / 20px.
  static final sectionTitle = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Título de painel compacto — 700 / 16px.
  static final panelTitle = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Texto de item / label de UI — 500 / 15px.
  static final body = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Variante compacta usada dentro do overlay — 500 / 13.5px.
  static final bodyCompact = _base.copyWith(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Texto secundário, metadados e timestamps — 400 / 13px.
  static final caption = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Metadado menor dentro de list items — 400 / 12px.
  static final captionSmall = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Header de seção em caixa alta — 600 / 11px com tracking largo.
  static final overline = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.66,
    height: 1.3,
  );

  /// Label de botão — 600 / 14px.
  static final button = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Conteúdo monoespaçado (key-caps, preview de comandos).
  static const mono = TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: ['Menlo', 'monospace'],
    fontSize: 12,
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );
}

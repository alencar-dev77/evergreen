import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Escala tipográfica do Evergreen.
///
/// Fonte: Inter, com fallback para SF Pro Display / sistema. Como o app é
/// macOS-first, o fallback nativo já entrega a leitura correta mesmo sem o
/// arquivo da Inter empacotado.
///
/// A escala é curta e desktop: corpo em 13–14px, nada de título heroico. O
/// maior estilo do app (17px) é o cabeçalho do Hub — em um utilitário de
/// produtividade não existe "hero" (ver `typography.md`).
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

  /// Título de tela — 600 / 17px. É o cabeçalho funcional de um painel, não um
  /// hero: o maior texto do app fica a um degrau do corpo, não a três.
  static final screenTitle = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Cabeçalho de seção — 600 / 15px.
  static final sectionTitle = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Título de painel compacto — 600 / 15px.
  static final panelTitle = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Corpo padrão — 400 / 14px.
  static final body = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Corpo enfatizado — 500 / 14px. Título dentro de uma linha, valor em vez de
  /// rótulo: hierarquia por peso, sem gastar altura extra.
  static final bodyEmphasis = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Corpo forte — 600 / 14px, tracking -0.2. O degrau acima do
  /// [bodyEmphasis], reservado a nome próprio numa linha: a marca do Evergreen
  /// no rodapé da sidebar. Tem o peso e o tracking do [screenTitle] em tamanho
  /// de corpo — é o mesmo texto, só que dentro de uma lista.
  static final bodyStrong = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );

  /// Variante compacta usada dentro do overlay — 400 / 13px.
  /// Leitura longa — 400 / 14px, entrelinha 1.65.
  ///
  /// Para texto que se lê em parágrafos, e não em linha de lista: a
  /// transcrição de uma reunião. A entrelinha é maior que a do [body] porque
  /// aqui o olho percorre muitas linhas seguidas, e é ela que impede que ele se
  /// perca ao voltar para o começo da próxima.
  static final reading = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.65,
  );

  static final bodyCompact = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Compacto enfatizado — 500 / 13px. Título de linha de lista e rótulo de
  /// configuração.
  static final bodyCompactEmphasis = _base.copyWith(
    fontSize: 13,
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

  /// Metadado menor enfatizado — 600 / 12px. A opção escolhida de um segmented
  /// control. Peso 600, e não os 500 do resto da escala, porque num controle
  /// denso a pílula selecionada precisa se separar das vizinhas sem mudar de
  /// tamanho — e mudar de tamanho faria as pílulas dançarem a cada escolha.
  static final captionSmallEmphasis = captionSmall.copyWith(
    fontWeight: FontWeight.w600,
  );

  /// Menor metadado da interface — 400 / 11px. Timestamp de linha, rótulo de
  /// dica de atalho, subtítulo de item de sidebar.
  static final captionXS = _base.copyWith(
    fontSize: 11,
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

  /// Contagem regressiva do Focus — 500 / 36px, algarismos tabulares.
  ///
  /// É a exceção prevista em `typography.md` para "um número de destaque
  /// isolado": aqui o número não decora a tela, ele *é* a tela. Peso 500 e não
  /// 600 porque em 36px o semibold já grita; os dígitos tabulares impedem que a
  /// linha dance a cada segundo.
  static final timer = _base.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    height: 1.1,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Conteúdo monoespaçado (key-caps, preview de comandos).
  static const mono = TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: ['Menlo', 'monospace'],
    fontSize: 12,
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );

  /// Mono no tamanho de key-cap e de badge de atalho — 11px.
  static final monoSmall = mono.copyWith(fontSize: 11);
}

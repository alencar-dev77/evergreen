import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Raios de canto padronizados.
///
/// A escala é deliberadamente baixa (12 no máximo): radius alto empurra a
/// estética para "app mobile consumer" em vez de ferramenta desktop — ver
/// `spacing.md`, seção "Border-radius".
abstract final class AppRadii {
  /// Superfícies flutuantes — painel do overlay, dropdown, modal — 12px.
  static const panel = Radius.circular(12);

  /// Cards e superfícies internas — 8px.
  static const card = Radius.circular(8);

  /// Botões e campos — 8px.
  static const button = Radius.circular(8);

  /// List items e botões compactos — 6px.
  static const listItem = Radius.circular(6);

  /// Badges de ícone — 6px.
  static const badge = Radius.circular(6);

  /// Badges pequenos dentro do overlay — 4px.
  static const badgeSmall = Radius.circular(4);

  static const panelAll = BorderRadius.all(panel);
  static const cardAll = BorderRadius.all(card);
  static const buttonAll = BorderRadius.all(button);
  static const listItemAll = BorderRadius.all(listItem);
  static const badgeAll = BorderRadius.all(badge);
  static const badgeSmallAll = BorderRadius.all(badgeSmall);
}

/// Escala de espaçamento. Múltiplos de 4 com nomes semânticos, para manter o
/// "muito respiro" pedido no design sem números mágicos espalhados.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const xxxl = 24.0;
  static const huge = 32.0;

  /// Margem externa máxima — rodapé de janela, respiro final de scroll.
  /// Usada com parcimônia: é o topo da escala, não um preenchimento genérico.
  static const giant = 48.0;
}

/// Bordas e sombras compartilhadas.
abstract final class AppBorders {
  /// Borda sutil padrão de 1px.
  static const subtle = BorderSide(color: AppColors.border, width: 1);

  static const all = Border.fromBorderSide(subtle);
  static const bottom = Border(bottom: subtle);
  static const right = Border(right: subtle);
}

abstract final class AppShadows {
  /// Sombra do painel flutuante — `0 24px 60px rgba(0,0,0,0.55)`.
  static const floatingPanel = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 60,
      offset: Offset(0, 24),
    ),
  ];

  /// Sombra do dropdown da menu bar — `0 20px 50px rgba(0,0,0,0.55)`.
  static const dropdown = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 50,
      offset: Offset(0, 20),
    ),
  ];

  /// Anel de foco de teclado: 2px ao redor do componente.
  ///
  /// É uma sombra sem blur em vez de uma borda para não empurrar o layout — o
  /// componente não muda de tamanho ao receber foco. Exige que o componente
  /// tenha fundo opaco, senão o retângulo inflado aparece por inteiro.
  static const focusRing = <BoxShadow>[
    BoxShadow(color: AppColors.focusRing, spreadRadius: 2),
  ];
}

/// Durações de animação. Tudo curto e suave — nada de transições longas.
abstract final class AppDurations {
  /// Micro-feedback: hover, pressed, anel de foco. Precisa ser imperceptível
  /// como animação — a interface só não pode "piscar" (`motion.md`: 80–120ms).
  static const instant = Duration(milliseconds: 90);

  /// Transições de estado pequenas — badge que muda, seleção que se move.
  static const fast = Duration(milliseconds: 150);

  /// Entrada de superfície flutuante (overlay do Pin, diálogo). A saída não tem
  /// duração: fechar é instantâneo, sempre (`motion.md`).
  static const entrance = Duration(milliseconds: 120);

  /// Transições de layout.
  static const medium = Duration(milliseconds: 220);

  static const curve = Curves.easeOutCubic;
}

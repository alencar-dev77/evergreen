import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Raios de canto padronizados.
abstract final class AppRadii {
  /// Painéis e cards grandes — 16px.
  static const panel = Radius.circular(16);

  /// Cards e superfícies internas — 14px.
  static const card = Radius.circular(14);

  /// Botões — 10px.
  static const button = Radius.circular(10);

  /// List items e botões compactos — 9px.
  static const listItem = Radius.circular(9);

  /// Badges de ícone — 7px.
  static const badge = Radius.circular(7);

  /// Badges pequenos dentro do overlay — 6px.
  static const badgeSmall = Radius.circular(6);

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
}

/// Durações de animação. Tudo curto e suave — nada de transições longas.
abstract final class AppDurations {
  /// Feedback de hover / cor.
  static const fast = Duration(milliseconds: 150);

  /// Transições de layout.
  static const medium = Duration(milliseconds: 220);

  static const curve = Curves.easeOutCubic;
}

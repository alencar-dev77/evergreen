import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';

/// Superfície base de todo painel do Evergreen.
///
/// Encapsula fundo `surface`, borda sutil de 1px, raio e a sombra flutuante —
/// a assinatura visual compartilhada pelo overlay do Pin, pelo dropdown da
/// menu bar e pelos cards do Hub.
class EgPanel extends StatelessWidget {
  const EgPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadii.panelAll,
    this.color = AppColors.surface,
    this.gradient,
    this.elevated = true,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color color;

  /// Gradiente sutil de superfície. Quando informado, substitui [color] —
  /// usado no overlay do Pin para dar profundidade ao painel.
  final Gradient? gradient;

  /// Aplica a sombra do painel flutuante. Desligue para painéis embutidos.
  final bool elevated;

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: AppBorders.all,
        boxShadow: elevated ? AppShadows.floatingPanel : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Badge quadrado arredondado que abriga um ícone.
///
/// Usado no ícone de tipo do list item (24px), no cabeçalho do preview (28px)
/// e no ícone do estado vazio (52px).
class EgIconBadge extends StatelessWidget {
  const EgIconBadge({
    super.key,
    required this.child,
    this.size = 24,
    this.color = AppColors.hover,
    this.borderRadius,
    this.bordered = false,
  });

  final Widget child;
  final double size;
  final Color color;
  final BorderRadius? borderRadius;

  /// Adiciona a borda sutil — usado no badge grande do estado vazio.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? AppRadii.badgeSmallAll,
        border: bordered ? AppBorders.all : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

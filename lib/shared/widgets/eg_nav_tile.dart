import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_hoverable.dart';
import 'eg_icon.dart';
import 'eg_panel.dart';
import 'eg_surface.dart';
import '../../core/design/eg_tokens.dart';

/// Item de navegação: badge de ícone, título e uma linha de apoio.
///
/// É a linha da barra lateral do Hub — a dos módulos e a da marca, que eram
/// dois widgets quase idênticos até a componentização. O que de fato as
/// distingue vira parâmetro ([titleStyle], [iconColor], [iconBackground]); o
/// resto — densidade, alinhamento, matriz de estado — é igual por construção,
/// que é o ponto de existir um componente em vez de dois.
///
/// Os estados vêm da [context.eg.surfaces.row]: selecionado em accent a 14%, hover
/// neutro, pressed um degrau acima e anel de foco pelo teclado. Selecionado
/// vence hover — sem isso o item aberto se perde assim que o mouse passa por
/// outro.
class EgNavTile extends StatelessWidget {
  const EgNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.titleStyle,
    this.iconSize = AppIconSizes.md,
    this.iconColor,
    this.iconBackground,
    this.borderedIcon = false,
    this.isMuted = false,
    this.margin,
  });

  final EgIconData icon;
  final String title;

  /// A linha de apoio, sempre presente: um item de navegação sem ela mudaria
  /// de altura no meio da lista.
  final String subtitle;

  final bool isSelected;
  final VoidCallback onTap;

  /// Padrão: [context.eg.text.bodyCompactEmphasis]. A marca usa o degrau acima.
  final TextStyle? titleStyle;

  final double iconSize;

  /// Padrão: accent quando selecionado, texto secundário no resto do tempo.
  final Color? iconColor;

  /// Padrão: superfície de campo quando selecionado, hover no resto do tempo —
  /// o badge acompanha a linha em vez de disputar com ela.
  final Color? iconBackground;

  /// Contorno sutil no badge. A marca leva; os módulos, não.
  final bool borderedIcon;

  /// Esmaece a linha inteira sem desligá-la — o módulo que ainda não existe
  /// continua clicável, e o que há para ver é justamente a tela que conta
  /// quando ele chega.
  final bool isMuted;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isSelected,
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Opacity(
        opacity: isMuted ? AppOpacities.unavailable : 1,
        child: Row(
          children: [
            EgIconBadge(
              size: AppBadgeSizes.sm,
              borderRadius: context.eg.shapes.smallAll,
              bordered: borderedIcon,
              color:
                  iconBackground ??
                  (isSelected
                      ? context.eg.colors.card
                      : context.eg.colors.hover),
              child: EgIcon(
                icon,
                size: iconSize,
                color:
                    iconColor ??
                    (isSelected
                        ? context.eg.colors.accent
                        : context.eg.colors.textSecondary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // O título só reage à seleção: hover e pressed são
                    // assunto da superfície, não do texto.
                    style: (titleStyle ?? context.eg.text.bodyCompactEmphasis)
                        .copyWith(
                          color: context.eg.surfaces.row.foregroundFor(
                            const EgInteraction(),
                            isSelected: isSelected,
                          ),
                        ),
                  ),
                  // Colados: título e apoio são um bloco só, e 4px já os leria
                  // como duas informações separadas.
                  const SizedBox(height: AppSpacing.hairline),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.eg.text.captionXS,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

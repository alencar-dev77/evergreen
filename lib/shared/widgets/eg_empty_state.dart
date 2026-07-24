import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_icon.dart';
import 'eg_panel.dart';

/// Estado vazio padrão: badge 52x52, título e subtítulo centralizados.
class EgEmptyState extends StatelessWidget {
  const EgEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final EgIconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.huge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EgIconBadge(
            size: 40,
            color: AppColors.card,
            borderRadius: AppRadii.badgeAll,
            bordered: true,
            child: EgIcon(icon, size: 18),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodyCompact.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.captionSmall,
          ),
        ],
      ),
    );
  }
}

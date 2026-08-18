import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../models/evergreen_module.dart';

/// Painel exibido para módulos que ainda não foram construídos.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.module});

  final EvergreenModule module;

  @override
  Widget build(BuildContext context) {
    return EgPanel(
      color: AppColors.card,
      borderRadius: AppRadii.cardAll,
      elevated: false,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EgIconBadge(
            size: AppBadgeSizes.md,
            color: AppColors.hover,
            borderRadius: AppRadii.badgeAll,
            child: EgIcon(module.icon, size: AppIconSizes.xl),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Em breve, na ${module.plannedFor}',
                  style: AppTypography.bodyCompact.copyWith(
                    color: AppColors.greenLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(module.description, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

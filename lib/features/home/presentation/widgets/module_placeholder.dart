import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../models/evergreen_module.dart';
import '../../../../core/design/eg_tokens.dart';

/// Painel exibido para módulos que ainda não foram construídos.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.module});

  final EvergreenModule module;

  @override
  Widget build(BuildContext context) {
    return EgPanel(
      color: context.eg.colors.surface,
      borderRadius: context.eg.shapes.cardAll,
      elevated: false,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EgIconBadge(
            size: AppBadgeSizes.md,
            color: context.eg.colors.hover,
            borderRadius: context.eg.shapes.segmentAll,
            child: EgIcon(module.icon, size: AppIconSizes.xl),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Em breve, na ${module.plannedFor}',
                  style: context.eg.text.bodyCompact.copyWith(
                    color: context.eg.colors.accentLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(module.description, style: context.eg.text.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

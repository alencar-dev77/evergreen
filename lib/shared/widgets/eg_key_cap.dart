import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';

/// Tecla individual renderizada como key-cap (`⌘`, `⇧`, `V`).
class EgKeyCap extends StatelessWidget {
  const EgKeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.badgeSmallAll,
        border: AppBorders.all,
      ),
      child: Text(label, style: AppTypography.monoSmall),
    );
  }
}

/// Sequência de key-caps que representa um atalho completo.
class EgShortcutDisplay extends StatelessWidget {
  const EgShortcutDisplay({super.key, required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          EgKeyCap(keys[i]),
        ],
      ],
    );
  }
}

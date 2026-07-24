import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_toggle.dart';

/// Linha de configuração: label à esquerda, controle à direita.
///
/// Compartilhada por todas as telas de configuração dos módulos, para que Pin,
/// Focus e Shelf tenham exatamente a mesma densidade e alinhamento.
class EgSettingsRow extends StatelessWidget {
  const EgSettingsRow({
    super.key,
    required this.label,
    required this.trailing,
    this.description,
    this.showDivider = true,
  });

  /// Atalho para a linha mais comum: label + toggle.
  EgSettingsRow.toggle({
    super.key,
    required this.label,
    required bool value,
    ValueChanged<bool>? onChanged,
    this.description,
    this.showDivider = true,
  }) : trailing = EgToggle(value: value, onChanged: onChanged);

  final String label;
  final Widget trailing;
  final String? description;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: showDivider ? AppBorders.bottom : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.bodyCompact),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(description!, style: AppTypography.captionSmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          trailing,
        ],
      ),
    );
  }
}

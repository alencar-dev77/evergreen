import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_section_label.dart';

/// Agrupa linhas de configuração sob um header em caixa alta.
class EgSettingsSection extends StatelessWidget {
  const EgSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgSectionLabel(
          title,
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        ),
        ...children,
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

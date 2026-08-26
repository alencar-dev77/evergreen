import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_section_label.dart';

/// Agrupa linhas de configuração sob um header em caixa alta.
class EgSettingsSection extends StatelessWidget {
  const EgSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;

  /// Controle que manda no que a seção mostra — o recorte de período do Track.
  ///
  /// Na linha do header, e não acima do conteúdo: ele governa a seção inteira,
  /// e uma linha própria para ele o faria parecer mais um item da lista abaixo.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        ...children,
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  Widget _header() {
    if (trailing == null) {
      return EgSectionLabel(
        title,
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: EgSectionLabel(title)),
          trailing!,
        ],
      ),
    );
  }
}

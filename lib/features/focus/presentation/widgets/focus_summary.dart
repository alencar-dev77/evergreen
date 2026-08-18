import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../data/focus_session_repository.dart';

/// Os dois números do Focus: hoje e os últimos 7 dias.
///
/// Sem card, sem borda, sem ícone — dois valores e seus rótulos, alinhados à
/// esquerda como o resto da tela. A hierarquia vem do tamanho do número contra
/// o rótulo, que é tudo de que uma estatística de duas medidas precisa.
class FocusSummary extends StatelessWidget {
  const FocusSummary({super.key, required this.stats});

  final FocusStats stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Stat(label: 'Hoje', value: DurationFormat.compact(stats.today)),
          const SizedBox(width: AppSpacing.giant),
          // "Esta semana" e não "últimos 7 dias": o histórico do Focus zera na
          // segunda-feira, então uma janela deslizante contaria tempo que já
          // não está mais na lista abaixo.
          _Stat(
            label: 'Esta semana',
            value: DurationFormat.compact(stats.week),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.screenTitle),
        const SizedBox(height: AppSpacing.hairline),
        Text(label, style: AppTypography.captionXS),
      ],
    );
  }
}

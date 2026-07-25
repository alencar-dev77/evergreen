import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_section_label.dart';

/// O bloco central do painel do Focus: rótulo da fase, número grande e, quando
/// há, a atividade e a linha de progresso.
///
/// É o mesmo bloco em todos os estados — contando, pausado ou concluído — e por
/// isso o número nunca muda de posição quando a sessão troca de fase. O que
/// muda é o conteúdo, não o layout.
class FocusCountdown extends StatelessWidget {
  const FocusCountdown({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.progress,
    this.isMuted = false,
  });

  /// Fase ou situação: "Foco", "Pausa", "Sessão concluída".
  final String label;

  /// O número em destaque — `24:13` contando, `25 min` ao fim.
  final String value;

  /// A atividade da sessão, quando ela existe.
  final String? detail;

  /// Progresso da fase, de 0 a 1. `null` esconde a linha.
  final double? progress;

  /// Esmaece o número. Usado na pausa do cronômetro: o tempo continua sendo o
  /// conteúdo da tela, mas parado — e isso precisa ser visível sem depender só
  /// do rótulo mudar.
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EgSectionLabel(label),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.timer.copyWith(
            color: isMuted ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        if (detail != null && detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyCompact.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _ProgressLine(value: progress!, isMuted: isMuted),
        ],
      ],
    );
  }
}

/// Linha de progresso de 2px.
///
/// Não anima: ela avança uma fração invisível por segundo, e animar cada passo
/// só custaria frames. É uma pista periférica — quem quer precisão lê o número.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value, required this.isMuted});

  final double value;
  final bool isMuted;

  static const _height = 2.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.border),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isMuted
                    ? AppColors.textTertiary
                    : AppColors.greenPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

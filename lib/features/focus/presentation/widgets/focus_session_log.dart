import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../models/focus_session_note.dart';

/// O que foi escrito nesta sessão: a atividade do início e as observações
/// anotadas ao longo dela, em ordem cronológica.
///
/// É o diário da sessão — vive acima do campo de anotação no painel e dentro do
/// detalhe do histórico, sempre com a mesma forma, para que a lista que a
/// pessoa vê enquanto trabalha seja a mesma que ela relê depois.
class FocusSessionLog extends StatelessWidget {
  const FocusSessionLog({
    super.key,
    required this.activity,
    required this.notes,
    this.maxHeight,
  });

  /// O texto escrito antes de começar. Encabeça a lista.
  final String? activity;

  final List<FocusSessionNote> notes;

  /// Teto de altura antes de a lista rolar. `null` deixa crescer à vontade.
  final double? maxHeight;

  bool get _isEmpty => (activity == null || activity!.isEmpty) && notes.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (activity != null && activity!.isNotEmpty)
          Text(
            activity!,
            style: AppTypography.bodyCompact.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        for (final note in notes) ...[
          const SizedBox(height: AppSpacing.xxs),
          _NoteLine(note: note),
        ],
      ],
    );

    if (maxHeight == null) return content;

    // `reverse` mantém o fim da lista à vista sem controlador: a anotação
    // recém-escrita é a que importa, e ela é sempre a última.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: SingleChildScrollView(
        reverse: true,
        child: content,
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note});

  final FocusSessionNote note;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          // O minuto fica um nível atrás do texto: ele localiza a anotação, mas
          // quem se lê é o que foi escrito.
          TextSpan(
            text: '${note.label} — ',
            style: AppTypography.captionXS.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          TextSpan(text: note.text, style: AppTypography.captionXS),
        ],
      ),
    );
  }
}

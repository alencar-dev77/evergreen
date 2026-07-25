import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/focus_session.dart';
import '../viewmodels/focus_history_view_model.dart';
import 'focus_session_log.dart';

/// Detalhe de uma sessão do histórico.
///
/// A linha da lista responde "quando e quanto"; aqui ficam as anotações e o
/// resumo — o conteúdo que não caberia em uma linha sem transformar a lista em
/// parágrafo. É sobretudo consulta: a única ação é apagar aquela sessão, para
/// que corrigir um registro errado não custe a semana inteira.
class FocusSessionDialog extends ConsumerWidget {
  const FocusSessionDialog({super.key, required this.session});

  final FocusSession session;

  /// Um pouco mais largo que o diálogo de confirmação: aqui há texto para ler,
  /// não uma pergunta para responder.
  static const _width = 420.0;

  /// Teto da área de anotações antes de ela rolar.
  static const _logMaxHeight = 220.0;

  static Future<void> show(BuildContext context, FocusSession session) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) => FocusSessionDialog(session: session),
    );
  }

  /// O título é o que a pessoa escreveu antes de começar. Sem isso, a própria
  /// data e hora servem de nome — melhor que um rótulo genérico.
  static String titleOf(FocusSession session) {
    if (session.hasActivity) return session.activity!;

    return '${DayLabel.of(session.startedAt)} · '
        '${DayLabel.time(session.startedAt)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape):
              Navigator.of(context).pop,
        },
        child: EgPanel(
          width: _width,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titleOf(session), style: AppTypography.panelTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(_metadata(), style: AppTypography.captionXS),
              const SizedBox(height: AppSpacing.xxl),
              _body(),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  // Destrutiva à esquerda, longe do botão que se aperta no
                  // reflexo — é a convenção do macOS para diálogos que têm uma
                  // ação de risco ao lado de uma inofensiva.
                  EgButton.destructive(
                    label: 'Apagar',
                    onPressed: () => _delete(context, ref),
                  ),
                  const Spacer(),
                  EgButton.secondary(
                    label: 'Fechar',
                    autofocus: true,
                    onPressed: Navigator.of(context).pop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Apagar é irreversível — pede confirmação, como o "Limpar histórico".
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Apagar sessão?',
      message: 'A sessão e o que você anotou nela serão removidos. '
          'Não dá para desfazer.',
      confirmLabel: 'Apagar',
    );
    if (!confirmed || !context.mounted) return;

    ref.read(focusHistoryViewModelProvider.notifier).delete(session);
    Navigator.of(context).pop();
  }

  String _metadata() {
    return '${DayLabel.of(session.startedAt)} · '
        '${DayLabel.time(session.startedAt)} · '
        '${DurationFormat.compact(session.duration)}';
  }

  Widget _body() {
    if (!session.hasNotes && !session.hasSummary) {
      return Text(
        'Nenhuma anotação nesta sessão.',
        style: AppTypography.captionSmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.hasNotes) ...[
          const EgSectionLabel(
            'Anotações',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          // Sem a atividade: ela já é o título do diálogo, e repeti-la aqui
          // seria a mesma frase duas vezes na mesma tela.
          FocusSessionLog(
            activity: null,
            notes: session.notes,
            maxHeight: _logMaxHeight,
          ),
        ],
        if (session.hasSummary) ...[
          if (session.hasNotes) const SizedBox(height: AppSpacing.xxl),
          const EgSectionLabel(
            'Resumo',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          Text(session.summary!, style: AppTypography.bodyCompact),
        ],
      ],
    );
  }
}

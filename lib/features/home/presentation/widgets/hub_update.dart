import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/system/update_service.dart';
import '../../../../shared/widgets/eg_brand_mark.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_panel.dart';

/// A versão nova: o que muda e o botão de atualizar, num cartão por cima do
/// Hub.
///
/// Cartão, e não a tela inteira: é uma pergunta de sim ou não ("atualizar
/// agora?"), que é o único caso em que o Evergreen escurece o que está atrás —
/// a regra do `EgConfirmDialog`. Clicar fora fecha, como Esc ou "Agora não"; a
/// versão continua anunciada (a bolinha e o item do menu ficam). Do palco da
/// apresentação de boas-vindas ele herda o gradiente, com o canivete no lugar
/// do print — é o Evergreen falando de si mesmo, não uma janela de sistema.
///
/// "Atualizar e reiniciar" é a resposta inteira: daqui o app baixa, fecha,
/// instala e abre de novo, com a abertura animada da build nova. O andamento
/// aparece no próprio botão, e enquanto ele anda o cartão não fecha.
class HubUpdate extends StatelessWidget {
  const HubUpdate({
    super.key,
    required this.state,
    required this.currentVersion,
    required this.onInstall,
    required this.onClose,
  });

  final UpdateState state;

  /// A versão instalada, para a frase "você está na …".
  final String currentVersion;

  final VoidCallback onInstall;
  final VoidCallback onClose;

  static const _width = 440.0;
  static const _stageHeight = 120.0;

  /// Até onde a lista de novidades cresce antes de rolar por dentro: os
  /// botões precisam continuar à vista numa versão com muita coisa.
  static const _notesMaxHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final failed = state.phase == UpdatePhase.error;

    return EgPanel(
      width: _width,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stage(context),
          const SizedBox(height: AppSpacing.xl),
          Text('Evergreen ${state.version ?? ''}', style: eg.text.panelTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            failed
                ? 'Não deu para atualizar agora. A $currentVersion continua '
                      'instalada; tente de novo mais tarde.'
                : 'Você está na $currentVersion. Isto é o que muda:',
            style: eg.text.bodyCompact.copyWith(color: eg.colors.textSecondary),
          ),
          if (!failed && state.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _notes(context),
          ],
          const SizedBox(height: AppSpacing.xxl),
          _actions(context, failed: failed),
        ],
      ),
    );
  }

  /// O palco da apresentação, em miniatura, com o canivete no centro.
  Widget _stage(BuildContext context) {
    return SizedBox(
      height: _stageHeight,
      child: ClipRRect(
        borderRadius: context.eg.shapes.cardAll,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: context.eg.gradients.onboardingStage,
          ),
          child: const Center(child: EgBrandMark(size: 64)),
        ),
      ),
    );
  }

  /// As novidades, como o `CHANGELOG.md` as escreveu: uma versão por título,
  /// uma linha por mudança.
  Widget _notes(BuildContext context) {
    final eg = context.eg;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _notesMaxHeight),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, note) in state.notes.indexed)
              Padding(
                padding: EdgeInsets.only(
                  top: note.kind == UpdateNoteKind.heading && index > 0
                      ? AppSpacing.md
                      : AppSpacing.xxs,
                ),
                child: switch (note.kind) {
                  UpdateNoteKind.heading => Text(
                    note.text,
                    style: eg.text.bodyStrong,
                  ),
                  UpdateNoteKind.paragraph => Text(
                    note.text,
                    style: eg.text.bodyCompact.copyWith(
                      color: eg.colors.textSecondary,
                    ),
                  ),
                  UpdateNoteKind.item => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•  ',
                        style: eg.text.bodyCompact.copyWith(
                          color: eg.colors.accent,
                        ),
                      ),
                      Expanded(
                        child: Text(note.text, style: eg.text.bodyCompact),
                      ),
                    ],
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Os dois botões, à direita como no `EgConfirmDialog`. O de atualizar é
  /// também onde o andamento aparece.
  Widget _actions(BuildContext context, {required bool failed}) {
    final busy = state.phase.isBusy;
    final progress = state.progress;
    final label = switch (state.phase) {
      UpdatePhase.downloading when progress != null =>
        'Baixando… ${(progress * 100).round()}%',
      UpdatePhase.downloading => 'Baixando…',
      UpdatePhase.extracting => 'Preparando…',
      UpdatePhase.installing => 'Reiniciando…',
      _ => 'Atualizar e reiniciar',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (failed)
              EgButton(label: 'Fechar', autofocus: true, onPressed: onClose)
            else ...[
              if (!busy)
                EgButton.secondary(label: 'Agora não', onPressed: onClose),
              EgButton(
                label: label,
                autofocus: true,
                isLoading: state.phase == UpdatePhase.installing,
                onPressed: busy ? null : onInstall,
              ),
            ],
          ],
        ),
        if (busy && progress != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ProgressLine(value: progress),
        ],
      ],
    );
  }
}

/// A linha fina do andamento, sob os botões.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Andamento',
      value: '${(value * 100).round()}%',
      child: SizedBox(
        height: 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.eg.colors.control,
            borderRadius: context.eg.shapes.segmentAll,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.eg.colors.accent,
                  borderRadius: context.eg.shapes.segmentAll,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

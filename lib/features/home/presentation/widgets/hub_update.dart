import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/system/update_service.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../../shared/widgets/eg_brand_mark.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';

/// A versão nova, por cima do Hub: o que mudou e o botão de atualizar.
///
/// Mesma cena da apresentação de boas-vindas — o fundo, o palco que vai do
/// preto ao verde da marca, o botão no centro —, porque é o mesmo tipo de
/// momento: o Evergreen falando de si mesmo, uma vez, em vez de uma janela de
/// sistema pedindo licença. O palco leva o canivete no lugar do print.
///
/// "Atualizar e reiniciar" é a resposta inteira: daqui o app baixa, fecha,
/// instala e abre de novo, com a abertura animada da build nova. O andamento
/// aparece no próprio botão; "Agora não" fecha a tela e a versão continua
/// anunciada (a bolinha e o item do menu ficam).
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

  static const _stageWidth = 620.0;
  static const _stageHeight = 200.0;
  static const _contentWidth = 480.0;

  /// Até onde a lista de novidades cresce antes de rolar por dentro: o botão
  /// precisa continuar à vista numa versão com muita coisa.
  static const _notesMaxHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final failed = state.phase == UpdatePhase.error;

    return EgBackground(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xxxl,
                  horizontal: AppSpacing.huge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stage(context),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      'Evergreen ${state.version ?? ''}',
                      style: context.eg.text.display,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: _contentWidth,
                      child: Text(
                        failed
                            ? 'Não deu para atualizar agora. A versão '
                                  '$currentVersion continua instalada; tente '
                                  'de novo mais tarde.'
                            : 'Você está na $currentVersion. Isto é o que '
                                  'muda:',
                        textAlign: TextAlign.center,
                        style: context.eg.text.body.copyWith(
                          color: context.eg.colors.textSecondary,
                        ),
                      ),
                    ),
                    if (!failed && state.notes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _notes(context),
                    ],
                    const SizedBox(height: AppSpacing.xxxl),
                    _action(context, failed: failed),
                  ],
                ),
              ),
            ),
          ),
          EgHintBar(
            hints: [
              if (!failed && !state.phase.isBusy)
                EgHint(
                  keys: const ['enter'],
                  label: 'atualizar',
                  onTap: onInstall,
                ),
            ],
            trailing: state.phase.isBusy
                ? null
                : EgHint(
                    keys: const ['esc'],
                    label: 'agora não',
                    onTap: onClose,
                  ),
          ),
        ],
      ),
    );
  }

  /// O palco da apresentação, com o canivete no centro.
  Widget _stage(BuildContext context) {
    return SizedBox(
      width: _stageWidth,
      height: _stageHeight,
      child: ClipRRect(
        borderRadius: context.eg.shapes.panelAll,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: context.eg.gradients.onboardingStage,
          ),
          child: const Center(child: EgBrandMark(size: 96)),
        ),
      ),
    );
  }

  /// As novidades, como o `CHANGELOG.md` as escreveu: uma versão por título,
  /// uma linha por mudança.
  Widget _notes(BuildContext context) {
    final eg = context.eg;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: _contentWidth,
        maxHeight: _notesMaxHeight,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, note) in state.notes.indexed)
              Padding(
                padding: EdgeInsets.only(
                  top: note.kind == UpdateNoteKind.heading && index > 0
                      ? AppSpacing.lg
                      : AppSpacing.xxs,
                ),
                child: switch (note.kind) {
                  UpdateNoteKind.heading => Text(
                    note.text,
                    style: eg.text.bodyStrong,
                  ),
                  UpdateNoteKind.paragraph => Text(
                    note.text,
                    style: eg.text.body.copyWith(
                      color: eg.colors.textSecondary,
                    ),
                  ),
                  UpdateNoteKind.item => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•  ',
                        style: eg.text.body.copyWith(color: eg.colors.accent),
                      ),
                      Expanded(child: Text(note.text, style: eg.text.body)),
                    ],
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }

  /// O botão, que também é onde o andamento aparece.
  Widget _action(BuildContext context, {required bool failed}) {
    final progress = state.progress;
    final label = switch (state.phase) {
      UpdatePhase.downloading when progress != null =>
        'Baixando… ${(progress * 100).round()}%',
      UpdatePhase.downloading => 'Baixando…',
      UpdatePhase.extracting => 'Preparando…',
      UpdatePhase.installing => 'Reiniciando…',
      _ when failed => 'Fechar',
      _ => 'Atualizar e reiniciar',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          child: EgButton(
            label: label,
            onPressed: state.phase.isBusy
                ? null
                : (failed ? onClose : onInstall),
            isLoading: state.phase == UpdatePhase.installing,
            expand: true,
            autofocus: true,
          ),
        ),
        if (state.phase.isBusy && progress != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ProgressLine(value: progress),
        ],
      ],
    );
  }
}

/// A linha fina do andamento, sob o botão.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Andamento',
      value: '${(value * 100).round()}%',
      child: SizedBox(
        width: 240,
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

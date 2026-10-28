import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../viewmodels/echo_playback_view_model.dart';

/// O player da reunião, preso no topo da leitura.
///
/// No cabeçalho da região, e não dentro do texto que rola: a transcrição de
/// quarenta minutos passa por baixo dele e o controle nunca sai da tela —
/// pausar não pode exigir rolar de volta ao começo.
///
/// Uma linha só, do jeito que um player de podcast se lê: voltar, tocar,
/// avançar, o tempo, a barra e a velocidade. O verde é do botão de tocar, que é a ação
/// primária da linha; o resto é neutro.
class EchoPlayerBar extends StatelessWidget {
  const EchoPlayerBar({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onSkip,
    required this.onSeek,
    required this.onCycleRate,
  });

  final EchoPlaybackState state;
  final VoidCallback onToggle;
  final void Function(Duration offset) onSkip;
  final void Function(int positionMs) onSeek;
  final VoidCallback onCycleRate;

  @override
  Widget build(BuildContext context) {
    final skip = EchoPlaybackViewModel.skip;

    return Row(
      children: [
        EgIconButton(
          icon: EgIconData.skipBack,
          tooltip: 'Voltar ${skip.inSeconds} s (←)',
          size: AppBadgeSizes.sm,
          iconSize: AppIconSizes.lg,
          onPressed: () => onSkip(-skip),
          repeatable: true,
        ),
        EgIconButton(
          icon: state.isPlaying ? EgIconData.pause : EgIconData.play,
          tooltip: state.isPlaying ? 'Pausar (espaço)' : 'Tocar (espaço)',
          size: AppBadgeSizes.sm,
          iconSize: AppIconSizes.lg,
          color: context.eg.colors.accent,
          hoverColor: context.eg.colors.accentHover,
          onPressed: onToggle,
        ),
        EgIconButton(
          icon: EgIconData.skipForward,
          tooltip: 'Avançar ${skip.inSeconds} s (→)',
          size: AppBadgeSizes.sm,
          iconSize: AppIconSizes.lg,
          onPressed: () => onSkip(skip),
          repeatable: true,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(clock(state.positionMs), style: context.eg.text.monoSmall),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: EchoScrubber(
            positionMs: state.positionMs,
            durationMs: state.durationMs,
            onSeek: onSeek,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(clock(state.durationMs), style: context.eg.text.monoSmall),
        const SizedBox(width: AppSpacing.xs),
        EchoRateButton(rate: state.rate, onPressed: onCycleRate),
      ],
    );
  }

  /// `1×`, `1,25×`, `1,5×`, `2×` — com vírgula, como se escreve aqui.
  static String rateLabel(double rate) {
    final text = rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toString().replaceAll('.', ',');
    return '$text×';
  }

  /// `12:04`, ou `1:02:09` passando de uma hora.
  static String clock(int ms) {
    final total = ms ~/ 1000;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    String two(int value) => value.toString().padLeft(2, '0');

    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}

/// A barra do tempo: clicar salta, arrastar procura.
///
/// Fina e sem moldura, como a régua de um player do sistema — a parte tocada
/// em verde porque é o andamento de algo ligado, e o resto na linha neutra.
class EchoScrubber extends StatelessWidget {
  const EchoScrubber({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.onSeek,
  });

  final int positionMs;
  final int durationMs;
  final void Function(int positionMs) onSeek;

  static const _height = 20.0;
  static const _track = 3.0;
  static const _knob = 9.0;

  @override
  Widget build(BuildContext context) {
    final fraction = durationMs <= 0
        ? 0.0
        : (positionMs / durationMs).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void seekAt(double dx) {
          if (durationMs <= 0 || width <= 0) return;
          onSeek(((dx / width).clamp(0.0, 1.0) * durationMs).round());
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seekAt(details.localPosition.dx),
            onHorizontalDragUpdate: (details) =>
                seekAt(details.localPosition.dx),
            child: SizedBox(
              height: _height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: context.eg.colors.line,
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                  Container(
                    width: width * fraction,
                    height: _track,
                    decoration: BoxDecoration(
                      color: context.eg.colors.accent,
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                  Positioned(
                    left: (width * fraction - _knob / 2).clamp(
                      0.0,
                      width - _knob,
                    ),
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: BoxDecoration(
                        color: context.eg.colors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A velocidade da fala: um clique passa ao degrau seguinte.
///
/// Um botão que gira, e não um menu: são quatro degraus, e quem acelera um
/// áudio aperta até achar o seu — um menu pediria dois cliques para cada
/// tentativa. Largura fixa, para `1,25×` não empurrar a barra ao lado. Fora
/// do normal o número acende para o texto principal: é o lembrete de que a
/// reunião não está tocando no tempo em que aconteceu. Nunca verde — mais
/// rápido não é "ligado".
class EchoRateButton extends StatelessWidget {
  const EchoRateButton({
    super.key,
    required this.rate,
    required this.onPressed,
  });

  final double rate;
  final VoidCallback onPressed;

  static const _width = 44.0;

  @override
  Widget build(BuildContext context) {
    final label = EchoPlayerBar.rateLabel(rate);
    final isNormal = rate == 1;

    return EgInteractiveSurface(
      onTap: onPressed,
      style: context.eg.surfaces.ghost,
      borderRadius: context.eg.shapes.rowAll,
      width: _width,
      height: AppBadgeSizes.sm,
      alignment: Alignment.center,
      semanticLabel: 'Velocidade $label (S)',
      builder: (context, state) => Text(
        label,
        style: context.eg.text.monoSmall.copyWith(
          color: isNormal && !state.isHovered && !state.isFocused
              ? context.eg.colors.textSecondary
              : context.eg.colors.textPrimary,
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import '../../../../core/app_info.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../../shared/widgets/eg_brand_mark.dart';

/// A abertura do Hub: a lâmina da marca girando para fora do cabo.
///
/// Roda **uma vez por build instalada** — quem decide é o
/// `HubIntroViewModel`, não este widget, que só sabe animar e avisar quando
/// terminou. O que a torna aceitável num app que proíbe splash é a frequência:
/// 300ms cobrados de quem abre o Hub quarenta vezes por dia são pedágio;
/// cobrados uma vez por versão, são a marca dizendo que alguma coisa mudou.
///
/// O estado final do desenho é o estado normal do ícone, então não existe
/// degrau visual entre esta abertura e todas as outras.
class HubIntro extends StatefulWidget {
  const HubIntro({super.key, required this.onDone});

  /// Chamado quando a cena acaba — inclusive quando o movimento reduzido está
  /// ligado e ela não chegou a se mover.
  final VoidCallback onDone;

  @override
  State<HubIntro> createState() => _HubIntroState();
}

class _HubIntroState extends State<HubIntro>
    with SingleTickerProviderStateMixin {
  /// Quanto a marca fica parada depois de montada, para o nome ser lido.
  ///
  /// Fora da escala do `AppDurations` de propósito: aquela escala é de
  /// transições, e o teto dela são 320ms. Isto não é uma transição, é uma
  /// pausa — o tempo de olhar, que é o único motivo de a cena existir.
  static const _hold = Duration(milliseconds: 700);

  /// A saída é mais rápida que a entrada, como toda saída no Evergreen.
  static const _exit = AppDurations.instant;

  /// Quanto a lâmina passa do ponto antes de assentar. 1 é travada.
  static const _overshoot = 1 + 5 / 174;

  late final AnimationController _controller;
  late final Animation<double> _openness;
  late final Animation<double> _word;
  late final Animation<double> _curtain;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });

    _openness =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: _overshoot,
            ).chain(CurveTween(curve: AppDurations.curve)),
            weight: AppDurations.medium.inMilliseconds.toDouble(),
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: _overshoot,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: AppDurations.settle.inMilliseconds.toDouble(),
          ),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: Interval(0, _swingEnd)),
        );

    // O nome entra sobrepondo o fim do giro: em sequência, a cena teria dois
    // tempos e pareceria duas animações emendadas em vez de uma.
    _word = CurvedAnimation(
      parent: _controller,
      curve: Interval(_wordStart, _wordEnd, curve: AppDurations.curve),
    );

    _curtain = CurvedAnimation(
      parent: _controller,
      curve: Interval(_exitStart, 1, curve: Curves.easeIn),
    );
  }

  /// O instante em que a lâmina trava — o giro mais o assentamento.
  static final _lock = AppDurations.medium + AppDurations.settle;

  static final _total = _lock + _hold + _exit;

  /// Tudo abaixo é a mesma linha do tempo em fração do todo, porque é assim que
  /// o `Interval` a lê. Nenhum número solto: as marcas saem dos tokens.
  static final _swingEnd = _lock.inMilliseconds / _total.inMilliseconds;
  static final _wordEnd = _swingEnd;
  static final _wordStart =
      (_lock - AppDurations.entrance).inMilliseconds / _total.inMilliseconds;
  static final _exitStart =
      (_total - _exit).inMilliseconds / _total.inMilliseconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Movimento reduzido não é "anime mais rápido": é não animar. A lâmina
    // nasce travada, o nome nasce visível, e a cena só cumpre a pausa antes de
    // sair — o carimbo é gravado do mesmo jeito, senão a abertura voltaria a
    // cada Hub para quem desligou animação.
    if (MediaQuery.disableAnimationsOf(context)) {
      // Sem `_controller.value = 1`: pôr o controlador no fim dispara o
      // `addStatusListener`, e `onDone` sairia agora e de novo ao fim da
      // pausa. Em movimento reduzido o desenho não olha o controlador.
      Future<void>.delayed(_hold, () {
        if (mounted) widget.onDone();
      });
      return;
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: reduced ? 1 : 1 - _curtain.value,
        child: EgBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EgBrandMark(size: 104, openness: reduced ? 1 : _openness.value),
                const SizedBox(height: AppSpacing.xxl),
                Opacity(
                  opacity: reduced ? 1 : _word.value,
                  child: Transform.translate(
                    offset: Offset(0, reduced ? 0 : 4 * (1 - _word.value)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Evergreen', style: AppTypography.screenTitle),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          AppInfo.versionLabel,
                          style: AppTypography.captionXS,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

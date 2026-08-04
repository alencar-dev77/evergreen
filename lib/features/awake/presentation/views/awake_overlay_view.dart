import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/design/app_gradients.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_countdown.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../models/awake_duration.dart';
import '../viewmodels/awake_state.dart';
import '../viewmodels/awake_view_model.dart';
import 'awake_overlay_intents.dart';

/// Painel flutuante do Awake — a tela que o `⌘⇧X` abre.
///
/// Divide a janela com Pin e Focus (ver `OverlayWindow`). É o painel mais curto
/// da suíte de propósito: escolher por quanto tempo e ligar são as duas únicas
/// coisas que ele faz, e cada linha a mais seria uma decisão que ninguém pediu.
///
/// Fechar o painel não desliga a trava: ela continua no engine desta janela, e
/// o estado aparece no menu da barra.
class AwakeOverlayView extends ConsumerStatefulWidget {
  const AwakeOverlayView({super.key});

  @override
  ConsumerState<AwakeOverlayView> createState() => _AwakeOverlayViewState();
}

class _AwakeOverlayViewState extends ConsumerState<AwakeOverlayView>
    with WindowListener, SingleTickerProviderStateMixin {
  /// Segura o foco dentro do painel — sem um nó focado, o `Shortcuts` não
  /// receberia tecla nenhuma. Não há campo de texto aqui, então ele é o único.
  final _panelFocusNode = FocusNode(debugLabel: 'awake-panel');

  /// Fade de entrada, igual ao do Pin e ao do Focus: nasce em 1 para a primeira
  /// construção já mostrar o painel pronto; quem rebobina é o `onWindowFocus`.
  late final _entrance = AnimationController(
    vsync: this,
    duration: AppDurations.entrance,
    value: 1,
  );

  late final _entranceOpacity =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  /// Mesma largura do painel do Focus: os dois mostram um número grande e uma
  /// ação, e larguras diferentes para o mesmo arranjo fariam a troca de painel
  /// parecer uma troca de aplicativo.
  static const _panelWidth = 380.0;

  /// Margem para o macOS terminar a troca de foco antes de confirmarmos um
  /// blur — mesmo motivo dos outros painéis.
  static const _blurGracePeriod = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _entranceOpacity.dispose();
    _entrance.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    _entrance.forward(from: 0);
    _panelFocusNode.requestFocus();
  }

  @override
  void onWindowBlur() => unawaited(_handleBlur());

  @override
  void onWindowClose() => _close();

  Future<void> _handleBlur() async {
    await Future<void>.delayed(_blurGracePeriod);
    if (!mounted) return;
    if (await windowManager.isFocused()) return;

    await _close();
  }

  AwakeViewModel get _viewModel => ref.read(awakeViewModelProvider.notifier);

  /// Esconde o painel. A trava não é afetada — é o que a dica do rodapé promete
  /// ao dizer "fechar", e não "desligar".
  Future<void> _close() => OverlayWindow.instance.hide();

  /// Ligar e sair: quem apertou o atalho para manter a tela acesa já disse tudo
  /// o que tinha a dizer. Desligar não fecha — é comum desligar e logo religar
  /// com outro prazo, e a tela precisa continuar ali para isso.
  Future<void> _toggle() async {
    final wasOn = ref.read(awakeViewModelProvider).isOn;

    await _viewModel.toggle();
    if (!wasOn) await _close();
  }

  /// `⌘,`: sai de cena primeiro, depois abre o Hub — nessa ordem, um problema
  /// ao criar a janela nunca deixa o painel preso na tela.
  Future<void> _openSettings() async {
    await _close();
    await HubWindow.instance.open();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(awakeViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: AwakeOverlayIntents.shortcuts,
        child: Actions(
          actions: AwakeOverlayIntents.actions(
            onToggle: _toggle,
            onCycleDuration: _viewModel.cycleDuration,
            onClose: _close,
            onOpenSettings: _openSettings,
          ),
          // A janela é maior que o painel para caber a sombra. O resto dela é
          // transparente mas ainda captura cliques — clicar fora fecha.
          //
          // Centralizado na janela, como todos os painéis: quem se posiciona na
          // tela é a janela (ver `OverlayWindow`).
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: FadeTransition(
                    opacity: _entranceOpacity,
                    child: Focus(
                      focusNode: _panelFocusNode,
                      child: EgPanel(
                        width: _panelWidth,
                        gradient: AppGradients.panelSurface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: _body(state),
                            ),
                            _hintBar(state),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AwakeState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgCountdown(
          label: state.statusLabel,
          value: state.display,
          progress: state.progress,
          // Desligado, o número é uma proposta, não um fato — mesmo tratamento
          // da tela de partida do Focus.
          isMuted: !state.isOn,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: EgSegmentedControl<AwakeDuration>(
            value: state.duration,
            options: AwakeDuration.options,
            labelOf: (option) => option.label,
            onChanged: _viewModel.selectDuration,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Ligado, a tela não propõe nada — ela informa. Desligar é a saída
        // disponível, não a ação que o painel está sugerindo, e por isso vem
        // como secundário.
        if (state.isOn)
          EgButton.secondary(
            label: 'Desligar',
            expand: true,
            onPressed: _toggle,
          )
        else
          EgButton(
            label: 'Manter a tela acesa',
            expand: true,
            onPressed: _toggle,
          ),
      ],
    );
  }

  Widget _hintBar(AwakeState state) => EgHintBar(
        hints: [
          EgHint(
            keys: const ['enter'],
            label: state.isOn ? 'desligar' : 'ligar',
          ),
          const EgHint(keys: ['←', '→'], label: 'duração'),
        ],
        trailing: const EgHint(keys: ['esc'], label: 'fechar'),
      );
}

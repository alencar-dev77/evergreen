import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_countdown.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_overlay_shell.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/awake_duration.dart';
import '../viewmodels/awake_state.dart';
import '../viewmodels/awake_view_model.dart';
import '../viewmodels/keyboard_lock_state.dart';
import '../viewmodels/keyboard_lock_view_model.dart';
import 'awake_overlay_intents.dart';

/// Painel flutuante do Awake — a tela que o `⌘⇧X` abre.
///
/// Divide a janela com Pin e Focus (ver `OverlayWindow`). É o painel mais curto
/// da suíte de propósito: escolher por quanto tempo e ligar são as duas únicas
/// coisas que ele faz, e cada linha a mais seria uma decisão que ninguém pediu.
///
/// Fechar o painel não desliga a trava: ela continua no engine desta janela, e
/// o estado aparece no menu da barra.
///
/// O bloqueio de teclado é o contrário: **ele é o painel**. Bloqueado, o painel
/// inteiro vira a contagem do bloqueio; o "Desbloquear" devolve o teclado e
/// deixa o painel no Awake, e fechá-lo por qualquer caminho também devolve. O Esc não tem como chegar aqui, e um
/// teclado bloqueado sem nada na tela dizendo isso pareceria um Mac travado.
class AwakeOverlayView extends ConsumerStatefulWidget {
  const AwakeOverlayView({super.key});

  @override
  ConsumerState<AwakeOverlayView> createState() => _AwakeOverlayViewState();
}

class _AwakeOverlayViewState extends ConsumerState<AwakeOverlayView> {
  /// Segura o foco dentro do painel — sem um nó focado, o `Shortcuts` não
  /// receberia tecla nenhuma. Não há campo de texto aqui, então ele é o único.
  final _panelFocusNode = FocusNode(debugLabel: 'awake-panel');

  /// Mesma largura do painel do Focus: os dois mostram um número grande e uma
  /// ação, e larguras diferentes para o mesmo arranjo fariam a troca de painel
  /// parecer uma troca de aplicativo.
  static const _panelWidth = 380.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _panelFocusNode.dispose();
    super.dispose();
  }

  AwakeViewModel get _viewModel => ref.read(awakeViewModelProvider.notifier);

  KeyboardLockViewModel get _keyboard =>
      ref.read(keyboardLockViewModelProvider.notifier);

  /// Esconde o painel. A trava não é afetada — é o que a dica do rodapé promete
  /// ao dizer "fechar", e não "desligar". O bloqueio de teclado é: ele não
  /// sobrevive ao painel que o mostra.
  Future<void> _close() async {
    await _keyboard.unlock();
    await OverlayWindow.instance.hide();
  }

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
    final keyboard = ref.watch(keyboardLockViewModelProvider);

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
            onLockKeyboard: _keyboard.lock,
          ),
          child: EgOverlayShell(
            onClose: () => unawaited(_close()),
            onShow: _panelFocusNode.requestFocus,
            focusNode: _panelFocusNode,
            child: EgPanel(
              width: _panelWidth,
              vibrant: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: keyboard.isLocked
                        ? _lockedBody(keyboard)
                        : _body(state, keyboard),
                  ),
                  if (keyboard.isLocked)
                    const _LockedFooter()
                  else
                    _hintBar(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AwakeState state, KeyboardLockState keyboard) {
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
        const SizedBox(height: AppSpacing.sm),
        _LockKeyboardLine(keyboard: keyboard, onLock: _keyboard.lock),
      ],
    );
  }

  /// O painel bloqueado: quanto falta, o que ainda funciona, e a saída.
  ///
  /// Sem o seletor de duração — ele é do Awake, não do teclado, e o prazo do
  /// bloqueio é preferência. A frase diz onde ele se muda, porque o painel não
  /// tem como trocá-lo agora.
  Widget _lockedBody(KeyboardLockState keyboard) {
    final eg = context.eg;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgCountdown(
          label: 'Teclado bloqueado',
          value: keyboard.display,
          progress: keyboard.progress,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'O mouse e o trackpad continuam funcionando. O tempo do bloqueio '
          'se muda nas preferências do Awake.',
          style: eg.text.body.copyWith(color: eg.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        EgButton(
          label: 'Desbloquear',
          expand: true,
          onPressed: _keyboard.unlock,
        ),
      ],
    );
  }

  Widget _hintBar(AwakeState state) => EgHintBar(
    hints: [
      EgHint(keys: const ['enter'], label: state.isOn ? 'desligar' : 'ligar'),
      const EgHint(keys: ['←', '→'], label: 'duração'),
    ],
    trailing: const EgHint(keys: ['esc'], label: 'fechar'),
  );
}

/// A porta do bloqueio de teclado, abaixo da ação do Awake.
///
/// Linha, e não botão: a ação do painel continua sendo a do Awake, e um
/// segundo botão do mesmo tamanho disputaria com ela. O prazo vai escrito na
/// própria linha, porque ele não se escolhe aqui.
class _LockKeyboardLine extends StatelessWidget {
  const _LockKeyboardLine({required this.keyboard, required this.onLock});

  final KeyboardLockState keyboard;
  final Future<void> Function() onLock;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final refusal = keyboard.refusalMessage;
    final label = 'Bloquear o teclado por ${_durationText(keyboard)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgInteractiveSurface(
          onTap: onLock,
          focusable: false,
          semanticLabel: label,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: eg.text.footnote.copyWith(
                    color: eg.colors.textSecondary,
                  ),
                ),
              ),
              const EgKeyCap('t', onGlass: true),
            ],
          ),
        ),
        if (refusal != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xxs,
              AppSpacing.sm,
              0,
            ),
            child: Text(
              refusal,
              style: eg.text.footnote.copyWith(color: eg.colors.warning),
            ),
          ),
      ],
    );
  }

  /// "1 min", "10 min" — e "tempo indeterminado" em "Sempre", que numa frase
  /// ("por Sempre") não se lê.
  static String _durationText(KeyboardLockState keyboard) =>
      keyboard.duration.duration == null
      ? 'tempo indeterminado'
      : keyboard.duration.label;
}

/// O rodapé do painel bloqueado.
///
/// Sem teclas: nenhuma chega ao painel agora, e ensinar uma seria mentir. No
/// lugar, a outra saída que o mouse tem.
class _LockedFooter extends StatelessWidget {
  const _LockedFooter();

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return Container(
      height: EgHintBar.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: eg.colors.edge)),
      ),
      child: Text(
        'Clicar fora do painel também desbloqueia',
        style: eg.text.caption.copyWith(color: eg.colors.textTertiary),
      ),
    );
  }
}

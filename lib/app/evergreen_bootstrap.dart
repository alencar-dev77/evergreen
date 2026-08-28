import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/system/global_shortcut_service.dart';
import '../core/system/menu_bar_service.dart';
import '../core/system/startup_service.dart';
import '../core/window/hub_window.dart';
import '../core/window/overlay_panel.dart';
import '../core/window/overlay_window.dart';
import '../features/awake/presentation/viewmodels/awake_state.dart';
import '../features/awake/presentation/viewmodels/awake_view_model.dart';
import '../features/echo/data/echo_summary_runner.dart';
import '../features/echo/presentation/viewmodels/echo_recorder_state.dart';
import '../features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import '../features/focus/presentation/viewmodels/focus_timer_state.dart';
import '../features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import '../features/home/presentation/viewmodels/app_settings_view_model.dart';
import '../features/leaf/presentation/viewmodels/leaf_view_model.dart';
import '../features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import 'providers.dart';

/// Liga os serviços que rodam enquanto o Evergreen estiver aberto.
///
/// Tudo aqui vive no engine da janela 0 (a janela flutuante), que nunca é
/// destruído — por isso a captura da área de transferência, o cronômetro do
/// Focus, os atalhos globais e o ícone da barra de menus continuam funcionando
/// com todas as janelas fechadas.
class EvergreenBootstrap {
  EvergreenBootstrap(this._container);

  final ProviderContainer _container;

  /// Fila de operações de janela, para que abrir e fechar nunca se cruzem.
  Future<void> _pending = Future<void>.value();

  /// Relógio do backup automático. Ver [_scheduleBackups].
  Timer? _backupTimer;

  Future<void> start() async {
    _container.read(pinOverlayViewModelProvider.notifier).startWatching();
    unawaited(_container.read(echoRecorderViewModelProvider.notifier).initialize());
    unawaited(
      EchoSummaryHost.register(_container.read(echoSummaryRunnerProvider)),
    );

    // Antes de qualquer coisa que possa iniciar uma sessão nova: se o
    // Evergreen morreu no meio de uma, o tempo focado até ali entra no
    // histórico agora. Ver `FocusRun`.
    await _container
        .read(focusTimerViewModelProvider.notifier)
        .recoverInterruptedSession();

    await _syncLaunchAtLogin();
    await _registerShortcuts();
    await _setUpMenuBar();
    // Depois da barra de menus existir: a primeira emissão já escreve o rótulo
    // nela, inclusive para limpá-lo.
    _watchFocusSession();
    _watchAwake();
    _watchEcho();
    _scheduleBackups();
    await _openHubIfRequested();
  }

  /// Liga o backup semanal.
  ///
  /// Na abertura e de seis em seis horas, e não numa tarefa agendada do
  /// sistema: o Evergreen é um agente de barra de menus que fica aberto o dia
  /// inteiro, então uma verificação barata de tempos em tempos alcança tanto
  /// quem reinicia o Mac todo dia quanto quem passa três semanas sem desligar.
  /// Só a checagem é frequente — o backup em si acontece uma vez por semana
  /// (`BackupService.isDue`).
  ///
  /// Aqui, e não no engine do Hub, pela mesma razão do cronômetro do Focus e da
  /// captura do Pin: a janela de preferências passa a maior parte do tempo
  /// fechada, e um backup que só rodasse com ela aberta não seria automático.
  void _scheduleBackups() {
    _runScheduledBackup();
    _backupTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _runScheduledBackup(),
    );
  }

  void _runScheduledBackup() {
    if (!_container.read(appSettingsViewModelProvider).automaticBackup) return;

    final service = _container.read(backupServiceProvider);
    if (!service.isDue()) return;

    try {
      service.create();
    } catch (_) {
      // Disco cheio, pasta sem permissão, banco travado por outro processo: o
      // backup falhado é tentado de novo na verificação seguinte, e nada disso
      // pode derrubar o aplicativo que está rodando. Quem precisa saber que
      // falhou é quem apertou o botão — e esse caminho avisa na tela.
    }
  }

  Future<void> _registerShortcuts() async {
    final shortcuts = GlobalShortcutService.instance;
    await shortcuts.initialize();
    await shortcuts.registerPinToggle(() => toggleOverlay(OverlayPanel.pin));
    await shortcuts.registerFocusToggle(
      () => toggleOverlay(OverlayPanel.focus),
    );
    await shortcuts.registerAwakeToggle(
      () => toggleOverlay(OverlayPanel.awake),
    );
    await shortcuts.registerLeafToggle(() => toggleOverlay(OverlayPanel.leaf));
    await shortcuts.registerEchoToggle(() => toggleOverlay(OverlayPanel.echo));
    await shortcuts.registerHubOpen(HubWindow.instance.open);
  }

  Future<void> _setUpMenuBar() async {
    await MenuBarService.instance.initialize(onAction: _handleMenuAction);
  }

  /// Mantém a barra de menus e a janela em dia com o cronômetro do Focus.
  ///
  /// A assinatura também é o que segura o cronômetro vivo fora da árvore de
  /// widgets: a sessão precisa continuar correndo com o painel fechado.
  void _watchFocusSession() {
    _container.listen<FocusTimerState>(
      focusTimerViewModelProvider,
      (previous, next) {
        // Na primeira emissão (`previous` nulo) o rótulo é escrito sempre, até
        // quando é nulo: o texto na barra de menus vive no lado nativo e
        // sobrevive a um hot restart — sem essa escrita, um cronômetro que
        // morreu com o engine continuaria "rodando" na barra.
        if (previous == null || previous.menuBarLabel != next.menuBarLabel) {
          unawaited(MenuBarService.instance.setSessionLabel(next.menuBarLabel));
        }

        // O contador de alertas só sobe quando uma fase termina sozinha e o
        // aviso na tela está ligado — comparar com o anterior evita reabrir o
        // painel a cada tique.
        if (next.alerts > (previous?.alerts ?? 0)) {
          unawaited(showOverlay(OverlayPanel.focus));
        }
      },
      fireImmediately: true,
    );
  }

  /// Mantém a barra de menus em dia com a trava do Awake.
  ///
  /// A assinatura também é o que segura a trava viva fora da árvore de widgets:
  /// ela precisa continuar valendo com o painel fechado, e o painel é a única
  /// outra coisa que observa esta ViewModel.
  void _watchAwake() {
    _container.listen<AwakeState>(
      awakeViewModelProvider,
      (previous, next) {
        if (previous?.menuBarDetail == next.menuBarDetail) return;

        unawaited(MenuBarService.instance.setAwakeDetail(next.menuBarDetail));
      },
      fireImmediately: true,
    );
  }

  /// Mantém a barra de menus em dia com a gravação do Echo.
  ///
  /// A assinatura também é o que segura a gravação viva fora da árvore de
  /// widgets: a reunião continua sendo gravada com o painel fechado, que é o
  /// caso normal — ninguém fica olhando um painel por trinta minutos.
  void _watchEcho() {
    _container.listen<EchoRecorderState>(
      echoRecorderViewModelProvider,
      (previous, next) {
        if (previous?.menuBarLabel == next.menuBarLabel) return;

        unawaited(MenuBarService.instance.setEchoLabel(next.menuBarLabel));
      },
      fireImmediately: true,
    );
  }

  /// Alinha a preferência salva com o estado real do sistema.
  ///
  /// O sistema é a autoridade: o usuário pode ter removido o Evergreen dos
  /// itens de início pelos Ajustes do macOS, e nesse caso é a preferência salva
  /// que está desatualizada — não o contrário.
  Future<void> _syncLaunchAtLogin() async {
    final actual = await StartupService.instance.isEnabled();

    await _container
        .read(appSettingsViewModelProvider.notifier)
        .adoptSystemLaunchAtLogin(actual);
  }

  /// "Abrir minimizado" desligado significa mostrar o Hub ao iniciar.
  Future<void> _openHubIfRequested() async {
    if (_container.read(appSettingsViewModelProvider).startMinimized) return;
    await HubWindow.instance.open();
  }

  /// Abre o painel se ele estiver fechado, fecha se já estiver à vista.
  ///
  /// Serializado: apertar o atalho duas vezes em sequência rápida faria as duas
  /// execuções lerem a visibilidade antes de qualquer uma mudá-la, e uma
  /// desfaria a outra.
  Future<void> toggleOverlay(OverlayPanel panel) {
    return _pending = _pending
        .then((_) => _toggleOverlay(panel))
        .catchError((Object _) {});
  }

  /// Traz um painel para a frente sem nunca fechá-lo — o caminho do aviso de
  /// fim de sessão, onde esconder a janela seria o oposto do pedido.
  Future<void> showOverlay(OverlayPanel panel) {
    return _pending =
        _pending.then((_) => _showOverlay(panel)).catchError((Object _) {});
  }

  Future<void> _toggleOverlay(OverlayPanel panel) async {
    final overlay = OverlayWindow.instance;

    // Mesmo painel já à vista: o atalho funciona como interruptor.
    if (await overlay.isVisible() &&
        _container.read(overlayPanelProvider) == panel) {
      await overlay.hide();
      return;
    }

    await _showOverlay(panel);
  }

  Future<void> _showOverlay(OverlayPanel panel) async {
    await _prepare(panel);
    _container.read(overlayPanelProvider.notifier).show(panel);

    // Já visível em outro painel: trocar o conteúdo basta, sem reabrir a
    // janela — mas o cursor pode ter ido para outro monitor desde a abertura, e
    // o atalho leva o painel para onde a pessoa está olhando. A reafirmação
    // também devolve o teclado ao painel: estar visível não é estar com o foco.
    if (await OverlayWindow.instance.isVisible()) {
      await OverlayWindow.instance.reassert();
      return;
    }

    await OverlayWindow.instance.show();
  }

  Future<void> _prepare(OverlayPanel panel) async {
    switch (panel) {
      case OverlayPanel.pin:
        _container.read(pinOverlayViewModelProvider.notifier).prepareForOpen();
      case OverlayPanel.focus:
        await _container
            .read(focusTimerViewModelProvider.notifier)
            .prepareForOpen();
      case OverlayPanel.leaf:
        await _container.read(leafViewModelProvider.notifier).prepareForOpen();
      case OverlayPanel.awake:
        await _container
            .read(awakeViewModelProvider.notifier)
            .prepareForOpen();
      case OverlayPanel.echo:
        await _container
            .read(echoRecorderViewModelProvider.notifier)
            .prepareForOpen();
    }
  }

  void _handleMenuAction(MenuBarAction action) {
    switch (action) {
      case MenuBarAction.openPin:
        toggleOverlay(OverlayPanel.pin);
      case MenuBarAction.openFocus:
        toggleOverlay(OverlayPanel.focus);
      case MenuBarAction.openLeaf:
        toggleOverlay(OverlayPanel.leaf);
      case MenuBarAction.openAwake:
        toggleOverlay(OverlayPanel.awake);
      case MenuBarAction.openEcho:
        toggleOverlay(OverlayPanel.echo);
      case MenuBarAction.openHub:
        HubWindow.instance.open();
      case MenuBarAction.quit:
        _quit();
    }
  }

  Future<void> _quit() async {
    _backupTimer?.cancel();
    // A trava seria solta pelo sistema de qualquer forma quando o processo
    // morresse — mas o tempo em que ela valeu é do dia, e o Track o perderia.
    await _container.read(awakeViewModelProvider.notifier).turnOff();
    await GlobalShortcutService.instance.dispose();
    await MenuBarService.instance.dispose();
    exit(0);
  }
}

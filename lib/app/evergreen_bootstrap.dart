import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../core/system/global_shortcut_service.dart';
import '../core/system/global_shortcut_slot.dart';
import '../core/system/menu_bar_service.dart';
import '../core/system/module_settings_host.dart';
import '../core/system/notification_service.dart';
import '../core/system/startup_service.dart';
import '../core/window/hub_destination.dart';
import '../core/window/hub_window.dart';
import '../core/window/overlay_panel.dart';
import '../core/window/overlay_window.dart';
import '../features/awake/models/awake_notifications.dart';
import '../features/awake/presentation/viewmodels/awake_state.dart';
import '../features/awake/presentation/viewmodels/awake_view_model.dart';
import '../features/echo/data/echo_summary_runner.dart';
import '../features/echo/presentation/viewmodels/echo_recorder_state.dart';
import '../features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import '../features/focus/models/focus_notifications.dart';
import '../features/focus/presentation/viewmodels/focus_timer_state.dart';
import '../features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import '../features/home/models/evergreen_module.dart';
import '../features/home/models/module_settings.dart';
import '../features/home/presentation/viewmodels/app_settings_view_model.dart';
import '../features/leaf/presentation/viewmodels/leaf_view_model.dart';
import '../features/nest/presentation/viewmodels/nest_view_model.dart';
import '../features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import '../features/track/models/track_week_digest.dart';
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

  /// Assinatura dos arquivos soltos no painel. Ver [_watchNestDrops].
  StreamSubscription<List<String>>? _nestDrops;

  /// Assinatura do chacoalhar. Ver [_watchNestShake].
  StreamSubscription<void>? _nestShakes;

  /// Assinatura dos cliques nas notificações. Ver [_watchNotifications].
  StreamSubscription<EgNotificationResponse>? _notificationResponses;

  /// Relógio do resumo da semana. Ver [_scheduleWeekDigest].
  Timer? _weekTimer;

  /// As preferências de módulo em vigor.
  ///
  /// Guardadas aqui porque três caminhos precisam consultá-las fora da hora em
  /// que são aplicadas: o arquivo que cai no painel, o atalho que sobreviveu a
  /// um instante de corrida, e o item do menu clicado.
  ModuleSettings _modules = const ModuleSettings();

  Future<void> start() async {
    // Antes de qualquer painel existir: o chacoalhar chega com tudo fechado, e
    // é ele quem manda o painel aparecer.
    _container.read(nestChannelProvider).listen();
    _container.read(nestViewModelProvider.notifier).startListening();
    _watchNestDrops();
    _watchNestShake();
    unawaited(
      _container.read(echoRecorderViewModelProvider.notifier).initialize(),
    );
    unawaited(
      EchoSummaryHost.register(_container.read(echoSummaryRunnerProvider)),
    );

    _watchNotifications();
    // Antes de recuperar a sessão interrompida: recuperá-la pode zerar a
    // semana passada do Focus, e o resumo dela precisa ser lido antes.
    await _checkWeekDigest();

    // Antes de qualquer coisa que possa iniciar uma sessão nova: se o
    // Evergreen morreu no meio de uma, o tempo focado até ali entra no
    // histórico agora. Ver `FocusRun`.
    await _container
        .read(focusTimerViewModelProvider.notifier)
        .recoverInterruptedSession();

    await _syncLaunchAtLogin();
    await _setUpMenuBar();
    // Depois do menu existir e antes de qualquer relógio começar: é isto que
    // liga a captura do Pin, registra os atalhos e decide quem aparece na barra
    // de status. Também é o que o Hub chama de volta, pelo canal, toda vez que
    // alguém mexe num interruptor ou grava um atalho.
    await ModuleSettingsHost.register(
      onReapply: _applyModuleSettings,
      onSuspendChanged: _setShortcutsSuspended,
    );
    await GlobalShortcutService.instance.initialize();
    await _applyModuleSettings();
    // Depois da barra de menus existir: a primeira emissão já escreve o rótulo
    // nela, inclusive para limpá-lo.
    _watchFocusSession();
    _watchAwake();
    _watchEcho();
    _scheduleBackups();
    _scheduleWeekDigest();
    await _openHubIfRequested();
  }

  /// Verifica a virada da semana de dez em dez minutos.
  ///
  /// Curto de propósito, ao contrário do backup: o resumo precisa ser lido
  /// antes de a primeira sessão de foco da semana nova terminar, porque é ela
  /// que apaga a semana passada do histórico do Focus.
  void _scheduleWeekDigest() {
    _weekTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => unawaited(_checkWeekDigest()),
    );
  }

  Future<void> _checkWeekDigest() async {
    try {
      // O repositório, e não [_modules]: a primeira verificação acontece antes
      // de as preferências de módulo serem aplicadas.
      final modules = _container.read(moduleSettingsRepositoryProvider).load();
      await _container
          .read(trackWeekNotifierProvider)
          .check(enabled: modules.isEnabled(EvergreenModule.track));
    } catch (_) {
      // Banco travado, imagem que não desenhou: o resumo é enfeite, e nada
      // disso pode derrubar a abertura do aplicativo.
    }
  }

  /// O que cada clique numa notificação faz.
  ///
  /// Os botões conferem o estado antes de agir: a notificação fica no Centro
  /// de Notificações por horas, e "Começar pausa" clicado depois de a pessoa
  /// já ter começado outra sessão não pode atropelar a que está correndo.
  void _watchNotifications() {
    _notificationResponses = _container
        .read(notificationServiceProvider)
        .responses
        .listen((response) => unawaited(_handleNotification(response)));
  }

  Future<void> _handleNotification(EgNotificationResponse response) async {
    final focus = _container.read(focusTimerViewModelProvider.notifier);
    final focusState = _container.read(focusTimerViewModelProvider);
    final awake = _container.read(awakeViewModelProvider.notifier);

    switch ((response.id, response.action)) {
      case (FocusNotifications.id, FocusNotifications.startRest):
        if (focusState.isFinished && focusState.phase.isFocus) {
          focus.startRest();
        }
      case (FocusNotifications.id, FocusNotifications.startFocus):
        if (focusState.isFinished && !focusState.phase.isFocus) {
          focus.start(activity: focusState.activity);
        }
      case (FocusNotifications.id, null):
        await showOverlay(OverlayPanel.focus);
      case (AwakeNotifications.id, AwakeNotifications.again):
        if (_modules.isEnabled(EvergreenModule.awake) &&
            !_container.read(awakeViewModelProvider).isOn) {
          await awake.turnOn();
        }
      case (AwakeNotifications.id, null):
        await showOverlay(OverlayPanel.awake);
      case (TrackWeekDigest.id, null || TrackWeekDigest.openTrack):
        await HubDestination.request(EvergreenModule.track.id);
        await HubWindow.instance.open();
    }
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

  /// Põe o mundo de acordo com o que está gravado no disco.
  ///
  /// Chamado na abertura e a cada mudança feita no Hub — que é outro engine,
  /// e por isso a releitura do disco é a primeira coisa que acontece aqui.
  ///
  /// Três consequências, e as três precisam acontecer juntas para o
  /// interruptor não mentir: os atalhos globais, o menu da barra de status e os
  /// serviços que rodam em segundo plano. Um módulo desligado que continuasse
  /// gravando a área de transferência seria a pior das três metades.
  Future<void> _applyModuleSettings() async {
    final repository = _container.read(moduleSettingsRepositoryProvider);
    await repository.reload();

    final settings = _modules = repository.load();

    await GlobalShortcutService.instance.apply(
      settings.activeBindings,
      handlers: _shortcutHandlers,
    );

    await MenuBarService.instance.setLayout(
      modules: [
        for (final module in EvergreenModule.values)
          if (module.menuBarAction != null && settings.isEnabled(module))
            module.menuBarAction!,
      ],
      bindings: settings.allBindings,
    );

    await _applyRuntime(settings);
    await _applyPinSettings();
  }

  /// Relê as preferências do Pin nesta janela.
  ///
  /// Elas são editadas no Hub, que é outro engine com a própria cópia em
  /// memória — e quem captura a área de transferência é esta janela. Sem
  /// reler, desligar um tipo só valia no lançamento seguinte: a tela mostrava
  /// o tipo desligado e o Pin continuava guardando o que ele copiava.
  Future<void> _applyPinSettings() =>
      _container.read(pinSettingsRepositoryProvider).reload();

  /// O que cada atalho faz. Registrado uma vez e guardado pelo serviço: um
  /// [GlobalShortcutService.resume] depois de uma gravação precisa registrar
  /// tudo de novo, e a essa altura ninguém está por perto para dizer o que cada
  /// tecla faz.
  Map<GlobalShortcutSlot, Future<void> Function()> get _shortcutHandlers => {
    GlobalShortcutSlot.pin: () => toggleOverlay(OverlayPanel.pin),
    GlobalShortcutSlot.focus: () => toggleOverlay(OverlayPanel.focus),
    GlobalShortcutSlot.leaf: () => toggleOverlay(OverlayPanel.leaf),
    GlobalShortcutSlot.awake: () => toggleOverlay(OverlayPanel.awake),
    GlobalShortcutSlot.echo: () => toggleOverlay(OverlayPanel.echo),
    GlobalShortcutSlot.nest: () => toggleOverlay(OverlayPanel.nest),
    GlobalShortcutSlot.hub: HubWindow.instance.open,
  };

  /// Liga e desliga o que roda em segundo plano.
  ///
  /// Só age nas **mudanças**: religar o Pin a cada aplicação recarregaria o
  /// histórico e reclassificaria o banco inteiro por nada.
  ///
  /// Desligar um módulo encerra o que ele tinha em curso, e encerra
  /// **guardando** — a sessão do Focus vai para o histórico com o tempo que
  /// teve, a reunião do Echo é transcrita, a trava do Awake é solta e vira uma
  /// linha do dia. Deixar rodando seria pior que qualquer uma dessas: a tela do
  /// módulo desligado fica apagada, e não haveria de onde parar uma gravação
  /// que continuasse.
  Future<void> _applyRuntime(ModuleSettings settings) async {
    for (final module in EvergreenModule.values) {
      final enabled = settings.isEnabled(module);
      if (_running[module] == enabled) continue;

      _running[module] = enabled;
      await (enabled ? _startModule(module) : _stopModule(module));
    }

    // O painel de um módulo que acabou de ser desligado não pode ficar na tela:
    // ele é a única superfície do módulo que não está apagada.
    final panel = _container.read(overlayPanelProvider);
    if (!settings.isEnabled(EvergreenModule.of(panel)) &&
        await OverlayWindow.instance.isVisible()) {
      await OverlayWindow.instance.hide();
    }
  }

  /// O que está ligado agora, para [_applyRuntime] só mexer no que mudou.
  final _running = <EvergreenModule, bool>{};

  Future<void> _startModule(EvergreenModule module) async {
    switch (module) {
      case EvergreenModule.pin:
        _container.read(pinOverlayViewModelProvider.notifier).startWatching();
      case EvergreenModule.nest:
        await _applyNestSettings();
      case EvergreenModule.focus:
      case EvergreenModule.leaf:
      case EvergreenModule.awake:
      case EvergreenModule.echo:
      case EvergreenModule.track:
        // Não têm nada rodando fora do painel: o atalho e o item do menu, que
        // `_applyModuleSettings` já cuidou, são a porta inteira deles.
        break;
    }
  }

  Future<void> _stopModule(EvergreenModule module) async {
    switch (module) {
      case EvergreenModule.pin:
        await _container
            .read(pinOverlayViewModelProvider.notifier)
            .stopWatching();
      case EvergreenModule.nest:
        await _container
            .read(nestChannelProvider)
            .setShakeEnabled(enabled: false);
      case EvergreenModule.focus:
        _container.read(focusTimerViewModelProvider.notifier).stop();
      case EvergreenModule.awake:
        await _container.read(awakeViewModelProvider.notifier).turnOff();
      case EvergreenModule.echo:
        await _container
            .read(echoRecorderViewModelProvider.notifier)
            .stopAndTranscribe();
      case EvergreenModule.leaf:
      case EvergreenModule.track:
        break;
    }
  }

  /// Tira e devolve os atalhos do sistema enquanto o Hub grava um novo.
  ///
  /// Com uma rede embaixo: quem suspendeu foi o Hub, e o Hub é uma sub-janela
  /// que pode ser fechada no meio da gravação — fechada, o engine dela morre e
  /// o "devolve" nunca chega. Sem o relógio, o Evergreen ficaria sem atalho
  /// nenhum até ser reiniciado, e a pessoa não teria como adivinhar por quê.
  ///
  /// Um minuto é folgado para o que se está esperando (apertar uma combinação)
  /// e curto para o estrago.
  Future<void> _setShortcutsSuspended({required bool suspended}) async {
    _suspensionGuard?.cancel();
    _suspensionGuard = null;

    if (!suspended) {
      await GlobalShortcutService.instance.resume();
      return;
    }

    await GlobalShortcutService.instance.suspend();
    _suspensionGuard = Timer(const Duration(minutes: 1), () {
      unawaited(GlobalShortcutService.instance.resume());
    });
  }

  /// Ver [_setShortcutsSuspended].
  Timer? _suspensionGuard;

  Future<void> _setUpMenuBar() async {
    await MenuBarService.instance.initialize(onAction: _handleMenuAction);
  }

  /// Mantém a barra de menus e a janela em dia com o cronômetro do Focus.
  ///
  /// A assinatura também é o que segura o cronômetro vivo fora da árvore de
  /// widgets: a sessão precisa continuar correndo com o painel fechado.
  void _watchFocusSession() {
    _container.listen<FocusTimerState>(focusTimerViewModelProvider, (
      previous,
      next,
    ) {
      // Na primeira emissão (`previous` nulo) o rótulo é escrito sempre, até
      // quando é nulo: o texto na barra de menus vive no lado nativo e
      // sobrevive a um hot restart — sem essa escrita, um cronômetro que
      // morreu com o engine continuaria "rodando" na barra.
      if (previous == null || previous.menuBarLabel != next.menuBarLabel) {
        unawaited(MenuBarService.instance.setSessionLabel(next.menuBarLabel));
      }

      // Fim pelo prazo, e não pelo botão: só o prazo vencido chega a
      // `finished` com o relógio zerado.
      final timedOut =
          previous != null &&
          previous.isActive &&
          next.isFinished &&
          next.remaining == Duration.zero;

      // O contador de alertas só sobe quando uma fase termina sozinha e o
      // aviso na tela está ligado — comparar com o anterior evita reabrir o
      // painel a cada tique.
      final bringForward = next.alerts > (previous?.alerts ?? 0);

      if (timedOut || bringForward) {
        unawaited(
          _onFocusFinished(next, notify: timedOut, bringForward: bringForward),
        );
      }
    }, fireImmediately: true);
  }

  /// Avisa o fim da fase — pela notificação, a menos que o painel do Focus já
  /// esteja na frente de quem o usa, e trazendo o painel quando a preferência
  /// pede.
  ///
  /// A visibilidade é lida **antes** de o painel ser trazido: depois, ele
  /// estaria sempre à vista e a notificação nunca sairia.
  Future<void> _onFocusFinished(
    FocusTimerState state, {
    required bool notify,
    required bool bringForward,
  }) async {
    if (notify && !await _isOnScreen(OverlayPanel.focus)) {
      await _container
          .read(notificationServiceProvider)
          .post(
            FocusNotifications.finished(
              phase: state.phase,
              focused: state.focused,
              activity: state.activity,
              settings: state.settings,
            ),
          );
    }

    if (bringForward) await showOverlay(OverlayPanel.focus);
  }

  /// Mantém a barra de menus em dia com a trava do Awake.
  ///
  /// A assinatura também é o que segura a trava viva fora da árvore de widgets:
  /// ela precisa continuar valendo com o painel fechado, e o painel é a única
  /// outra coisa que observa esta ViewModel.
  void _watchAwake() {
    _container.listen<AwakeState>(awakeViewModelProvider, (previous, next) {
      if (next.expirations > (previous?.expirations ?? 0)) {
        unawaited(
          _container
              .read(notificationServiceProvider)
              .post(
                AwakeNotifications.expired(
                  duration: next.duration,
                  mode: next.mode,
                ),
              ),
        );
      }

      if (previous?.menuBarDetail == next.menuBarDetail) return;

      unawaited(MenuBarService.instance.setAwakeDetail(next.menuBarDetail));
    }, fireImmediately: true);
  }

  /// Põe a prateleira na tela quando arquivos chegam com ela fechada.
  ///
  /// É o mesmo caminho do alerta de fim de sessão do Focus: um evento de fundo
  /// que **mostra** o painel, nunca o esconde.
  void _watchNestDrops() {
    _nestDrops = _container
        .read(nestChannelProvider)
        .onDropped
        .listen((_) => unawaited(_bringNestForward()));
  }

  /// Com a prateleira já na tela, o arquivo que caiu nela só devolve o teclado
  /// ao painel — **sem mexer na janela**.
  ///
  /// Passar pelo [showOverlay] reposicionava a janela no lugar de sempre a cada
  /// arquivo solto, e quem tinha arrastado o painel para o lado (é para isso
  /// que ele é `draggable`) via a prateleira pular de volta para o meio da
  /// tela no instante em que soltava (#66).
  Future<void> _bringNestForward() async {
    if (await _isNestOnScreen()) {
      await OverlayWindow.instance.refocus();
      return;
    }

    await showOverlay(OverlayPanel.nest);
  }

  Future<bool> _isNestOnScreen() => _isOnScreen(OverlayPanel.nest);

  Future<bool> _isOnScreen(OverlayPanel panel) async =>
      await OverlayWindow.instance.isVisible() &&
      _container.read(overlayPanelProvider) == panel;

  /// O módulo dono deste painel está ligado?
  ///
  /// Toda porta passa por aqui: o atalho global, o item do menu, o arquivo que
  /// cai no painel e o chacoalhar. Os atalhos de um módulo desligado nem
  /// chegam a estar registrados e o item do menu nem está desenhado — esta é a
  /// terceira tranca, para o instante entre o interruptor virar e o sistema
  /// tomar conhecimento, e para o arraste do Finder, que é do lado nativo e não
  /// tem como perguntar.
  bool _isEnabled(OverlayPanel panel) =>
      _modules.isEnabled(EvergreenModule.of(panel));

  /// Põe a prateleira debaixo do cursor quando alguém chacoalha um arquivo.
  ///
  /// A porta que quem vem do Dropover tenta primeiro, e a única em que o painel
  /// vai até a pessoa em vez de o contrário: quem já está com um arquivo na mão
  /// não deve ter de arrastá-lo até o centro da tela.
  ///
  /// Com a prateleira já na tela, o gesto não faz nada — mover a janela debaixo
  /// de um arraste em curso seria pior que não reagir.
  void _watchNestShake() {
    _nestShakes = _container.read(nestChannelProvider).onShake.listen((_) {
      unawaited(_openNestAtCursor());
    });
  }

  Future<void> _openNestAtCursor() async {
    if (await _isNestOnScreen()) return;

    final cursor = await screenRetriever.getCursorScreenPoint();
    await showOverlay(OverlayPanel.nest, at: cursor);
  }

  /// Manda as preferências do Nest para o lado nativo na abertura.
  ///
  /// O chacoalhar vive fora de qualquer engine e nasce desligado a cada
  /// lançamento — sem isto, o interruptor mostraria "ligado" com o gesto morto.
  Future<void> _applyNestSettings() async {
    final repository = _container.read(nestSettingsRepositoryProvider);
    await repository.reload();

    final settings = repository.load();

    await _container
        .read(nestChannelProvider)
        .setShakeEnabled(enabled: settings.useShake);
  }

  /// Mantém a barra de menus em dia com a gravação do Echo.
  ///
  /// A assinatura também é o que segura a gravação viva fora da árvore de
  /// widgets: a reunião continua sendo gravada com o painel fechado, que é o
  /// caso normal — ninguém fica olhando um painel por trinta minutos.
  void _watchEcho() {
    _container.listen<EchoRecorderState>(echoRecorderViewModelProvider, (
      previous,
      next,
    ) {
      if (previous?.menuBarLabel == next.menuBarLabel) return;

      unawaited(MenuBarService.instance.setEchoLabel(next.menuBarLabel));
    }, fireImmediately: true);
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
    if (!_isEnabled(panel)) return Future<void>.value();

    return _pending = _pending
        .then((_) => _toggleOverlay(panel))
        .catchError((Object _) {});
  }

  /// Traz um painel para a frente sem nunca fechá-lo — o caminho do aviso de
  /// fim de sessão, onde esconder a janela seria o oposto do pedido.
  Future<void> showOverlay(OverlayPanel panel, {Offset? at}) {
    if (!_isEnabled(panel)) return Future<void>.value();

    return _pending = _pending
        .then((_) => _showOverlay(panel, at: at))
        .catchError((Object _) {});
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

  Future<void> _showOverlay(OverlayPanel panel, {Offset? at}) async {
    await _prepare(panel);
    _container.read(overlayPanelProvider.notifier).show(panel);

    // Já visível em outro painel: trocar o conteúdo basta, sem reabrir a
    // janela — mas o cursor pode ter ido para outro monitor desde a abertura, e
    // o atalho leva o painel para onde a pessoa está olhando. A reafirmação
    // também devolve o teclado ao painel: estar visível não é estar com o foco.
    if (await OverlayWindow.instance.isVisible()) {
      await OverlayWindow.instance.reassert(at: at);
      return;
    }

    await OverlayWindow.instance.show(at: at);
  }

  Future<void> _prepare(OverlayPanel panel) async {
    switch (panel) {
      case OverlayPanel.pin:
        unawaited(
          _container
              .read(pinOverlayViewModelProvider.notifier)
              .prepareForOpen(),
        );
      case OverlayPanel.focus:
        await _container
            .read(focusTimerViewModelProvider.notifier)
            .prepareForOpen();
      case OverlayPanel.leaf:
        await _container.read(leafViewModelProvider.notifier).prepareForOpen();
      case OverlayPanel.awake:
        await _container.read(awakeViewModelProvider.notifier).prepareForOpen();
      case OverlayPanel.echo:
        await _container
            .read(echoRecorderViewModelProvider.notifier)
            .prepareForOpen();
      case OverlayPanel.nest:
        await _container.read(nestViewModelProvider.notifier).prepareForOpen();
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
      case MenuBarAction.openNest:
        toggleOverlay(OverlayPanel.nest);
      case MenuBarAction.openHub:
        HubWindow.instance.open();
      case MenuBarAction.quit:
        _quit();
    }
  }

  Future<void> _quit() async {
    _backupTimer?.cancel();
    _weekTimer?.cancel();
    _suspensionGuard?.cancel();
    await _notificationResponses?.cancel();
    await _nestDrops?.cancel();
    await _nestShakes?.cancel();
    // A trava seria solta pelo sistema de qualquer forma quando o processo
    // morresse — mas o tempo em que ela valeu é do dia, e o Track o perderia.
    await _container.read(awakeViewModelProvider.notifier).turnOff();
    await GlobalShortcutService.instance.dispose();
    await MenuBarService.instance.dispose();
    exit(0);
  }
}

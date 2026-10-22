import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../core/design/themes/evergreen_tokens.dart';
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
import '../core/local_model/local_model_gate.dart';
import '../features/echo/data/echo_summary_runner.dart';
import '../features/echo/presentation/viewmodels/echo_recorder_state.dart';
import '../features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import '../features/focus/models/focus_notifications.dart';
import '../features/focus/presentation/viewmodels/focus_timer_state.dart';
import '../features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import '../features/home/models/evergreen_module.dart';
import '../features/home/models/module_settings.dart';
import '../features/home/presentation/viewmodels/app_settings_view_model.dart';
import '../features/leaf/models/leaf_notifications.dart';
import '../features/leaf/presentation/viewmodels/leaf_view_model.dart';
import '../features/nest/presentation/viewmodels/nest_view_model.dart';
import '../features/notch/data/notch_island_channel.dart';
import '../features/notch/models/notch_activity.dart';
import '../features/notch/models/notch_settings.dart';
import '../features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import '../features/track/models/track_week_digest.dart';
import '../shared/feature_flags.dart';
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

  /// Assinaturas do arquivo levado até o notch. Ver [_watchNestNotch].
  StreamSubscription<void>? _nestNotch;
  StreamSubscription<void>? _nestNotchEnded;

  /// O número do arraste mais recente que chegou ao notch, e o do que abriu a
  /// prateleira. Um número, e não um "sim ou não": o fim de um arraste só
  /// pode fechar a prateleira que **ele** abriu — nunca uma que a pessoa
  /// abriu de propósito pelo atalho. Ver [_closeNestIfUnused].
  int _notchGesture = 0;
  int? _nestOpenedByGesture;

  /// Algum arquivo foi solto na prateleira que saiu do notch.
  ///
  /// O "soltou" na janela, e não o "passou por cima": a janela 0 inteira é
  /// destino de arraste, transparente inclusive, e ela está encostada no
  /// recorte — o primeiro movimento depois de ela aparecer já conta como
  /// "por cima", antes de o arquivo chegar perto do painel. O "soltou" chega
  /// antes de o botão subir, e muito antes de cada arquivo ser lido do disco.
  bool _nestReceivedFromNotch = false;

  StreamSubscription<List<String>>? _nestNotchDrops;

  /// A pilha do notch: quando ela recolhe. Ver [_watchNestPile].
  StreamSubscription<bool>? _nestPointer;
  Timer? _pileTimer;

  /// O cursor já passou por cima da pilha desde que ela abriu — a partir daí,
  /// sair dela recolhe no prazo curto.
  bool _pileTouched = false;

  /// O último "dentro?" que o lado nativo avisou.
  bool _pilePointerInside = false;

  /// Qual abertura da pilha é a da vez. Um recolhimento que já estava na fila
  /// quando a pilha reabriu é de outra abertura, e não esconde nada.
  int _pileGeneration = 0;

  /// O que a ilha sabe sobre a pilha estar aberta embaixo dela.
  bool _islandQuiet = false;

  /// O prazo até recolher enquanto o cursor ainda não passou pela pilha.
  Duration _pileGrace = _pileLeave;

  /// Quanto a pilha espera, com o mouse fora, para voltar ao notch.
  static const _pileLeave = Duration(milliseconds: 1500);

  /// E quanto ela fica à vista quando foi o `⌘⇧R` que a abriu: o atalho é
  /// "me mostra o que está no Nest", e quem o apertou está olhando — o mouse
  /// está longe, em outro app, e um segundo e meio não dá para ler.
  static const _pileGlance = Duration(seconds: 3);

  /// Assinatura dos botões da ilha do notch. Ver [_watchNotch].
  StreamSubscription<NotchIslandEvent>? _notchActions;

  /// Assinatura do módulo que a ilha mostra, para a barra de menus não
  /// repeti-lo. Ver [_watchNotch].
  StreamSubscription<NotchModule?>? _notchOnShown;

  /// O que a ilha mostra agora, para só mandar ao canal o que mudou.
  List<NotchActivity> _notchShown = const [];

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
    _watchNestNotch();
    _watchNestPile();
    await _setUpNotch();
    unawaited(
      _container.read(echoRecorderViewModelProvider.notifier).initialize(),
    );
    unawaited(
      EchoSummaryHost.register(_container.read(echoSummaryRunnerProvider)),
    );
    unawaited(LocalModelHost.register(_container.read(localModelGateProvider)));
    // O que uma execução anterior carregou no LM Studio e não chegou a
    // descarregar — o Evergreen caiu no meio de um resumo. O `load` não tem
    // prazo de inatividade, então ninguém mais o tiraria da memória.
    unawaited(_container.read(lmStudioLocalModelProvider).sweep());

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
    _watchNotch();
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
    final leafNote = LeafNotifications.noteIdOf(response.id);
    if (leafNote != null) {
      await _handleLeafReminder(leafNote, action: response.action);
      return;
    }

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
    GlobalShortcutSlot.nest: _toggleNest,
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
      case EvergreenModule.leaf:
        // Os lembretes da parede voltam ao sistema — inclusive os que o
        // desligar tirou de lá.
        _container.read(leafViewModelProvider.notifier).scheduleReminders();
      case EvergreenModule.focus:
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
        // As duas portas juntas: desligar o Nest não pode deixar o notch
        // chamando uma prateleira apagada.
        final channel = _container.read(nestChannelProvider);
        await channel.setShakeEnabled(enabled: false);
        await channel.setNotchEnabled(enabled: false);
        await _container
            .read(notchIslandChannelProvider)
            .setEnabled(NotchModule.nest, enabled: false);
      case EvergreenModule.focus:
        _container.read(focusTimerViewModelProvider.notifier).stop();
      case EvergreenModule.awake:
        await _container.read(awakeViewModelProvider.notifier).turnOff();
      case EvergreenModule.echo:
        await _container
            .read(echoRecorderViewModelProvider.notifier)
            .stopAndTranscribe();
      case EvergreenModule.leaf:
        // Desligado, o Leaf não lembra de nada. Os horários ficam guardados
        // nos cartões e voltam com ele.
        _container.read(leafViewModelProvider.notifier).unscheduleReminders();
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

  /// O lembrete de um cartão: adiar, ou abrir a parede com ele escolhido.
  ///
  /// A seleção vem **depois** de o painel abrir: abrir relê a parede e põe a
  /// seleção no primeiro cartão, e o cartão lembrado tem de ser o da vez.
  Future<void> _handleLeafReminder(int noteId, {String? action}) async {
    final leaf = _container.read(leafViewModelProvider.notifier);

    if (action == LeafNotifications.snooze) {
      leaf.snooze(noteId);
      return;
    }

    await showOverlay(OverlayPanel.leaf);
    leaf.selectNote(noteId);
  }

  /// Avisa o fim da fase — pela notificação, a menos que o painel do Focus já
  /// esteja na frente de quem o usa, e trazendo o painel quando a preferência
  /// pede.
  ///
  /// A visibilidade é lida **antes** de o painel ser trazido: depois, ele
  /// estaria sempre à vista e a notificação nunca sairia.
  ///
  /// O som vai dentro da notificação. O alerta do sistema (`NSBeep`) só toca
  /// quando ela não sai — painel à vista, ou permissão negada —, senão seriam
  /// dois sons no mesmo instante.
  Future<void> _onFocusFinished(
    FocusTimerState state, {
    required bool notify,
    required bool bringForward,
  }) async {
    if (notify) {
      final shown =
          !await _isOnScreen(OverlayPanel.focus) &&
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

      if (!shown && state.settings.playSound) {
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
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
      // A pilha recebe o arquivo sem pegar o teclado — quem arrastou ainda
      // está no Finder.
      await OverlayWindow.instance.refocus(keyboard: !_isPileOnScreen);
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

    final notch = _container.read(notchSettingsRepositoryProvider);
    await notch.reload();
    final inNotch = notch.load().isEnabled(NotchModule.nest);

    // As duas metades do Nest no notch andam juntas: a porta (o arquivo levado
    // até lá) e a pilha que espera nele.
    await _container
        .read(nestChannelProvider)
        .setNotchEnabled(enabled: inNotch);
    await _container
        .read(notchIslandChannelProvider)
        .setEnabled(NotchModule.nest, enabled: inNotch);
  }

  /// `⌘⇧R` e o item do menu.
  ///
  /// Com arquivos esperando e o Nest no notch, o atalho mostra **a pilha, pelo
  /// notch** — onde ela mora enquanto não é mandada —, e ela volta para lá
  /// sozinha se o mouse não for até ela. Com a prateleira vazia não há pilha
  /// para mostrar, e o atalho abre a prateleira de sempre, no centro. Com o
  /// Nest já na tela, em qualquer formato, fecha.
  ///
  /// A decisão inteira acontece **dentro da fila**: dois `⌘⇧R` seguidos, ou um
  /// atalho chegando com um recolhimento já enfileirado, leriam "não está na
  /// tela" ao mesmo tempo, e o segundo abriria em vez de fechar.
  Future<void> _toggleNest() async {
    if (!_isEnabled(OverlayPanel.nest)) return;

    _queue(() async {
      if (await _isNestOnScreen()) {
        await OverlayWindow.instance.hide();
      } else if (await _canUseNestPile()) {
        await _openNestPile(keyboard: true, grace: _pileGlance);
      } else {
        await _showOverlay(OverlayPanel.nest);
      }
    });
  }

  Future<bool> _canUseNestPile() async {
    if (_container.read(nestViewModelProvider).isEmpty) return false;

    // Relida: quem liga e desliga o Nest no notch é o Hub, outro engine.
    final settings = _container.read(notchSettingsRepositoryProvider);
    await settings.reload();
    if (!settings.load().isEnabled(NotchModule.nest)) return false;

    return _container.read(notchIslandChannelProvider).hasNotch();
  }

  /// Abre a pilha do Nest embaixo do notch.
  ///
  /// [keyboard] só para o atalho: pelo mouse ou pelo arraste, quem está
  /// digitando em outro app continua digitando.
  Future<void> _openNestPile({
    required bool keyboard,
    required Duration grace,
  }) async {
    if (await _isNestOnScreen()) return;

    _container.read(nestViewModelProvider.notifier).clearSelection();
    await _showOverlay(OverlayPanel.nest, atNotch: true, keyboard: keyboard);
    _armPile(grace: grace);
  }

  /// A pilha está na tela, embaixo do notch — e não a prateleira completa.
  bool get _isPileOnScreen =>
      OverlayWindow.instance.visible.value &&
      OverlayWindow.instance.notchAnchor.value != null &&
      _container.read(overlayPanelProvider) == OverlayPanel.nest;

  /// Recolhe a pilha para o notch quando o mouse não está nela.
  ///
  /// Quem diz "dentro" ou "fora" é o relógio nativo que já segue o cursor para
  /// o clique atravessar a janela (`NestChannel.onPointerInside`), e com o
  /// botão apertado conta como dentro — o arquivo a caminho passa por fora da
  /// pilha. Recolher é só esconder: com arquivos, a ilha do Nest aparece
  /// sozinha (ver [_watchNotch]).
  void _watchNestPile() {
    _nestPointer = _container.read(nestChannelProvider).onPointerInside.listen((
      inside,
    ) {
      _pilePointerInside = inside;
      if (!_isPileOnScreen) return;

      if (inside) {
        _pileTouched = true;
        _pileTimer?.cancel();
        return;
      }

      _schedulePileCollapse();
    });
  }

  void _armPile({required Duration grace}) {
    _pileGeneration++;
    _pileTouched = false;
    _pileGrace = grace;
    _schedulePileCollapse();
  }

  void _schedulePileCollapse() {
    _pileTimer?.cancel();
    final generation = _pileGeneration;
    _pileTimer = Timer(
      _pileTouched ? _pileLeave : _pileGrace,
      () => _queue(() => _collapsePile(generation)),
    );
  }

  Future<void> _collapsePile(int generation) async {
    if (generation != _pileGeneration) return;
    if (!_isPileOnScreen || _pilePointerInside) return;

    await OverlayWindow.instance.hide();
  }

  /// Põe a prateleira embaixo do notch quando alguém para um arquivo nele.
  ///
  /// A terceira porta do Nest, e a única que não precisa de gesto nenhum: o
  /// arquivo já estava indo para cima. Com a prateleira já na tela, não faz
  /// nada — o mesmo raciocínio do chacoalhar.
  void _watchNestNotch() {
    final channel = _container.read(nestChannelProvider);

    _nestNotch = channel.onNotch.listen((_) {
      // Numerado aqui, de forma síncrona, e enfileirado já: o fim do arraste
      // pode chegar antes de qualquer `await` desta abertura, e precisa
      // encontrá-la na fila à frente dele.
      final gesture = ++_notchGesture;
      _queue(() => _openNestAtNotch(gesture));
    });

    _nestNotchEnded = channel.onNotchDragEnded.listen((_) {
      final gesture = _notchGesture;
      unawaited(
        Future<void>.delayed(
          _dropSettle,
        ).then((_) => _queue(() => _closeNestIfUnused(gesture))),
      );
    });

    _nestNotchDrops = channel.onDropped.listen((_) {
      if (_nestOpenedByGesture != null) _nestReceivedFromNotch = true;
    });
  }

  /// Põe uma operação de janela na fila — ver [_pending].
  void _queue(Future<void> Function() operation) {
    _pending = _pending.then((_) => operation()).catchError((Object _) {});
  }

  Future<void> _openNestAtNotch(int gesture) async {
    if (!_isEnabled(OverlayPanel.nest)) return;
    if (await _isNestOnScreen()) return;

    _nestOpenedByGesture = gesture;
    _nestReceivedFromNotch = false;
    _container.read(nestViewModelProvider.notifier).clearSelection();
    // Sem o teclado: quem arrasta um arquivo do Finder ainda está no Finder.
    await _showOverlay(OverlayPanel.nest, atNotch: true, keyboard: false);
    _armPile(grace: _pileLeave);
  }

  /// Quanto esperar, depois de o botão subir, antes de conferir se o arquivo
  /// chegou: a entrega do arraste e o aviso de "soltou" correm em caminhos
  /// diferentes do lado nativo, e o arquivo pode chegar um instante depois.
  /// A espera fica **fora** da fila de janela, para não atrasar o atalho de
  /// ninguém.
  static const _dropSettle = Duration(milliseconds: 300);

  /// Recolhe a prateleira que saiu do notch se o arraste acabou sem soltar
  /// nada nela.
  ///
  /// Quem levou o arquivo até o notch e desistiu — soltou de volta no Finder,
  /// ou em lugar nenhum — não pediu prateleira nenhuma; deixá-la vazia no topo
  /// da tela seria cobrar um Esc por um gesto que não aconteceu.
  ///
  /// A pergunta é "algum arquivo foi solto nela?", e não "ela tem itens?":
  /// os itens só entram depois de cada arquivo ser lido do disco, e soltar
  /// cinquenta arquivos de um volume de rede deixava a prateleira vazia por
  /// mais tempo que qualquer espera — ela se fechava com tudo chegando.
  Future<void> _closeNestIfUnused(int gesture) async {
    if (_nestOpenedByGesture != gesture) return;
    _nestOpenedByGesture = null;

    if (_nestReceivedFromNotch) return;
    if (!await _isNestOnScreen()) return;
    if (!_container.read(nestViewModelProvider).isEmpty) return;

    await OverlayWindow.instance.hide();
  }

  /// Prepara a ilha do notch: as cores e quem está ligado nela.
  ///
  /// A ilha vive fora de qualquer engine e nasce sem saber nada a cada
  /// lançamento — sem isto, o interruptor diria "ligado" e o notch ficaria
  /// vazio.
  Future<void> _setUpNotch() async {
    final channel = _container.read(notchIslandChannelProvider)..listen();
    await channel.configure(EvergreenTokens.palette);

    final settings = _container.read(notchSettingsRepositoryProvider).load();
    for (final module in [NotchModule.echo, NotchModule.focus]) {
      await channel.setEnabled(module, enabled: settings.isEnabled(module));
    }
  }

  /// Mantém a ilha do notch em dia com a reunião e a sessão de foco, e atende
  /// os botões dela.
  ///
  /// Escuta os dois e manda a lista inteira: quem decide qual dos dois aparece é
  /// a ordem (`NotchActivity.running`) somada a quem está ligado no notch, e
  /// isso o lado nativo sabe melhor — o Hub o avisa direto.
  void _watchNotch() {
    void push() {
      final running = NotchActivity.running(
        echo: _container.read(echoRecorderViewModelProvider),
        focus: _container.read(focusTimerViewModelProvider),
        // Sem filtrar pelo módulo ligado: quem decide é o lado nativo, que o
        // `_stopModule` desliga e o `_applyNestSettings` religa — filtrar aqui
        // deixava a ilha do Nest sem voltar ao religar o módulo.
        nest: _container.read(nestViewModelProvider),
        nestOnScreen:
            OverlayWindow.instance.visible.value &&
            _container.read(overlayPanelProvider) == OverlayPanel.nest,
      );
      // A ilha fica quieta com a pilha aberta embaixo dela: não abre por cima
      // do cabeçalho nem das pastas.
      final quiet = _isPileOnScreen;
      if (quiet != _islandQuiet) {
        _islandQuiet = quiet;
        unawaited(
          _container.read(notchIslandChannelProvider).setQuiet(quiet: quiet),
        );
      }

      if (listEquals(running, _notchShown)) return;

      _notchShown = running;
      unawaited(_container.read(notchIslandChannelProvider).update(running));
    }

    _container
      ..listen(echoRecorderViewModelProvider, (_, _) => push())
      ..listen(focusTimerViewModelProvider, (_, _) => push())
      ..listen(nestViewModelProvider, (_, _) => push())
      ..listen(overlayPanelProvider, (_, _) => push());
    // A janela aparecer e sumir é o que traz a pilha de volta ao notch.
    OverlayWindow.instance.visible.addListener(push);
    OverlayWindow.instance.notchAnchor.addListener(push);
    push();

    final channel = _container.read(notchIslandChannelProvider);
    _notchActions = channel.onAction.listen(
      (event) => unawaited(_handleNotchAction(event)),
    );

    // O relógio que a ilha mostra sai da barra de menus. Ela só avisa a
    // virada e sobrevive a um hot restart, então quem começa a escutar
    // pergunta também o que ela mostra agora.
    _notchOnShown = channel.onShown.listen(_showInMenuBar);
    unawaited(channel.shown().then(_showInMenuBar));
  }

  void _showInMenuBar(NotchModule? module) {
    final action = switch (module) {
      NotchModule.echo => MenuBarAction.openEcho,
      NotchModule.focus => MenuBarAction.openFocus,
      // A pilha do Nest não tem relógio na barra de menus.
      NotchModule.nest || null => null,
    };
    unawaited(MenuBarService.instance.setInNotch(action));
  }

  Future<void> _handleNotchAction(NotchIslandEvent event) async {
    switch (event.module) {
      case NotchModule.echo:
        final echo = _container.read(echoRecorderViewModelProvider.notifier);
        switch (event.action) {
          case NotchAction.pause:
            await echo.pause();
          case NotchAction.resume:
            await echo.resume();
          case NotchAction.stop:
            // Parar daqui transcreve em segundo plano, como desligar o
            // módulo: a reunião aparece no Hub quando estiver pronta, e quem
            // quiser acompanhar abre o painel.
            await echo.stopAndTranscribe();
          case NotchAction.open:
            await showOverlay(OverlayPanel.echo);
        }

      case NotchModule.focus:
        final focus = _container.read(focusTimerViewModelProvider.notifier);
        switch (event.action) {
          case NotchAction.pause:
            focus.pause();
          case NotchAction.resume:
            focus.resume();
          case NotchAction.stop:
            // Encerrar leva ao painel: é lá que o Focus pergunta o resumo e
            // oferece a pausa, e uma sessão encerrada sem ninguém ver a
            // pergunta ficaria esperando por ela até a próxima abertura.
            focus.stop();
            await showOverlay(OverlayPanel.focus);
          case NotchAction.open:
            await showOverlay(OverlayPanel.focus);
        }

      case NotchModule.nest:
        // O mouse em cima da ilha do Nest, ou um clique nela: a pilha sai do
        // notch, sem pegar o teclado de ninguém.
        if (event.action == NotchAction.open) {
          _queue(() async {
            if (!_isEnabled(OverlayPanel.nest)) return;

            // Com outro painel na frente — a busca do Pin a meio caminho —,
            // passar o mouse pelo notch não o troca pela pilha.
            if (await OverlayWindow.instance.isVisible() &&
                _container.read(overlayPanelProvider) != OverlayPanel.nest) {
              return;
            }
            await _openNestPile(keyboard: false, grace: _pileLeave);
          });
        }
    }
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
  ///
  /// Ligado — que é o padrão —, a apresentação de boas-vindas pendente abre o
  /// Hub mesmo assim. Ela mora no Hub, e o Evergreen não tem janela nem ícone
  /// no Dock: quem acabou de instalar pelo `.dmg` abria o app e não via nada,
  /// e a conclusão natural era que ele não tinha aberto. A régua é a da
  /// própria apresentação (uma vez por build), então quem atualiza também a
  /// encontra, e quem já a viu segue abrindo minimizado.
  Future<void> _openHubIfRequested() async {
    final onboardingPending =
        FeatureFlags.onboarding &&
        _container
            .read(onboardingRepositoryProvider)
            .shouldShow(_container.read(buildStampProvider));

    if (_container.read(appSettingsViewModelProvider).startMinimized &&
        !onboardingPending) {
      return;
    }
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
  Future<void> showOverlay(
    OverlayPanel panel, {
    Offset? at,
    bool atNotch = false,
  }) {
    if (!_isEnabled(panel)) return Future<void>.value();

    return _pending = _pending
        .then((_) => _showOverlay(panel, at: at, atNotch: atNotch))
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

  Future<void> _showOverlay(
    OverlayPanel panel, {
    Offset? at,
    bool atNotch = false,
    bool keyboard = true,
  }) async {
    await _prepare(panel);
    _container.read(overlayPanelProvider.notifier).show(panel);

    // Já visível em outro painel: trocar o conteúdo basta, sem reabrir a
    // janela — mas o cursor pode ter ido para outro monitor desde a abertura, e
    // o atalho leva o painel para onde a pessoa está olhando. A reafirmação
    // também devolve o teclado ao painel: estar visível não é estar com o foco.
    if (await OverlayWindow.instance.isVisible()) {
      await OverlayWindow.instance.reassert(
        at: at,
        atNotch: atNotch,
        keyboard: keyboard,
      );
      return;
    }

    await OverlayWindow.instance.show(
      at: at,
      atNotch: atNotch,
      keyboard: keyboard,
    );
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
        unawaited(_toggleNest());
      case MenuBarAction.openHub:
        HubWindow.instance.open();
      case MenuBarAction.uninstall:
        unawaited(_askToUninstall());
      case MenuBarAction.quit:
        _quit();
    }
  }

  /// Leva ao Hub com a pergunta de desinstalar na tela. O destino antes da
  /// janela, como no "Abrir no Hub" do Echo — ver [HubDestination].
  Future<void> _askToUninstall() async {
    await HubDestination.request(HubDestination.uninstall);
    await HubWindow.instance.open();
  }

  Future<void> _quit() async {
    _backupTimer?.cancel();
    _weekTimer?.cancel();
    _suspensionGuard?.cancel();
    await _notificationResponses?.cancel();
    await _nestDrops?.cancel();
    await _nestShakes?.cancel();
    await _nestNotch?.cancel();
    await _nestNotchEnded?.cancel();
    await _nestNotchDrops?.cancel();
    await _nestPointer?.cancel();
    _pileTimer?.cancel();
    await _notchActions?.cancel();
    await _notchOnShown?.cancel();
    // A ilha é uma janela nativa: sem isto ela ficaria no notch até o processo
    // morrer, que é um instante depois — mas um instante com um relógio parado.
    await _container.read(notchIslandChannelProvider).update(const []);
    // A trava seria solta pelo sistema de qualquer forma quando o processo
    // morresse — mas o tempo em que ela valeu é do dia, e o Track o perderia.
    await _container.read(awakeViewModelProvider.notifier).turnOff();
    await GlobalShortcutService.instance.dispose();
    await MenuBarService.instance.dispose();
    exit(0);
  }
}

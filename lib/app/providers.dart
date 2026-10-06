import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import '../core/storage/app_database.dart';
import '../core/system/module_settings_host.dart';
import '../core/system/notification_service.dart';
import '../core/storage/backup_service.dart';
import '../core/storage/export_service.dart';
import '../core/window/overlay_panel.dart';
import '../core/window/window_kind.dart';
import '../features/awake/data/awake_session_repository.dart';
import '../features/awake/data/awake_settings_repository.dart';
import '../features/awake/data/sleep_assertion_service.dart';
import '../features/echo/data/echo_channel.dart';
import '../features/echo/data/echo_repository.dart';
import '../features/echo/data/echo_settings_repository.dart';
import '../features/echo/data/echo_summary_runner.dart';
import '../features/focus/data/focus_run_repository.dart';
import '../features/focus/data/focus_session_repository.dart';
import '../features/focus/data/focus_settings_repository.dart';
import '../core/app_info.dart';
import '../features/home/data/app_settings_repository.dart';
import '../features/home/data/hub_intro_repository.dart';
import '../features/home/data/module_settings_repository.dart';
import '../features/home/data/onboarding_repository.dart';
import '../features/leaf/data/leaf_repository.dart';
import '../features/nest/data/nest_channel.dart';
import '../features/nest/data/nest_file_service.dart';
import '../features/nest/data/nest_settings_repository.dart';
import '../features/nest/data/nest_transfer_repository.dart';
import '../features/pin/data/clipboard_repository.dart';
import '../features/pin/data/clipboard_watcher.dart';
import '../features/pin/data/pin_settings_repository.dart';
import '../features/track/data/track_repository.dart';
import '../features/track/data/track_summarizer.dart';
import '../features/track/data/track_summary_cache.dart';
import '../features/track/data/track_week_notifier.dart';

/// Dependências resolvidas antes do `runApp` e injetadas via `overrides`.
///
/// Manter banco e preferências como providers sobrescritos evita `await` dentro
/// da árvore de widgets — a UI nunca precisa lidar com um estado "carregando
/// infraestrutura".
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('appDatabaseProvider precisa de override no main'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw StateError('sharedPreferencesProvider precisa de override no main'),
);

/// Qual janela este engine está desenhando.
///
/// Sobrescrito no `main` a partir do argumento que o engine recebeu. O padrão
/// é a janela 0 porque é ela quem hospeda os serviços de fundo — e porque um
/// teste, que não tem janela nenhuma, quer o comportamento de quem faz o
/// trabalho, não o de quem o delega.
final windowKindProvider = Provider<WindowKind>((ref) => WindowKind.overlay);

/// Os backups do banco, na subpasta `Backups` do próprio aplicativo.
///
/// Ali, e não em `~/Documents`: o backup automático precisa acontecer sozinho,
/// e escrever na pasta de Documentos faz o macOS pedir permissão numa hora que
/// ninguém escolheu — um pedido que, recusado, deixaria a proteção desligada
/// sem ninguém saber. A pasta do aplicativo não pede nada, e a tela de
/// preferências tem o botão que a abre no Finder.
final backupServiceProvider = Provider<BackupService>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return BackupService(
    database: database.db,
    directory: Directory(p.join(database.directoryPath, 'Backups')),
  );
});

/// Os textos que saem do Evergreen, na subpasta `Exportações` do aplicativo.
///
/// Ao lado dos backups, e pela mesma razão: ali o macOS não pede permissão
/// nenhuma, e `~/Documents` pediria — no meio de um clique em "Exportar", o
/// que transformaria uma ação de um passo numa caixa de diálogo do sistema.
/// A pasta é funda, então quem escreve o arquivo o mostra no Finder.
final exportServiceProvider = Provider<ExportService>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return LocalExportService(
    directory: Directory(p.join(database.directoryPath, 'Exportações')),
  );
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Quem avisa a janela 0 de que as preferências de módulo mudaram.
///
/// Provider, e não uma chamada estática, para o teste de widget poder pôr uma
/// imitação em memória no lugar: no relógio falso do binding a resposta do
/// canal nunca chega, e a tela que grava um atalho ficaria esperando para
/// sempre. Ver [ModuleSettingsNotifier].
final moduleSettingsNotifierProvider = Provider<ModuleSettingsNotifier>(
  (ref) => const ChannelModuleSettingsNotifier(),
);

/// Quais módulos estão ligados e que tecla abre cada um.
///
/// Lido nos dois engines: o Hub escreve, a janela 0 aplica. Ver
/// `ModuleSettingsHost`.
final moduleSettingsRepositoryProvider = Provider<ModuleSettingsRepository>(
  (ref) => ModuleSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final hubIntroRepositoryProvider = Provider<HubIntroRepository>(
  (ref) => HubIntroRepository(ref.watch(sharedPreferencesProvider)),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(sharedPreferencesProvider)),
);

/// Assinatura da build instalada, lida uma vez por engine.
///
/// É um provider, e não uma chamada direta a [AppInfo.readBuildStamp], para o
/// teste poder dizer qual build ele está simulando — a data do executável real,
/// dentro do `flutter_tester`, é a do próprio `flutter_tester`.
final buildStampProvider = Provider<String>((ref) => AppInfo.readBuildStamp());

final clipboardRepositoryProvider = Provider<ClipboardRepository>(
  (ref) => SqliteClipboardRepository(ref.watch(appDatabaseProvider).db),
);

final pinSettingsRepositoryProvider = Provider<PinSettingsRepository>(
  (ref) => PinSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final clipboardWatcherProvider = Provider<ClipboardWatcher>((ref) {
  final watcher = ClipboardWatcher();
  ref.onDispose(watcher.dispose);
  return watcher;
});

/// Relógio da aplicação.
///
/// É uma dependência como outra qualquer: o cronômetro do Focus mede tempo
/// real, e sem esta costura não daria para verificar uma sessão de 25 minutos
/// sem esperar 25 minutos.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>(
  (ref) => SqliteFocusSessionRepository(ref.watch(appDatabaseProvider).db),
);

final focusSettingsRepositoryProvider = Provider<FocusSettingsRepository>(
  (ref) => FocusSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final focusRunRepositoryProvider = Provider<FocusRunRepository>(
  (ref) => FocusRunRepository(ref.watch(sharedPreferencesProvider)),
);

final awakeSettingsRepositoryProvider = Provider<AwakeSettingsRepository>(
  (ref) => AwakeSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final leafRepositoryProvider = Provider<LeafRepository>(
  (ref) => SqliteLeafRepository(ref.watch(appDatabaseProvider).db),
);

/// A conversa com o destino de arraste, o QuickLook e o seletor de pasta.
///
/// Provider (e não instância global) porque é o que o teste substitui para
/// verificar o painel do Nest sem Finder e sem miniatura.
final nestChannelProvider = Provider<NestChannel>((ref) {
  final channel = NestChannel();
  ref.onDispose(channel.dispose);
  return channel;
});

final nestSettingsRepositoryProvider = Provider<NestSettingsRepository>(
  (ref) => NestSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final nestTransferRepositoryProvider = Provider<NestTransferRepository>(
  (ref) => SqliteNestTransferRepository(ref.watch(appDatabaseProvider).db),
);

/// Quem copia e move arquivo pelo Nest.
///
/// Provider (e não uma instância solta) porque o serviço carrega o relógio da
/// aplicação: a hora de uma transferência é o que a agrupa no dia do Track, e
/// verificar isso sem esperar a meia-noite chegar exige poder trocá-lo.
final nestFileServiceProvider = Provider<NestFileService>(
  (ref) => LocalNestFileService(clock: ref.watch(clockProvider)),
);

final echoRepositoryProvider = Provider<EchoRepository>(
  (ref) => SqliteEchoRepository(ref.watch(appDatabaseProvider).db),
);

final echoSettingsRepositoryProvider = Provider<EchoSettingsRepository>(
  (ref) => EchoSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// A conversa com o gravador, o transcritor e o modelo de resumo.
///
/// Provider (e não instância global) porque é o que o teste substitui para
/// verificar o painel do Echo sem microfone, sem reunião e sem modelo.
final echoChannelProvider = Provider<EchoChannel>((ref) {
  final channel = EchoChannel();
  ref.onDispose(channel.dispose);
  return channel;
});

/// Quem resume uma reunião — e, dependendo da janela, quem manda resumir.
///
/// No engine da janela 0 é o [LocalEchoSummaryRunner], que faz o trabalho e
/// atende o canal. No Hub é o [WindowEchoSummaryRunner], que pede à janela 0 e
/// depois pergunta como vai. A troca acontece aqui, e não no chamador, porque
/// **onde o resumo roda é uma decisão de infraestrutura**: quem aperta
/// "Resumir" não tem nada com isso.
///
/// A razão de existir dessa divisão: o Hub é uma sub-janela, e fechá-la destrói
/// o engine dela junto com todo trabalho pendente. Um resumo pedido e deixado
/// correndo enquanto se fecha a janela simplesmente sumia.
final echoSummaryRunnerProvider = Provider<EchoSummaryRunner>((ref) {
  if (ref.watch(windowKindProvider) == WindowKind.hub) {
    return const WindowEchoSummaryRunner();
  }

  return LocalEchoSummaryRunner(
    repository: ref.watch(echoRepositoryProvider),
    settings: ref.watch(echoSettingsRepositoryProvider),
    appSettings: ref.watch(appSettingsRepositoryProvider),
    channel: ref.watch(echoChannelProvider),
  );
});

/// A leitura agregada que o Track faz das tabelas dos outros módulos.
///
/// Só leitura: o Track não tem tabela própria nem migração — ele é a consulta
/// que junta foco, reuniões, cópias e anotações por dia.
final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => SqliteTrackRepository(ref.watch(appDatabaseProvider).db),
);

/// Quem escreve o parágrafo do dia, no mesmo modelo local que resume as
/// reuniões do Echo — e com a mesma degradação silenciosa quando ele não está
/// disponível.
final trackSummarizerProvider = Provider<TrackSummarizer>(
  (ref) => TrackSummarizer(
    ref.watch(echoChannelProvider),
    ref.watch(appSettingsRepositoryProvider).load().userName,
  ),
);

/// O parágrafo já escrito de cada dia, no plist — ver [TrackSummaryCache].
final trackSummaryCacheProvider = Provider<TrackSummaryCache>(
  (ref) => TrackSummaryCache(ref.watch(sharedPreferencesProvider)),
);

/// As notificações locais — ver `NotificationChannel.swift`.
///
/// Provider para o teste poder trocar o canal por uma imitação. Só a janela 0
/// tem o lado nativo; no Hub cada `post` responde `false`.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = ChannelNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// O resumo da semana passada, avisado na primeira verificação da segunda.
final trackWeekNotifierProvider = Provider<TrackWeekNotifier>(
  (ref) => TrackWeekNotifier(
    repository: ref.watch(trackRepositoryProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    appSettings: ref.watch(appSettingsRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// A trava que impede o display de dormir.
///
/// Provider (e não uma instância global) porque é o que o teste substitui para
/// verificar o cronômetro do Awake sem tocar no IOKit.
final sleepAssertionServiceProvider = Provider<SleepAssertionService>(
  (ref) => NativeSleepAssertionService(),
);

final awakeSessionRepositoryProvider = Provider<AwakeSessionRepository>(
  (ref) => SqliteAwakeSessionRepository(ref.watch(appDatabaseProvider).db),
);

/// Painel que a janela flutuante está mostrando.
///
/// Só faz sentido no engine da janela 0, o único que desenha o overlay: o
/// atalho global de cada módulo escreve aqui antes de mandar a janela aparecer.
final overlayPanelProvider =
    NotifierProvider<OverlayPanelController, OverlayPanel>(
      OverlayPanelController.new,
    );

class OverlayPanelController extends Notifier<OverlayPanel> {
  @override
  OverlayPanel build() => OverlayPanel.pin;

  void show(OverlayPanel panel) => state = panel;
}

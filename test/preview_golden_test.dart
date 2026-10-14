@Tags(['preview'])
library;

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/storage/backup_service.dart';
import 'package:evergreen/core/storage/disk_usage_service.dart';
import 'package:evergreen/core/design/app_metrics.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/features/awake/models/awake_duration.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_view_model.dart';
import 'package:evergreen/features/awake/presentation/views/awake_overlay_view.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import 'package:evergreen/features/echo/presentation/views/echo_overlay_view.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:evergreen/features/focus/models/focus_session_note.dart';
import 'package:evergreen/features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import 'package:evergreen/features/focus/presentation/views/focus_overlay_view.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/leaf/models/leaf_note.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_view_model.dart';
import 'package:evergreen/features/leaf/presentation/views/leaf_overlay_view.dart';
import 'package:evergreen/features/nest/data/nest_transfer_repository.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_view_model.dart';
import 'package:evergreen/features/nest/presentation/views/nest_overlay_view.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import 'package:evergreen/features/pin/presentation/views/pin_overlay_view.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/track/data/track_repository.dart';
import 'package:evergreen/features/track/presentation/widgets/track_day_list.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:evergreen/shared/widgets/eg_search_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'features/awake/fake_sleep_assertion_service.dart';
import 'features/echo/fake_echo_channel.dart';
import 'features/focus/fake_focus_session_repository.dart';
import 'features/leaf/fake_leaf_repository.dart';
import 'shared/fake_notification_service.dart';
import 'features/nest/fake_nest_channel.dart';
import 'features/pin/fake_clipboard_repository.dart';
import 'golden_fonts.dart';
import 'features/echo/fake_export_service.dart';
import 'features/echo/fake_echo_audio.dart';
import 'features/home/fake_disk_usage_service.dart';

/// Goldens usados como conferência visual do design durante o desenvolvimento.
///
/// Rode com `flutter test --update-goldens --tags preview` para regerar as
/// imagens em `test/goldens/`. Não fazem parte da suíte padrão: são um apoio de
/// revisão, não uma trava de regressão.
/// A janela do Hub, em pixels físicos: 980×680 lógicos a 2x.
///
/// Fixa, como a janela de verdade — o golden do Hub deixou de ser uma medida
/// escolhida no teste e passou a ser a janela que a pessoa abre.
const _hubWindow = Size(1960, 1360);

/// A mesma janela com a região de leitura aberta: 980 + 480.
const _hubWindowWithRegion = Size(2920, 1360);

void main() {
  setUpAll(loadGoldenFonts);

  // A versão da barra lateral do Hub sai do bundle, que não existe em teste.
  // Fixá-la aqui mantém os goldens estáveis quando o pubspec mudar de versão —
  // é o design que eles conferem, não o número.
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Evergreen',
      packageName: 'com.evergreen.app',
      version: '0.3.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppInfo.load();
  });

  late SharedPreferences preferences;
  late Database echoDb;
  late FakeEchoChannel channel;
  late FakeEchoPlayer echoPlayer;
  late BackupService backups;
  late FakeNestChannel nestChannel;

  /// Os arquivos que aparecem na prateleira do Nest. Existem no disco de
  /// verdade, numa pasta temporária: o cartão lê tamanho e data do sistema de
  /// arquivos, e uma imitação teria de mentir sobre as duas coisas.
  late Directory nestFiles;

  /// O "hoje" das imagens do Track: a quinta-feira em que a reunião do Echo
  /// acontece. Fixo porque o módulo lê a semana corrente — com o relógio real
  /// as fixtures cairiam fora do recorte e a tela sairia vazia.
  final trackToday = DateTime(2026, 7, 23, 16, 20);

  /// O "agora" da tela de preferências, pelo mesmo motivo do [trackToday]: a
  /// lista de backups rotula as datas como "Hoje"/"Ontem" e a linha do último
  /// backup diz "há N horas".
  final backupToday = DateTime(2026, 8, 25, 16, 20);

  setUp(() async {
    // Duas chaves, dois caminhos de primeira vez que este teste não quer: a
    // apresentação de boas-vindas (que espera seis cliques em "Próximo") e a
    // pergunta do nome (que leva o Hub para a tela do aplicativo). Aqui o app
    // já foi apresentado nesta build e já sabe com quem fala.
    SharedPreferences.setMockInitialValues({
      'app.onboarding_seen_build': AppInfo.readBuildStamp(),
      'app.user_name': 'Lucas',
    });
    preferences = await SharedPreferences.getInstance();

    nestChannel = FakeNestChannel();
    nestFiles = Directory.systemTemp.createTempSync('nest_golden');
    addTearDown(() => nestFiles.deleteSync(recursive: true));
    addTearDown(nestChannel.dispose);

    // A tela do Pin pergunta ao canal nativo se a permissão de Acessibilidade
    // existe, e sob `flutter test` não há lado nativo para responder: a
    // exceção subia no meio do primeiro quadro e derrubava toda tela do Hub.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('previous_app_focus'),
          (call) async =>
              call.method == 'hasAccessibilityPermission' ? true : null,
        );

    // O Echo lê as reuniões do banco; a conferência visual precisa de uma
    // reunião com transcrição para a tela do Hub não sair vazia.
    echoDb = sqlite3.openInMemory();
    AppDatabase.migrate(echoDb);
    SqliteEchoRepository(echoDb).insert(
      Meeting(
        title: 'Alinhamento de escopo',
        startedAt: DateTime(2026, 7, 23, 10, 30),
        // Com áudio: é o que põe o player no topo da leitura.
        audioFile: 'alinhamento.m4a',
        durationMs: const Duration(minutes: 32).inMilliseconds,
        language: TranscriptionLanguage.ptBR,
        summary:
            '- O escopo da v1 fica só na transcrição; o resumo entra depois.\n'
            '- Lucas fecha a proposta até sexta.\n'
            '- Ficou pendente decidir quem apresenta na terça.',
        // A instrução que produziu o resumo acima: é ela que a folha de
        // conferência precisa mostrar embaixo dele, em caps e discreta.
        summaryPrompt:
            'Escreva em tópicos curtos. Registre decisões, pendências e quem '
            'ficou responsável por cada coisa.',
        // Fragmentado como o modelo de fala realmente devolve — é o
        // agrupamento em turnos que a imagem precisa mostrar.
        segments: const [
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 4000,
            endMs: 9000,
            text: 'Então, a ideia é fechar o escopo hoje ainda',
            // Duas vozes do outro lado, como a separação grava agora — é o
            // que põe "Pessoa 1" e "Pessoa 2" na folha, cada uma no seu turno
            // e as duas no mesmo tom neutro.
            voice: 1,
            // Com o relógio de cada palavra, como a transcrição grava agora —
            // é o que deixa a folha "tocando" acender uma palavra só.
            words: [
              MeetingWord(startMs: 4000, endMs: 4500, text: 'Então,'),
              MeetingWord(startMs: 4600, endMs: 4700, text: ' a'),
              MeetingWord(startMs: 4800, endMs: 5200, text: ' ideia'),
              MeetingWord(startMs: 5300, endMs: 5400, text: ' é'),
              MeetingWord(startMs: 5500, endMs: 6000, text: ' fechar'),
              MeetingWord(startMs: 6100, endMs: 6200, text: ' o'),
              MeetingWord(startMs: 6300, endMs: 7000, text: ' escopo'),
              MeetingWord(startMs: 7100, endMs: 7600, text: ' hoje'),
              MeetingWord(startMs: 7700, endMs: 9000, text: ' ainda'),
            ],
          ),
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 9000,
            endMs: 12000,
            text: ', se todo mundo concordar.',
            voice: 1,
          ),
          MeetingSegment(
            speaker: Speaker.me,
            startMs: 13500,
            endMs: 17000,
            text: 'Fechado. Eu mando a proposta até sexta',
          ),
          MeetingSegment(
            speaker: Speaker.me,
            startMs: 17000,
            endMs: 21000,
            text: ' com os números revisados.',
          ),
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 22000,
            endMs: 31000,
            text: 'Perfeito. Falta só decidir quem apresenta na terça.',
            voice: 2,
          ),
        ],
      ),
    );

    channel = FakeEchoChannel()
      ..summaryValue =
          'Você passou a maior parte do dia no módulo de autenticação, em três '
          'sessões de foco que somaram quase duas horas, e ainda gravou o '
          'alinhamento de escopo da manhã. O que passou pela área de '
          'transferência foi sobretudo link e comando — dia de leitura e '
          'terminal.';

    // O Track lê as quatro tabelas: as três primeiras são as fixtures dos
    // outros módulos, e é a soma delas que a folha de conferência mostra.
    seedTrack(echoDb, trackToday);

    // A pasta de backups da conferência visual, com um histórico plausível: o
    // de hoje de manhã e os das duas semanas anteriores. Ancorada em
    // [backupToday], e não no relógio real, para a imagem não mudar conforme a
    // hora em que ela for regerada.
    final directory = Directory.systemTemp.createTempSync('evergreen-goldens');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    backups = BackupService(
      database: echoDb,
      directory: Directory('${directory.path}/Backups'),
    );

    for (final daysAgo in [14, 7, 0]) {
      backups.create(
        at: DateTime(
          backupToday.year,
          backupToday.month,
          backupToday.day - daysAgo,
          9,
          12,
        ),
      );
    }
  });

  tearDown(() {
    echoDb.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('previous_app_focus'),
          null,
        );
  });

  final base = DateTime(2026, 7, 23, 12);

  ClipboardItem item(int id, String content, {bool isPinned = false}) =>
      ClipboardItem.capture(
        content,
        at: base.subtract(Duration(minutes: id)),
      ).copyWith(id: id, isPinned: isPinned);

  final repository = FakeClipboardRepository([
    item(1, 'Flutter', isPinned: true),
    item(2, 'git pull origin develop', isPinned: true),
    item(4, 'https://pub.dev/packages/sqlite3'),
    // Um item apelidado: na lista o apelido vem à frente e o conteúdo fica
    // atrás dele, em segundo plano.
    item(6, 'Senha temporária: xK9#mPz2').copyWith(alias: 'senha do roteador'),
    item(9, 'flutter pub get'),
    // Um de cada tipo que o classificador reconhece: é o que faz a fila de
    // filtros aparecer inteira na folha de conferência, com os sete rótulos e
    // os ícones novos.
    item(11, 'contato@evergreen.com.br'),
    item(13, '(11) 98765-4321'),
    item(14, 'https://github.com/evergreen/pin'),
    item(21, '529.982.247-25'),
    item(30, 'const context.eg.colors.accent = Color(0xFF22C55E);'),
  ]);

  // Ancoradas no dia de hoje, e não em `base`: o histórico rotula as datas
  // como "Hoje"/"Ontem", que é como a tela realmente se apresenta a quem usa.
  final anchor = DateTime.now();

  final sessions = FakeFocusSessionRepository([
    FocusSession(
      id: 1,
      startedAt: DateTime(anchor.year, anchor.month, anchor.day, 9, 12),
      duration: const Duration(minutes: 25),
      activity: 'Refatorar o módulo de auth',
      summary: 'Terminei a migração do repositório',
      notes: const [
        FocusSessionNote(minute: 12, text: 'terminei a task e comecei outra'),
      ],
    ),
    FocusSession(
      id: 2,
      startedAt: DateTime(anchor.year, anchor.month, anchor.day, 10, 5),
      duration: const Duration(minutes: 25),
      activity: 'Revisar a PR do design system',
    ),
    FocusSession(
      id: 3,
      startedAt: DateTime(anchor.year, anchor.month, anchor.day, 14, 40),
      duration: const Duration(minutes: 45),
    ),
  ]);

  // Cinco vagas ocupadas de nove: mostra a grade cheia de conteúdo real, a
  // terceira linha ainda por nascer e a vaga que convida a próxima.
  final notes = FakeLeafRepository([
    LeafNote(
      id: 1,
      slot: 1,
      content: 'ligar pro contador antes de sexta',
      createdAt: anchor.subtract(const Duration(days: 3)),
    ),
    // Uma anotação no tamanho para que o cartão foi calibrado: o recado de uma
    // reunião, inteiro, sem reticências.
    LeafNote(
      id: 2,
      slot: 2,
      content:
          'Marina fecha o contrato até sexta. Cobrar o jurídico antes de '
          'quarta e mandar a minuta revisada junto.',
      createdAt: anchor.subtract(const Duration(hours: 5)),
    ),
    LeafNote(
      id: 3,
      slot: 3,
      content: 'perguntar do deploy de quinta',
      createdAt: anchor.subtract(const Duration(hours: 2)),
      // Um cartão com lembrete marcado: o sino e a hora no pé. Hora fixa
      // amanhã, para a imagem não mudar com o relógio de quem roda o teste.
      remindAt: DateTime(anchor.year, anchor.month, anchor.day + 1, 15, 30),
    ),
    LeafNote(
      id: 4,
      slot: 4,
      content: 'senha do wi-fi: verde-estufa-2026',
      createdAt: anchor.subtract(const Duration(minutes: 40)),
      // O cartão sob o vidro fosco.
      isHidden: true,
    ),
    LeafNote(
      id: 5,
      slot: 5,
      content: 'pizza sem cebola',
      createdAt: anchor.subtract(const Duration(minutes: 4)),
    ),
  ]);

  /// [beforeSettle] roda entre a montagem e o `pumpAndSettle` — é onde o
  /// histórico entra. Antes disso o overlay mostra o indicador de carregamento,
  /// que é indeterminado e nunca deixaria o `pumpAndSettle` terminar.
  /// [fakeClock] troca o relógio da aplicação pelo do binding, que anda com
  /// `tester.pump`. Só o painel em sessão precisa disso; nas telas do Hub o
  /// relógio falso jogaria as datas para 2015 e o histórico perderia o "Hoje".
  /// [now] fixa o relógio numa data escolhida — é o que o Track precisa, porque
  /// ele lê a semana corrente e as fixtures dele têm data fixa.
  Future<void> pump(
    WidgetTester tester,
    Widget home,
    Size size, {
    VoidCallback? beforeSettle,
    bool fakeClock = false,
    DateTime? now,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(repository),
          focusSessionRepositoryProvider.overrideWithValue(sessions),
          // Sem isso, ligar a trava chamaria o canal nativo do Awake, que não
          // existe sob `flutter test`.
          sleepAssertionServiceProvider.overrideWithValue(
            FakeSleepAssertionService(),
          ),
          // E o histórico do Awake, pelo mesmo motivo: soltar a trava grava uma
          // linha, e o banco do aplicativo não existe sob `flutter test`.
          awakeSessionRepositoryProvider.overrideWithValue(
            FakeAwakeSessionRepository(),
          ),
          leafRepositoryProvider.overrideWithValue(notes),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          echoAudioStoreProvider.overrideWithValue(
            FakeEchoAudioStore(['alinhamento.m4a']),
          ),
          echoPlayerProvider.overrideWithValue(
            echoPlayer = FakeEchoPlayer(
              durationMs: const Duration(minutes: 32).inMilliseconds,
            ),
          ),
          echoRepositoryProvider.overrideWithValue(
            SqliteEchoRepository(echoDb),
          ),
          echoChannelProvider.overrideWithValue(channel),
          exportServiceProvider.overrideWithValue(FakeExportService()),
          nestChannelProvider.overrideWithValue(nestChannel),
          nestTransferRepositoryProvider.overrideWithValue(
            SqliteNestTransferRepository(echoDb),
          ),
          // O Track lê o mesmo banco: ele não tem tabela própria.
          trackRepositoryProvider.overrideWithValue(
            SqliteTrackRepository(echoDb),
          ),
          backupServiceProvider.overrideWithValue(backups),
          diskUsageServiceProvider.overrideWithValue(
            FakeDiskUsageService(
              const DiskUsage(
                database: 7340032,
                meetings: 8283750,
                backups: 5872025,
              ),
            ),
          ),
          if (fakeClock)
            clockProvider.overrideWithValue(() => tester.binding.clock.now())
          else if (now != null)
            clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: ColoredBox(
            color: EgTokens.evergreen().colors.canvas,
            child: home,
          ),
        ),
      ),
    );

    beforeSettle?.call();
    await tester.pumpAndSettle();
  }

  testWidgets('overlay do Pin — lista', (tester) async {
    await pump(
      tester,
      const PinOverlayView(),
      const Size(1120, 1000),
      beforeSettle: () => _loadHistory(tester),
    );

    await expectLater(
      find.byType(PinOverlayView),
      matchesGoldenFile('goldens/pin_overlay_list.png'),
    );
  });

  testWidgets('overlay do Pin — preview aberto', (tester) async {
    await pump(
      tester,
      const PinOverlayView(),
      const Size(1120, 1000),
      beforeSettle: () => _loadHistory(tester),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinOverlayView),
      matchesGoldenFile('goldens/pin_overlay_preview.png'),
    );
  });

  testWidgets('Hub — configurações do Pin', (tester) async {
    await pump(tester, const HubView(), _hubWindow);

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_pin_settings.png'),
    );
  });

  testWidgets('painel do Focus — partida', (tester) async {
    await pump(tester, const FocusOverlayView(), const Size(1120, 800));

    await expectLater(
      find.byType(FocusOverlayView),
      matchesGoldenFile('goldens/focus_overlay_idle.png'),
    );
  });

  testWidgets('painel do Focus — sessão em andamento', (tester) async {
    // Mais alta que a do painel parado: com o anel, o diário e o campo de
    // anotação, a sessão em andamento é a tela mais alta do módulo.
    await pump(
      tester,
      const FocusOverlayView(),
      const Size(1120, 1000),
      fakeClock: true,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FocusOverlayView)),
    );
    final viewModel = container.read(focusTimerViewModelProvider.notifier);
    viewModel.start(activity: 'Refatorar o módulo de auth');

    await tester.pump(const Duration(minutes: 3, seconds: 20));
    viewModel.addNote('terminei a task e comecei outra');

    await tester.pump(const Duration(minutes: 2, seconds: 27));
    // Tempo para o foco assentar no painel e a borda do campo terminar a
    // transição — senão o campo de anotação congela com a borda de foco que
    // ele não tem no uso real.
    await tester.pump(const Duration(milliseconds: 120));

    await expectLater(
      find.byType(FocusOverlayView),
      matchesGoldenFile('goldens/focus_overlay_running.png'),
    );

    container.read(focusTimerViewModelProvider.notifier).dismiss();
  });

  /// A sessão do histórico aberta na região de leitura.
  ///
  /// Larga pelo mesmo motivo da reunião do Echo: abrir uma sessão faz a
  /// **janela crescer** (`HubWindowChannel.setDetailWidth`), e sob `flutter
  /// test` não há janela nativa para crescer — o tamanho já entra aqui somado.
  /// Era um diálogo modal por cima da tela até a v0.4.
  testWidgets('Hub — Focus, a sessão aberta', (tester) async {
    await pump(tester, const HubView(), _hubWindowWithRegion);

    await tester.tap(find.text(EvergreenModule.focus.name));
    await tester.pumpAndSettle();

    // A tela abre em "Ajustes"; o histórico mora na outra aba.
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    // Na linha do histórico o título e o anúncio do que há dentro vivem num
    // parágrafo só, como o apelido do Pin — daí a busca por trecho.
    await tester.tap(find.textContaining('Refatorar o módulo de auth'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_focus_session.png'),
    );
  });

  testWidgets('Hub — preferências do aplicativo', (tester) async {
    // Alta: com o backup e a restauração a tela passou a ser a mais longa do
    // Hub, e a folha de conferência precisa mostrá-la inteira.
    await pump(
      tester,
      const HubView(),
      const Size(1800, 2400),
      now: backupToday,
    );

    await tester.tap(find.text('Aplicativo'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_app_settings.png'),
    );
  });

  testWidgets('Hub — Focus', (tester) async {
    await pump(tester, const HubView(), _hubWindow);

    await tester.tap(find.text(EvergreenModule.focus.name));
    await tester.pumpAndSettle();

    // A tela abre em "Ajustes"; o histórico mora na outra aba.
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_focus.png'),
    );
  });

  testWidgets('painel do Leaf — parede com anotações', (tester) async {
    await pump(tester, const LeafOverlayView(), const Size(1800, 1600));

    await expectLater(
      find.byType(LeafOverlayView),
      matchesGoldenFile('goldens/leaf_overlay_wall.png'),
    );
  });

  testWidgets('painel do Leaf — cartão em edição', (tester) async {
    await pump(tester, const LeafOverlayView(), const Size(1800, 1600));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LeafOverlayView)),
    );
    container.read(leafViewModelProvider.notifier).startNote();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Perguntar pro Rafa se o webhook novo já está em produção',
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LeafOverlayView),
      matchesGoldenFile('goldens/leaf_overlay_editing.png'),
    );
  });

  testWidgets('painel do Leaf — lembrete', (tester) async {
    await pump(tester, const LeafOverlayView(), const Size(1800, 1600));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LeafOverlayView)),
    );
    container.read(leafViewModelProvider.notifier).remindSlot(3);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sexta 14h');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LeafOverlayView),
      matchesGoldenFile('goldens/leaf_overlay_reminder.png'),
    );
  });

  testWidgets('Hub — Leaf', (tester) async {
    await pump(tester, const HubView(), _hubWindow);

    await tester.tap(find.text(EvergreenModule.leaf.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_leaf.png'),
    );
  });

  /// A janela do Hub com a região de leitura aberta.
  ///
  /// Larga porque é assim que ela fica no uso: abrir uma reunião faz a **janela
  /// crescer** (`HubWindowChannel.setDetailWidth`) em vez de espremer o que já
  /// estava na tela. Sob `flutter test` não há janela nativa para crescer, então
  /// o tamanho já entra aqui somado.
  Future<void> openReader(WidgetTester tester) async {
    await pump(tester, const HubView(), _hubWindowWithRegion);

    await tester.tap(find.text(EvergreenModule.echo.name));
    await tester.pumpAndSettle();

    // A tela abre em "Ajustes"; a lista mora na outra aba.
    await tester.tap(find.text('Reuniões'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Alinhamento de escopo'));
    await tester.pumpAndSettle();
  }

  testWidgets('Hub — Echo, a reunião aberta', (tester) async {
    await openReader(tester);

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_echo_reader.png'),
    );
  });

  testWidgets('Hub — Echo, a transcrição', (tester) async {
    await openReader(tester);

    // A aba que motivou o redesenho: empilhada sob o resumo, a transcrição
    // empurrava a lista de reuniões para fora da tela.
    await tester.tap(find.text('Transcrição'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_echo_transcript.png'),
    );
  });

  testWidgets('Hub — Echo, a transcrição tocando', (tester) async {
    await openReader(tester);
    await tester.tap(find.text('Transcrição'));
    await tester.pumpAndSettle();

    // No meio de "escopo": o player anda, a palavra acende, a barra avança.
    echoPlayer.positionMs = 6500;
    await tester.tap(find.byTooltip('Tocar (espaço)'));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_echo_playing.png'),
    );

    await tester.tap(find.byTooltip('Pausar (espaço)'));
    await tester.pumpAndSettle();
  });

  /// A busca de todas as reuniões, no lugar da lista.
  Future<void> searchMeetings(
    WidgetTester tester,
    String query, {
    Size window = _hubWindow,
  }) async {
    await pump(tester, const HubView(), window);

    await tester.tap(find.text(EvergreenModule.echo.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reuniões'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(EgSearchField),
        matching: find.byType(TextField),
      ),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Hub — Echo, buscando', (tester) async {
    // A proposta está no resumo e na fala: a folha mostra os dois tipos de
    // trecho, cada um com o grifo e quem o disse.
    await searchMeetings(tester, 'proposta');

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_echo_search.png'),
    );
  });

  testWidgets('Hub — Echo, o trecho achado', (tester) async {
    await searchMeetings(tester, 'proposta', window: _hubWindowWithRegion);

    // Do resumo para a fala, e Enter: a leitura abre na transcrição, com o
    // termo marcado sobre o fundo de "achado".
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_echo_search_open.png'),
    );
  });

  /// A prateleira com o que se junta num dia de trabalho: uma pasta, um
  /// documento e um vídeo, de origens diferentes, esperando o mesmo destino.
  testWidgets('painel do Nest — prateleira cheia', (tester) async {
    await preferences.setStringList('nest.destinations', [
      '{"path":"/Users/lucas/Documentos/Recibos","alias":""}',
      '{"path":"/Users/lucas/Clientes/Marina","alias":"Marina"}',
      '{"path":"/Users/lucas/Desktop/Triagem","alias":""}',
    ]);

    // Numa pasta com nome de gente, e com tamanhos de arquivo de verdade: este
    // print também é o do Nest na apresentação de boas-vindas, e o caminho
    // temporário do teste (`…/T/nest_golden…`) e "2 KB" denunciavam a fixture.
    final downloads = Directory(p.join(nestFiles.path, 'lucas', 'Downloads'))
      ..createSync(recursive: true);
    final paths = <String>[];
    for (final (name, bytes) in const [
      ('contrato-marina.pdf', 248000),
      ('reuniao-23-07.mov', 4800000),
      ('notas fiscais', 0),
    ]) {
      final path = p.join(downloads.path, name);
      if (name.contains('.')) {
        File(path).writeAsBytesSync(List.filled(bytes, 0));
      } else {
        Directory(path).createSync();
      }
      paths.add(path);
    }

    // Mais alta que a do painel vazio: cheia, a prateleira ganha a capa da
    // pilha em cima da fila e das pastas.
    await pump(tester, const NestOverlayView(), const Size(1120, 1040));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NestOverlayView)),
    );
    // `runAsync` porque encher a prateleira lê o disco de verdade — tamanho e
    // data de cada arquivo —, e o relógio falso do teste de widget não entrega
    // a resposta de uma leitura de arquivo.
    await tester.runAsync(
      () => container.read(nestViewModelProvider.notifier).addPaths(paths),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(NestOverlayView),
      matchesGoldenFile('goldens/nest_overlay_filled.png'),
    );
  });

  testWidgets('painel do Nest — vazia', (tester) async {
    await pump(tester, const NestOverlayView(), const Size(1120, 700));

    await expectLater(
      find.byType(NestOverlayView),
      matchesGoldenFile('goldens/nest_overlay_empty.png'),
    );
  });

  testWidgets('Hub — Nest', (tester) async {
    await preferences.setStringList('nest.destinations', [
      '{"path":"/Users/lucas/Documentos/Recibos","alias":""}',
      '{"path":"/Users/lucas/Clientes/Marina","alias":"Marina"}',
    ]);

    await pump(tester, const HubView(), _hubWindow);

    await tester.tap(find.text(EvergreenModule.nest.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_nest.png'),
    );
  });

  testWidgets('painel do Awake — desligado', (tester) async {
    await pump(tester, const AwakeOverlayView(), const Size(1120, 700));

    await expectLater(
      find.byType(AwakeOverlayView),
      matchesGoldenFile('goldens/awake_overlay_idle.png'),
    );
  });

  testWidgets('painel do Awake — trava ligada', (tester) async {
    await pump(
      tester,
      const AwakeOverlayView(),
      const Size(1120, 700),
      fakeClock: true,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AwakeOverlayView)),
    );
    final viewModel = container.read(awakeViewModelProvider.notifier);
    await viewModel.selectDuration(AwakeDuration.minutes30);
    await viewModel.turnOn();

    // Poucos minutos, e não uma hora: o ticker é de um segundo, e cada minuto
    // pulado aqui são sessenta callbacks executados de verdade pelo relógio
    // falso. O que a imagem precisa mostrar é a contagem correndo com um pedaço
    // do progresso preenchido — 4 minutos bastam para as duas coisas.
    await tester.pump(const Duration(minutes: 4, seconds: 12));
    // O botão e a pílula selecionada trocam de cor em 90ms. Sem este quadro a
    // imagem congela no meio da transição — botão ainda verde escrito
    // "Desligar", pílula do lado errado — e viraria um golden que não
    // corresponde a nenhum estado real do painel.
    await tester.pump(AppDurations.instant);

    await expectLater(
      find.byType(AwakeOverlayView),
      matchesGoldenFile('goldens/awake_overlay_running.png'),
    );

    // O golden não pode deixar o ticker vivo atrás de si.
    await viewModel.turnOff();
  });

  testWidgets('painel do Echo — parado', (tester) async {
    await pump(tester, const EchoOverlayView(), const Size(1120, 700));

    await expectLater(
      find.byType(EchoOverlayView),
      matchesGoldenFile('goldens/echo_overlay_idle.png'),
    );
  });

  testWidgets('painel do Echo — gravando', (tester) async {
    // Mais alta que a do painel parado: gravando, a tela ganha as duas faixas
    // de nível e a última fala reconhecida.
    await pump(
      tester,
      const EchoOverlayView(),
      const Size(1120, 820),
      fakeClock: true,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EchoOverlayView)),
    );
    // `initialize` é quem liga a escuta do nativo — sem ela o painel não
    // recebe nível nem texto ao vivo, que é metade do que esta tela mostra.
    await container.read(echoRecorderViewModelProvider.notifier).initialize();
    await container.read(echoRecorderViewModelProvider.notifier).start();
    await tester.pump(const Duration(minutes: 12, seconds: 30));

    // Um instante de reunião de verdade: você falando (energia nas graves e
    // médias da voz) por cima do fim da fala dos outros, mais fraca. O canal do
    // teste emite as bandas que o nativo mediria.
    channel.emitLevels(
      const [0.34, 0.62, 0.78, 0.55, 0.41, 0.33, 0.22, 0.14, 0.08, 0.04],
      const [0.18, 0.26, 0.31, 0.22, 0.17, 0.12, 0.09, 0.06, 0.03, 0.0],
    );
    channel.emitLive('então o painel pode ser caro de desenhar, a sidebar não');
    // Três quadros, e cada um faz uma coisa: o primeiro entrega o aviso do
    // canal ao estado, o segundo monta as barras na altura de repouso (é onde a
    // animação começa) e o terceiro deixa os 100 ms delas correrem. Parando no
    // segundo, o golden congela o equalizador no chão.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await expectLater(
      find.byType(EchoOverlayView),
      matchesGoldenFile('goldens/echo_overlay_recording.png'),
    );

    // O golden não pode deixar o ticker vivo atrás de si.
    await container.read(echoRecorderViewModelProvider.notifier).cancel();
  });

  testWidgets('Hub — Echo', (tester) async {
    await pump(tester, const HubView(), _hubWindow);

    await tester.tap(find.text(EvergreenModule.echo.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_echo.png'),
    );
  });

  testWidgets('Hub — Awake', (tester) async {
    await pump(tester, const HubView(), _hubWindow);

    await tester.tap(find.text(EvergreenModule.awake.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_awake.png'),
    );
  });

  testWidgets('Hub — Track', (tester) async {
    await pump(
      tester,
      const HubView(),
      const Size(1800, 1400),
      now: trackToday,
    );

    await tester.tap(find.text(EvergreenModule.track.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_track.png'),
    );
  });

  /// O dia aberto na região de leitura.
  ///
  /// Larga pelo mesmo motivo da reunião do Echo e da sessão do Focus: abrir um
  /// dia faz a **janela crescer** (`HubWindowChannel.setDetailWidth`), e sob
  /// `flutter test` não há janela nativa para crescer — o tamanho já entra aqui
  /// somado.
  testWidgets('Hub — Track, o dia aberto', (tester) async {
    await pump(
      tester,
      const HubView(),
      const Size(2720, 1400),
      now: trackToday,
    );

    await tester.tap(find.text(EvergreenModule.track.name));
    await tester.pumpAndSettle();

    // "Hoje" também é o nome de uma pílula do recorte — o `find` precisa dizer
    // que quer a linha da lista.
    await tester.tap(
      find.descendant(
        of: find.byType(TrackDayList),
        matching: find.text('Hoje'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_track_day.png'),
    );
  });
}

/// Enche as tabelas que o Track lê, na semana de [today].
///
/// Escreve direto em SQL, e não pelos repositórios dos outros módulos: o Track
/// não tem escrita própria, e o que a folha de conferência precisa é do dado
/// como ele fica no banco depois que Focus, Echo, Pin e Leaf passaram por ali.
///
/// A distribuição do dia é a do documento que originou o módulo — quarenta
/// itens copiados, nove deles links e seis comandos.
void seedTrack(Database db, DateTime today) {
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(today.year, today.month, today.day - daysAgo, hour, minute);

  void focus(DateTime startedAt, int minutes, [String? activity]) {
    db.execute(
      'INSERT INTO focus_sessions (started_at, duration_seconds, activity) '
      'VALUES (?, ?, ?);',
      [startedAt.millisecondsSinceEpoch, minutes * 60, activity],
    );
  }

  void meeting(DateTime startedAt, int minutes, String title) {
    db.execute(
      'INSERT INTO echo_meetings '
      '(title, started_at, duration_ms, language, transcript) '
      'VALUES (?, ?, ?, ?, ?);',
      [
        title,
        startedAt.millisecondsSinceEpoch,
        Duration(minutes: minutes).inMilliseconds,
        'pt-BR',
        '[]',
      ],
    );
  }

  void copies(DateTime day, ClipboardItemType type, int count) {
    for (var index = 0; index < count; index++) {
      db.execute(
        'INSERT INTO clipboard_items (content, type, is_pinned, copied_at) '
        'VALUES (?, ?, 0, ?);',
        [
          '${type.name}-${day.day}-$index',
          type.name,
          day.add(Duration(minutes: index)).millisecondsSinceEpoch,
        ],
      );
    }
  }

  void note(int slot, DateTime createdAt) {
    db.execute(
      'INSERT INTO leaf_notes (slot, content, created_at) VALUES (?, ?, ?);',
      [slot, 'anotação $slot', createdAt.millisecondsSinceEpoch],
    );
  }

  focus(at(0, 9, 12), 25, 'Refatorar o módulo de auth');
  focus(at(0, 11, 20), 40, 'Revisar a PR do Echo');
  focus(at(0, 15, 5), 50);
  focus(at(1, 9, 40), 50, 'Escrever a proposta');
  focus(at(1, 14, 10), 25, 'Ajustar o classificador do Pin');
  focus(at(2, 10, 15), 45, 'Corrigir o bug da janela');
  focus(at(3, 8, 50), 50, 'Planejar a semana');
  focus(at(3, 16, 0), 25, 'Responder e-mails');

  // A reunião de hoje já entrou no `setUp`, com transcrição — é a mesma que o
  // Echo mostra.
  meeting(at(2, 15, 0), 28, 'Retrospectiva da sprint');

  copies(at(0, 8, 30), ClipboardItemType.text, 22);
  copies(at(0, 10, 0), ClipboardItemType.link, 9);
  copies(at(0, 13, 0), ClipboardItemType.command, 6);
  copies(at(0, 14, 0), ClipboardItemType.email, 2);
  copies(at(0, 16, 0), ClipboardItemType.phone, 1);
  copies(at(1, 11, 0), ClipboardItemType.text, 12);
  copies(at(1, 12, 0), ClipboardItemType.link, 4);
  copies(at(3, 9, 0), ClipboardItemType.text, 7);

  note(1, at(0, 10, 40));
  note(2, at(0, 15, 55));
  note(3, at(1, 9, 10));
}

void _loadHistory(WidgetTester tester) {
  final element = tester.element(find.byType(PinOverlayView));
  ProviderScope.containerOf(
    element,
  ).read(pinOverlayViewModelProvider.notifier).load();
}

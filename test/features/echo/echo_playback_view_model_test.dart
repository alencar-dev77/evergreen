import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_library_view_model.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_playback_view_model.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/viewmodels/hub_detail_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_audio.dart';
import 'fake_echo_channel.dart';
import 'fake_export_service.dart';

/// O player da leitura: segue a reunião aberta, toca, salta e para.
void main() {
  late Database db;
  late SqliteEchoRepository repository;
  late FakeEchoPlayer player;
  late FakeEchoAudioStore store;
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    repository = SqliteEchoRepository(db);
    player = FakeEchoPlayer(durationMs: 60000);
    store = FakeEchoAudioStore(['com-audio.m4a']);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        echoRepositoryProvider.overrideWithValue(repository),
        echoChannelProvider.overrideWithValue(FakeEchoChannel()),
        echoAudioStoreProvider.overrideWithValue(store),
        echoPlayerProvider.overrideWithValue(player),
        exportServiceProvider.overrideWithValue(FakeExportService()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Meeting insert(String title, {String? audio, int minutesAgo = 0}) =>
      repository.insert(
        Meeting(
          title: title,
          startedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
          durationMs: 60000,
          language: TranscriptionLanguage.ptBR,
          segments: const [],
          audioFile: audio,
        ),
      );

  EchoPlaybackState state() => container.read(echoPlaybackViewModelProvider);
  EchoPlaybackViewModel viewModel() =>
      container.read(echoPlaybackViewModelProvider.notifier);

  /// Abre a biblioteca, liga o player e deixa as respostas assentarem.
  Future<void> open({int? select}) async {
    await container.read(echoLibraryViewModelProvider.notifier).load();
    if (select != null) {
      container.read(echoLibraryViewModelProvider.notifier).select(select);
    }
    state();
    await pumpEventQueue();
  }

  test('a reunião com áudio carrega o player', () async {
    final meeting = insert('com áudio', audio: 'com-audio.m4a');

    await open();

    expect(state().meetingId, meeting.id);
    expect(state().durationMs, 60000);
    expect(player.loaded, store.pathOf('com-audio.m4a'));
  });

  test(
    'reunião sem áudio, ou com o arquivo sumido, não oferece player',
    () async {
      insert('antiga');
      await open();
      expect(state().isReady, isFalse);

      store.files.clear();
      final gone = insert('sumiu', audio: 'com-audio.m4a', minutesAgo: -1);
      container.read(echoLibraryViewModelProvider.notifier).select(gone.id!);
      await pumpEventQueue();

      expect(state().isReady, isFalse);
    },
  );

  test('trocar de reunião troca o áudio', () async {
    store.files.add('outra.m4a');
    final first = insert('primeira', audio: 'com-audio.m4a', minutesAgo: 5);
    final second = insert('segunda', audio: 'outra.m4a');

    await open(select: first.id);
    expect(state().meetingId, first.id);

    container.read(echoLibraryViewModelProvider.notifier).select(second.id!);
    await pumpEventQueue();

    expect(state().meetingId, second.id);
    expect(player.loaded, store.pathOf('outra.m4a'));
    expect(player.calls, contains('unload'));
  });

  test('tocar, saltar e pausar', () async {
    insert('com áudio', audio: 'com-audio.m4a');
    await open();

    await viewModel().toggle();
    expect(state().isPlaying, isTrue);

    await viewModel().skipBy(const Duration(seconds: 10));
    expect(player.positionMs, 10000);

    await viewModel().skipBy(const Duration(seconds: -30));
    expect(player.positionMs, 0, reason: 'não salta para antes do começo');

    await viewModel().seekTo(999999);
    expect(player.positionMs, 60000, reason: 'nem para depois do fim');

    await viewModel().toggle();
    expect(state().isPlaying, isFalse);
    expect(player.isPlaying, isFalse);
  });

  test('rolar à mão para de seguir; saltar volta a seguir', () async {
    insert('com áudio', audio: 'com-audio.m4a');
    await open();

    viewModel().stopFollowing();
    expect(state().isFollowing, isFalse);

    await viewModel().seekTo(5000);
    expect(state().isFollowing, isTrue);
  });

  test('a velocidade gira e acompanha a troca de reunião', () async {
    store.files.add('outra.m4a');
    final first = insert('primeira', audio: 'com-audio.m4a', minutesAgo: 5);
    final second = insert('segunda', audio: 'outra.m4a');

    await open(select: first.id);
    expect(state().rate, 1.0);

    await viewModel().cycleRate();
    await viewModel().cycleRate();
    expect(state().rate, 1.5);
    expect(player.rate, 1.5);

    // O arquivo novo nasce no normal: a velocidade da sessão vai junto.
    player.rate = 1;
    container.read(echoLibraryViewModelProvider.notifier).select(second.id!);
    await pumpEventQueue();

    expect(state().meetingId, second.id);
    expect(state().rate, 1.5);
    expect(player.rate, 1.5);

    await viewModel().cycleRate();
    await viewModel().cycleRate();
    expect(state().rate, 1.0);
  });

  test('fechar a leitura pausa o áudio', () async {
    insert('com áudio', audio: 'com-audio.m4a');
    await open();
    container.read(hubDetailProvider.notifier).open(EvergreenModule.echo);

    await viewModel().play();
    container.read(hubDetailProvider.notifier).close();
    await pumpEventQueue();

    expect(state().isPlaying, isFalse);
    expect(player.isPlaying, isFalse);
  });
}

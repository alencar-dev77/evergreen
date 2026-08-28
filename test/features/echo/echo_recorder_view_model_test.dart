import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_state.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';

void main() {
  late Database db;
  late FakeEchoChannel channel;
  late SharedPreferences preferences;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);

    channel = FakeEchoChannel(
      segments: const [
        MeetingSegment(
          speaker: Speaker.me,
          startMs: 0,
          endMs: 1000,
          text: 'oi',
        ),
        MeetingSegment(
          speaker: Speaker.others,
          startMs: 1200,
          endMs: 3000,
          text: 'vamos fechar o escopo',
        ),
      ],
    );

    container = ProviderContainer(
      overrides: [
        echoChannelProvider.overrideWithValue(channel),
        sharedPreferencesProvider.overrideWithValue(preferences),
        echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
        clockProvider.overrideWithValue(DateTime.now),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  EchoRecorderViewModel viewModel() =>
      container.read(echoRecorderViewModelProvider.notifier);

  EchoRecorderState state() => container.read(echoRecorderViewModelProvider);

  test('gravar leva o painel para o estado de gravação', () async {
    await viewModel().prepareForOpen();
    await viewModel().start();

    expect(channel.didStart, isTrue);
    expect(state().phase, EchoPhase.recording);
  });

  test(
    'o vocabulário das preferências chega ao gravar e ao transcrever',
    () async {
      // As duas pontas, e não só uma: gravar leva a lista para a transcrição ao
      // vivo, transcrever leva para a do arquivo — que é a que vira a reunião.
      await preferences.setString('echo.vocabulary', 'Riverpod, Diletta');

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      expect(channel.startedWithVocabulary, ['Riverpod', 'Diletta']);
      expect(channel.transcribedWithVocabulary, ['Riverpod', 'Diletta']);
    },
  );

  test('parar transcreve, guarda e só então apaga o áudio', () async {
    await viewModel().start();
    await viewModel().stopAndTranscribe();

    expect(state().phase, EchoPhase.done);

    final meeting = state().lastMeeting!;
    expect(meeting.id, isNotNull);
    expect(meeting.segments, hasLength(2));
    expect(meeting.durationMs, 90000);

    // A ordem é a regra: o áudio só é apagado depois de a transcrição estar no
    // banco, e as duas faixas vão juntas.
    expect(channel.deletedAudio, ['/tmp/mic.caf', '/tmp/sistema.caf']);
    expect(SqliteEchoRepository(db).loadAll(), hasLength(1));
  });

  test('transcrição que falha preserva o áudio e explica', () async {
    await viewModel().start();
    channel.failWith = const EchoException('transcription_failed', 'Deu ruim.');

    await viewModel().stopAndTranscribe();

    expect(state().phase, EchoPhase.failed);
    expect(state().errorMessage, contains('áudio foi preservado'));
    expect(channel.deletedAudio, isEmpty);
    expect(SqliteEchoRepository(db).loadAll(), isEmpty);
  });

  test('desistir joga o áudio fora e não guarda reunião', () async {
    await viewModel().start();
    await viewModel().cancel();

    expect(channel.didCancel, isTrue);
    expect(state().phase, EchoPhase.idle);
    expect(SqliteEchoRepository(db).loadAll(), isEmpty);
  });

  test('sem permissão, o painel não deixa gravar', () async {
    channel.capabilitiesValue = const EchoCapabilities(
      microphone: PermissionStatus.notDetermined,
      screenRecording: PermissionStatus.notDetermined,
    );

    await viewModel().prepareForOpen();

    expect(state().capabilities.canRecord, isFalse);
  });

  test('as duas permissões são pedidas em separado', () async {
    // Uma pode estar concedida enquanto a outra não, e cada uma é pedida por
    // uma API diferente — um pedido único não teria como resolver as duas.
    channel.capabilitiesValue = const EchoCapabilities(
      microphone: PermissionStatus.notDetermined,
      screenRecording: PermissionStatus.denied,
    );
    await viewModel().prepareForOpen();

    await viewModel().requestMicrophone();
    expect(channel.requested, ['microphone']);
    expect(state().capabilities.microphone, PermissionStatus.granted);
    expect(state().capabilities.canRecord, isFalse);

    await viewModel().requestScreenRecording();
    expect(channel.requested, ['microphone', 'screenRecording']);
    expect(state().capabilities.canRecord, isTrue);
  });

  test('permissão negada muda o verbo do botão para os Ajustes', () {
    // Depois de um "não", pedir de novo não abre diálogo nenhum — o único
    // caminho é os Ajustes, e o botão precisa dizer isso.
    expect(PermissionStatus.notDetermined.actionLabel, 'Permitir');
    expect(PermissionStatus.denied.actionLabel, 'Abrir Ajustes');
  });

  test('a barra de menus só mostra a contagem enquanto grava', () async {
    expect(state().menuBarLabel, isNull);

    await viewModel().start();
    expect(state().menuBarLabel, '00:00');

    await viewModel().stopAndTranscribe();
    expect(state().menuBarLabel, isNull);
  });

  test('a gravação nasce sem transcrição ao vivo', () async {
    // O padrão é desligado, e de propósito: transcrever ao vivo custa
    // processador exatamente enquanto a chamada de vídeo já está consumindo a
    // máquina.
    await viewModel().start();

    expect(channel.startedWithLiveTranscription, isFalse);
    expect(channel.startedWithLocale, 'pt-BR');
  });

  test('a transcrição ao vivo ligada chega ao canal', () async {
    // As preferências são editadas no Hub, que roda em outro engine — daí o
    // `reload` antes de gravar. Sem ele a gravação sairia no modo de ontem, e
    // nada no Dart denunciaria: o ao vivo simplesmente não aconteceria.
    await preferences.setBool('echo.liveTranscription', true);
    await preferences.setString('echo.language', 'en-US');

    await viewModel().start();

    expect(channel.startedWithLiveTranscription, isTrue);
    expect(channel.startedWithLocale, 'en-US');
  });

  test('o texto ao vivo não passa dos últimos trechos', () async {
    // É o `initialize` que assina o canal — sem ele, não há transcrição ao vivo
    // chegando de lugar nenhum.
    await viewModel().initialize();
    await viewModel().start();

    for (var i = 0; i < 10; i++) {
      channel.emitLive('trecho $i');
      await Future<void>.delayed(Duration.zero);
    }

    expect(state().liveText, hasLength(6));
    expect(state().liveText.last, 'trecho 9');
  });
}

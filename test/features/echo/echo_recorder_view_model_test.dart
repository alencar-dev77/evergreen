import 'dart:async';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/voice_separation.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_state.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';
import 'fake_echo_audio.dart';

void main() {
  late Database db;
  late FakeEchoChannel channel;
  late SharedPreferences preferences;
  late ProviderContainer container;
  late FakeEchoAudioStore audio;

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
        echoAudioStoreProvider.overrideWithValue(audio = FakeEchoAudioStore()),
        echoPlayerProvider.overrideWithValue(FakeEchoPlayer()),
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

  test('o equalizador mostra a medida do instante, não a fila delas', () async {
    await viewModel().initialize();
    await viewModel().start();

    channel.emitLevels(const [0.1, 0.2], const [0.3, 0.4]);
    await Future<void>.delayed(Duration.zero);
    channel.emitLevels(const [0.7, 0.8], const [0.9, 1.0]);
    await Future<void>.delayed(Duration.zero);

    // A anterior não fica guardada: o painel responde "agora", e uma fila de
    // instantes seria a fita passando que o equalizador substituiu.
    expect(state().spectrum?.mic, const [0.7, 0.8]);
    expect(state().spectrum?.system, const [0.9, 1.0]);
  });

  group('vozes da reunião', () {
    const conversa = [
      MeetingSegment(
        speaker: Speaker.others,
        startMs: 0,
        endMs: 2000,
        text: 'quem fica com a proposta?',
      ),
      MeetingSegment(
        speaker: Speaker.me,
        startMs: 2500,
        endMs: 3500,
        text: 'eu posso',
      ),
      MeetingSegment(
        speaker: Speaker.others,
        startMs: 4000,
        endMs: 6000,
        text: 'então até sexta',
      ),
    ];

    const duasVozes = [
      VoiceTurn(voice: 'S1', startMs: 0, endMs: 2000),
      VoiceTurn(voice: 'S2', startMs: 4000, endMs: 6000),
    ];

    test('separa o outro lado e guarda a voz no banco', () async {
      channel
        ..segments = conversa
        ..voiceTurns = duasVozes;

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      // Só a faixa do computador vai para a diarização.
      expect(channel.diarizedPath, '/tmp/sistema.caf');

      final stored = SqliteEchoRepository(
        db,
      ).findById(state().lastMeeting!.id!)!;
      expect(stored.segments.map((segment) => segment.voice), [1, null, 2]);
      expect(stored.segments.map((segment) => segment.labelFor('Lucas')), [
        'Pessoa 1',
        'Lucas',
        'Pessoa 2',
      ]);
      expect(state().isSeparatingVoices, isFalse);
    });

    test('o painel diz que está separando, e só enquanto separa', () async {
      // Na primeira reunião a etapa baixa o modelo: sem dizer o que está
      // acontecendo, o "Transcrevendo" parado um minuto a mais parece travado.
      final gate = Completer<void>();
      channel
        ..segments = conversa
        ..voiceTurns = duasVozes
        ..diarizeGate = gate;

      await viewModel().start();
      final stopping = viewModel().stopAndTranscribe();
      await pumpEventQueue();

      expect(state().phase, EchoPhase.transcribing);
      expect(state().isSeparatingVoices, isTrue);

      gate.complete();
      await stopping;

      expect(state().phase, EchoPhase.done);
      expect(state().isSeparatingVoices, isFalse);
    });

    test('a separação que falha não derruba a reunião nem avisa', () async {
      // Sem rede na primeira vez, o modelo não baixa — e a reunião é
      // guardada como sempre foi, com o outro lado inteiro em "Reunião".
      channel
        ..segments = conversa
        ..diarizeFailWith = const EchoException(
          'diarization_failed',
          'Sem rede.',
        );

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      expect(state().phase, EchoPhase.done);
      expect(state().errorMessage, isNull);
      expect(state().isSeparatingVoices, isFalse);
      expect(state().lastMeeting!.segments, hasLength(3));
      expect(state().lastMeeting!.voiceCount, 0);
      expect(channel.deletedAudio, isNotEmpty);
    });

    test('a separação que não responde não prende a reunião', () {
      // Rede lenta no primeiro download: o modelo pode levar minutos, e a
      // reunião sai sem vozes em vez de ficar em "Transcrevendo".
      fakeAsync((async) {
        channel
          ..segments = conversa
          ..voiceTurns = duasVozes
          ..diarizeGate = Completer<void>();

        viewModel().start();
        async.flushMicrotasks();
        viewModel().stopAndTranscribe();
        async.elapse(const Duration(minutes: 2));
        expect(state().phase, EchoPhase.transcribing);

        async.elapse(const Duration(minutes: 2));
        expect(state().phase, EchoPhase.done);
        expect(state().isSeparatingVoices, isFalse);
        expect(state().lastMeeting!.voiceCount, 0);
      });
    });

    test('sem fala do outro lado, nem pergunta', () async {
      channel.segments = const [
        MeetingSegment(
          speaker: Speaker.me,
          startMs: 0,
          endMs: 1000,
          text: 'anotação sozinho',
        ),
      ];

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      expect(channel.diarizedPath, isNull);
    });

    test('o vocabulário corrige depois de a voz ser decidida', () async {
      // A troca reescreve o trecho inteiro — e não pode levar a voz junto.
      await preferences.setString('echo.vocabulary', 'proposta -> Proposta');
      channel
        ..segments = conversa
        ..voiceTurns = duasVozes;

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      final first = state().lastMeeting!.segments.first;
      expect(first.text, 'quem fica com a Proposta?');
      expect(first.voice, 1);
    });
  });

  group('pausar', () {
    test('suspende a captura e zera o medidor', () async {
      await viewModel().initialize();
      await viewModel().start();

      channel.emitLevels(const [0.4, 0.4], const [0.4, 0.4]);
      await Future<void>.delayed(Duration.zero);
      expect(state().spectrum, isNotNull);

      await viewModel().pause();

      expect(channel.didPause, isTrue);
      expect(state().isPaused, isTrue);
      expect(state().isRecording, isTrue, reason: 'pausada, não encerrada');
      expect(state().isCapturing, isFalse);
      // Parado não tem o que medir: barras congeladas diriam que ainda entra
      // som.
      expect(state().spectrum, isNull);
    });

    test('pausada, a medida que chega é ignorada', () async {
      await viewModel().initialize();
      await viewModel().start();
      await viewModel().pause();

      channel.emitLevels(const [0.9, 0.9], const [0.9, 0.9]);
      await Future<void>.delayed(Duration.zero);

      expect(state().spectrum, isNull);
    });

    test('retomar volta a capturar', () async {
      await viewModel().initialize();
      await viewModel().start();
      await viewModel().pause();
      await viewModel().resume();

      expect(channel.didResume, isTrue);
      expect(state().isPaused, isFalse);
      expect(state().isCapturing, isTrue);
    });

    test('não pausa o que não está gravando', () async {
      await viewModel().pause();

      expect(channel.didPause, isFalse);
      expect(state().isPaused, isFalse);
    });
  });

  group('áudio para ouvir', () {
    test(
      'a reunião guarda a cópia comprimida e solta as faixas cruas',
      () async {
        channel.onArchive = (destination) =>
            audio.files.add(destination.split('/').last);

        await viewModel().start();
        await viewModel().stopAndTranscribe();

        final meeting = state().lastMeeting!;
        expect(meeting.audioFile, startsWith('reuniao-'));
        expect(meeting.audioFile, endsWith('.m4a'));
        expect(channel.archivedTo, audio.pathOf(meeting.audioFile!));
        expect(channel.deletedAudio, ['/tmp/mic.caf', '/tmp/sistema.caf']);

        // E o nome foi para o banco, não só para o estado.
        final stored = SqliteEchoRepository(db).findById(meeting.id!);
        expect(stored!.audioFile, meeting.audioFile);
      },
    );

    test('a cópia que falha não derruba a reunião', () async {
      channel.failArchive = true;

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      expect(state().phase, EchoPhase.done);
      expect(state().lastMeeting!.hasAudio, isFalse);
      expect(channel.deletedAudio, isNotEmpty);
    });

    test('sem fala reconhecida, nada é guardado para ouvir', () async {
      channel.segments = const [];

      await viewModel().start();
      await viewModel().stopAndTranscribe();

      expect(channel.archivedTo, isNull);
      expect(channel.deletedAudio, isEmpty);
    });
  });
}

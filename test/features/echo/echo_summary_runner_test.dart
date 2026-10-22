import 'dart:async';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/data/echo_summary_runner.dart';
import 'package:evergreen/features/echo/models/echo_settings.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_library_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/local_model/fake_lm_studio_http.dart';
import 'fake_echo_channel.dart';
import 'fake_export_service.dart';
import 'fake_echo_audio.dart';

/// O resumo que não pode morrer junto com a janela.
///
/// O Hub é uma sub-janela: fechá-la destrói o engine dela e tudo o que estava
/// pendente ali dentro. Enquanto o resumo era feito pela ViewModel do Hub,
/// pedir "Resumir" e sair da janela cancelava o trabalho em silêncio — a
/// reunião reaparecia sem resumo, sem erro e sem nada dizendo o que houve.
///
/// Por isso quem faz o trabalho é o [LocalEchoSummaryRunner], que vive no
/// engine da janela flutuante, junto do cronômetro do Focus e da captura do
/// Pin. O que estes testes prendem é essa separação: o container do Hub é
/// **descartado no meio do resumo**, e o resumo continua até o banco.
void main() {
  late Database db;
  late SharedPreferences preferences;
  late EchoRepository repository;
  late FakeEchoChannel channel;
  late ProviderContainer background;
  late int meetingId;

  /// O engine da janela 0: é dele que sai o runner que faz o trabalho.
  ProviderContainer openBackground({List<Override> extra = const []}) {
    final container = ProviderContainer(
      overrides: [
        ...extra,
        sharedPreferencesProvider.overrideWithValue(preferences),
        echoAudioStoreProvider.overrideWithValue(FakeEchoAudioStore()),
        echoPlayerProvider.overrideWithValue(FakeEchoPlayer()),
        echoRepositoryProvider.overrideWithValue(repository),
        echoChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Uma abertura do Hub. O runner vem de fora, como na vida real vem pelo
  /// canal entre janelas — o Hub nunca tem o seu.
  ProviderContainer openHub() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        echoAudioStoreProvider.overrideWithValue(FakeEchoAudioStore()),
        echoPlayerProvider.overrideWithValue(FakeEchoPlayer()),
        echoRepositoryProvider.overrideWithValue(repository),
        echoChannelProvider.overrideWithValue(channel),
        echoSummaryRunnerProvider.overrideWithValue(
          background.read(echoSummaryRunnerProvider),
        ),
        exportServiceProvider.overrideWithValue(FakeExportService()),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    repository = SqliteEchoRepository(db);

    meetingId = repository
        .insert(
          Meeting(
            title: 'Alinhamento de escopo',
            startedAt: DateTime(2026, 8, 20, 15, 30),
            durationMs: const Duration(minutes: 32).inMilliseconds,
            language: TranscriptionLanguage.ptBR,
            segments: const [
              MeetingSegment(
                speaker: Speaker.others,
                startMs: 4000,
                endMs: 9000,
                text: 'A ideia é fechar o escopo hoje.',
              ),
              MeetingSegment(
                speaker: Speaker.me,
                startMs: 9000,
                endMs: 12000,
                text: 'Fechado, eu levo isso para a sprint.',
              ),
            ],
          ),
        )
        .id!;

    channel = FakeEchoChannel()..summaryValue = '- escopo fechado';
    background = openBackground();
  });

  tearDown(() => db.close());

  test(
    'o resumo chega ao banco mesmo com o Hub fechado no meio dele',
    () async {
      final gate = Completer<void>();
      channel.summaryGate = gate;

      final hub = openHub();
      final library = hub.read(echoLibraryViewModelProvider.notifier);

      await library.load();
      await library.summarize(meetingId);

      expect(
        hub.read(echoLibraryViewModelProvider).summarizingId,
        meetingId,
        reason: 'a tela precisa dizer que o trabalho começou',
      );
      expect(repository.findById(meetingId)!.hasSummary, isFalse);

      // A janela é fechada com o modelo ainda escrevendo. É aqui que o bug
      // acontecia: com o engine do Hub, ia embora o resumo inteiro.
      hub.dispose();

      gate.complete();
      await pumpEventQueue();

      final saved = repository.findById(meetingId)!;
      expect(saved.summary, '- escopo fechado');
      expect(saved.hasSummaryPrompt, isTrue);
    },
  );

  test('o Hub reaberto encontra o resumo que terminou sem ele', () async {
    final gate = Completer<void>();
    channel.summaryGate = gate;

    final first = openHub();
    await first.read(echoLibraryViewModelProvider.notifier).load();
    await first
        .read(echoLibraryViewModelProvider.notifier)
        .summarize(meetingId);
    first.dispose();

    gate.complete();
    await pumpEventQueue();

    final second = openHub();
    addTearDown(second.dispose);
    await second.read(echoLibraryViewModelProvider.notifier).load();

    final state = second.read(echoLibraryViewModelProvider);
    expect(state.summarizingId, isNull);
    expect(state.selected!.summary, '- escopo fechado');
  });

  test(
    'o Hub aberto no meio do trabalho reencontra o resumo em curso',
    () async {
      final gate = Completer<void>();
      channel.summaryGate = gate;

      // Pedido feito por uma abertura anterior do Hub, que já foi embora.
      final first = openHub();
      await first.read(echoLibraryViewModelProvider.notifier).load();
      await first
          .read(echoLibraryViewModelProvider.notifier)
          .summarize(meetingId);
      first.dispose();

      final second = openHub();
      addTearDown(second.dispose);
      await second.read(echoLibraryViewModelProvider.notifier).load();

      expect(
        second.read(echoLibraryViewModelProvider).summarizingId,
        meetingId,
        reason:
            'quem reabre a janela precisa ver que ainda há resumo acontecendo',
      );

      gate.complete();
      await pumpEventQueue();
    },
  );

  test('a instrução gravada é a que o modelo recebeu', () async {
    await preferences.setString('echo.summaryInstructions', 'Um parágrafo só.');

    final hub = openHub();
    addTearDown(hub.dispose);

    await hub.read(echoLibraryViewModelProvider.notifier).load();
    await hub.read(echoLibraryViewModelProvider.notifier).summarize(meetingId);
    await pumpEventQueue();

    expect(
      channel.summarizedInstructions.single,
      startsWith('Um parágrafo só.'),
    );
    // Gravada é só a da pessoa: as regras do aplicativo vão ao modelo, mas a
    // tela mostra esta para ser copiada de volta às preferências.
    expect(repository.findById(meetingId)!.summaryPrompt, 'Um parágrafo só.');
  });

  test(
    'sem instrução escrita, o que fica gravado é a padrão do aplicativo',
    () async {
      final hub = openHub();
      addTearDown(hub.dispose);

      await hub.read(echoLibraryViewModelProvider.notifier).load();
      await hub
          .read(echoLibraryViewModelProvider.notifier)
          .summarize(meetingId);
      await pumpEventQueue();

      // Explícita no caminho, e não "manda vazio e deixa o Swift escolher": só
      // assim dá para gravar a frase que o modelo de fato leu.
      expect(
        channel.summarizedInstructions.single,
        startsWith(EchoSettings.defaultInstructions),
      );
      expect(
        repository.findById(meetingId)!.summaryPrompt,
        EchoSettings.defaultInstructions,
      );
    },
  );

  test('dois pedidos seguidos não viram dois resumos', () async {
    final gate = Completer<void>();
    channel.summaryGate = gate;

    final runner = background.read(echoSummaryRunnerProvider);
    await runner.start(meetingId);
    await runner.start(meetingId);

    gate.complete();
    await pumpEventQueue();

    expect(channel.summarizedTexts, hasLength(1));
  });

  /// O tamanho do bloco vem da janela do modelo, não de um número escrito para
  /// a janela antiga. No macOS 27 ela dobrou, e é isso que faz uma reunião
  /// longa deixar de passar por um resumo de resumos.
  group('o bloco segue a janela do modelo', () {
    late int longMeetingId;

    setUp(() {
      // Uns 9 mil caracteres: passa do teto da janela de 4.096, cabe na de
      // 8.192.
      longMeetingId = repository
          .insert(
            Meeting(
              title: 'Planejamento do trimestre',
              startedAt: DateTime(2026, 9, 30, 10),
              durationMs: const Duration(minutes: 40).inMilliseconds,
              language: TranscriptionLanguage.ptBR,
              segments: [
                for (var i = 0; i < 120; i++)
                  MeetingSegment(
                    speaker: i.isEven ? Speaker.others : Speaker.me,
                    startMs: i * 1000,
                    endMs: i * 1000 + 900,
                    text: 'Fala $i sobre o roadmap e as metas do trimestre.',
                  ),
              ],
            ),
          )
          .id!;
    });

    test('sem saber a janela, a reunião longa vai em blocos', () async {
      await background.read(echoSummaryRunnerProvider).start(longMeetingId);
      await pumpEventQueue();

      // Os blocos e mais o passo final que junta os resumos deles.
      expect(channel.summarizedTexts.length, greaterThan(2));
    });

    test('com a janela do macOS 27, ela cabe de uma vez', () async {
      channel.contextSizeValue = 8192;

      await background.read(echoSummaryRunnerProvider).start(longMeetingId);
      await pumpEventQueue();

      expect(channel.summarizedTexts, hasLength(1));
      expect(repository.findById(longMeetingId)!.hasSummary, isTrue);
      expect(
        repository.findById(longMeetingId)!.summaryModel,
        'Apple Intelligence',
      );
    });

    test(
      'com o LM Studio, a reunião vai inteira e o modelo sai da memória',
      () async {
        await preferences.setString('app.local_model_source', 'lm_studio');
        await preferences.setString('app.local_model_id', 'qwen3.5-4b-mlx');
        await preferences.setString('app.local_model_name', 'Qwen3.5 4B');
        final http = FakeLmStudioHttp();
        final lmStudio = openBackground(
          extra: [lmStudioHttpProvider.overrideWithValue(http)],
        );

        await lmStudio.read(echoSummaryRunnerProvider).start(longMeetingId);
        await pumpEventQueue();

        // Um bloco só nos 32k, nenhum pelo canal do Apple Intelligence.
        expect(http.chats, hasLength(1));
        expect(channel.summarizedTexts, isEmpty);
        expect(http.chats.single['max_output_tokens'], 1500);

        final meeting = repository.findById(longMeetingId)!;
        expect(meeting.summary, 'resumo');
        expect(meeting.summaryModel, 'Qwen3.5 4B');
        expect(http.loads, 1);
        expect(http.loaded, isEmpty);
      },
    );

    test('com o servidor desligado, "Resumir" mostra o erro', () async {
      await preferences.setString('app.local_model_source', 'lm_studio');
      await preferences.setString('app.local_model_id', 'qwen3.5-4b-mlx');
      final http = FakeLmStudioHttp()..offline = true;
      final lmStudio = openBackground(
        extra: [lmStudioHttpProvider.overrideWithValue(http)],
      );
      final runner = lmStudio.read(echoSummaryRunnerProvider);

      await runner.start(longMeetingId);
      await pumpEventQueue();

      expect(
        (await runner.status()).errorMessage,
        'O servidor do LM Studio está desligado.',
      );
      expect(channel.summarizedTexts, isEmpty);
      expect(repository.findById(longMeetingId)!.hasSummary, isFalse);
    });
  });

  test('a falha do modelo fica guardada até alguém abrir a janela', () async {
    channel.failWith = const EchoException(
      'summary_failed',
      'o modelo recusou',
    );

    final runner = background.read(echoSummaryRunnerProvider);
    await runner.start(meetingId);
    await pumpEventQueue();

    final hub = openHub();
    addTearDown(hub.dispose);
    await hub.read(echoLibraryViewModelProvider.notifier).load();

    expect(
      hub.read(echoLibraryViewModelProvider).errorMessage,
      'o modelo recusou',
    );
    expect(repository.findById(meetingId)!.hasSummary, isFalse);

    // Contada uma vez, e só. Guardá-la faria a mesma falha reaparecer em toda
    // abertura da tela, por um resumo que a pessoa já leu e já esqueceu.
    final later = openHub();
    addTearDown(later.dispose);
    await later.read(echoLibraryViewModelProvider.notifier).load();

    expect(later.read(echoLibraryViewModelProvider).errorMessage, isNull);
  });

  /// O modelo não sabe quem é quem: o rótulo da transcrição é a única pista, e
  /// a instrução é o que diz que aquele nome é de quem está pedindo o resumo.
  group('o nome de quem pediu', () {
    test('sem nome, nada muda no que vai para o modelo', () async {
      await background.read(echoSummaryRunnerProvider).start(meetingId);
      await pumpEventQueue();

      expect(channel.summarizedTexts.single, contains('Você: Fechado'));
      expect(
        channel.summarizedInstructions.single,
        isNot(contains('pediu este resumo')),
      );
    });

    test('quem não falou não é apresentado ao modelo', () async {
      // O caso que pedia a regra: um vídeo assistido em silêncio. Só a faixa
      // do computador tem fala, e apresentar o nome faria dele o dono de tudo.
      await preferences.setString('app.user_name', 'Lucas');
      final videoId = repository
          .insert(
            Meeting(
              title: 'Entrevista no YouTube',
              startedAt: DateTime(2026, 10, 1, 22, 26),
              durationMs: const Duration(minutes: 3).inMilliseconds,
              language: TranscriptionLanguage.ptBR,
              segments: const [
                MeetingSegment(
                  speaker: Speaker.others,
                  startMs: 0,
                  endMs: 5000,
                  text: 'Eu não conheço a Roberta.',
                ),
              ],
            ),
          )
          .id!;

      await background.read(echoSummaryRunnerProvider).start(videoId);
      await pumpEventQueue();

      final instructions = channel.summarizedInstructions.single;
      expect(instructions, isNot(contains('Lucas')));
      expect(instructions, contains('não as atribua a ninguém'));
    });

    test('a regra de quem disse o quê vai também nos blocos', () async {
      // É no bloco que "Reunião: eu não conheço a Roberta" vira "fulano
      // afirma…" — e o passo final só lê o que o bloco escreveu.
      channel.contextSizeValue = null;
      final longId = repository
          .insert(
            Meeting(
              title: 'Longa',
              startedAt: DateTime(2026, 10, 1, 9),
              durationMs: const Duration(minutes: 40).inMilliseconds,
              language: TranscriptionLanguage.ptBR,
              segments: [
                for (var i = 0; i < 120; i++)
                  MeetingSegment(
                    speaker: Speaker.others,
                    startMs: i * 1000,
                    endMs: i * 1000 + 900,
                    text: 'Fala $i sobre o roadmap e as metas do trimestre.',
                  ),
              ],
            ),
          )
          .id!;

      await background.read(echoSummaryRunnerProvider).start(longId);
      await pumpEventQueue();

      expect(channel.summarizedInstructions.length, greaterThan(2));
      for (final instructions in channel.summarizedInstructions) {
        expect(instructions, contains('não as atribua a ninguém'));
      }
    });

    test(
      'as vozes separadas chegam numeradas, e a regra diz o que são',
      () async {
        final voicesId = repository
            .insert(
              Meeting(
                title: 'Planejamento',
                startedAt: DateTime(2026, 10, 2, 14),
                durationMs: const Duration(minutes: 5).inMilliseconds,
                language: TranscriptionLanguage.ptBR,
                segments: const [
                  MeetingSegment(
                    speaker: Speaker.others,
                    startMs: 0,
                    endMs: 3000,
                    text: 'Quem fica com o relatório?',
                    voice: 1,
                  ),
                  MeetingSegment(
                    speaker: Speaker.others,
                    startMs: 3000,
                    endMs: 6000,
                    text: 'Eu fico.',
                    voice: 2,
                  ),
                ],
              ),
            )
            .id!;

        await background.read(echoSummaryRunnerProvider).start(voicesId);
        await pumpEventQueue();

        expect(
          channel.summarizedTexts.single,
          'Pessoa 1: Quem fica com o relatório?\nPessoa 2: Eu fico.',
        );
        final instructions = channel.summarizedInstructions.single;
        expect(instructions, contains('são 2 vozes diferentes'));
        expect(instructions, contains('O número não é nome'));
        // No lugar da regra sem vozes, e não ao lado: as duas se contradiziam.
        expect(instructions, isNot(contains('não as atribua a ninguém')));
      },
    );

    test('as vozes chegam a cada bloco, numeradas da mesma forma', () async {
      // O bloco é onde "Pessoa 2 fica com o relatório" vira "alguém fica com
      // o relatório" — o passo final só lê o que o bloco escreveu.
      channel.contextSizeValue = null;
      final longId = repository
          .insert(
            Meeting(
              title: 'Longa com vozes',
              startedAt: DateTime(2026, 10, 2, 9),
              durationMs: const Duration(minutes: 40).inMilliseconds,
              language: TranscriptionLanguage.ptBR,
              segments: [
                for (var i = 0; i < 120; i++)
                  MeetingSegment(
                    speaker: Speaker.others,
                    startMs: i * 1000,
                    endMs: i * 1000 + 900,
                    text: 'Fala $i sobre o roadmap e as metas do trimestre.',
                    voice: i % 3 + 1,
                  ),
              ],
            ),
          )
          .id!;

      await background.read(echoSummaryRunnerProvider).start(longId);
      await pumpEventQueue();

      expect(channel.summarizedInstructions.length, greaterThan(2));
      for (final instructions in channel.summarizedInstructions) {
        expect(instructions, contains('são 3 vozes diferentes'));
        expect(instructions, contains('mantenha o rótulo ao lado'));
      }
      expect(channel.summarizedTexts.first, contains('Pessoa 3: Fala 2'));
    });

    test('sem vozes separadas, a regra das vozes não vai', () async {
      await background.read(echoSummaryRunnerProvider).start(meetingId);
      await pumpEventQueue();

      expect(
        channel.summarizedInstructions.single,
        isNot(contains('vozes diferentes')),
      );
    });

    test('com nome, ele vai no rótulo e na instrução', () async {
      // Escrito na janela do Hub, lido no engine da janela 0: o runner relê o
      // disco antes de começar, senão o primeiro resumo depois de a pessoa se
      // apresentar sairia chamando ela de "a pessoa" ainda.
      await preferences.setString('app.user_name', 'Lucas');

      await background.read(echoSummaryRunnerProvider).start(meetingId);
      await pumpEventQueue();

      expect(channel.summarizedTexts.single, contains('Lucas: Fechado'));
      expect(channel.summarizedTexts.single, isNot(contains('Você:')));
      expect(channel.summarizedInstructions.single, contains('"Lucas:"'));
      expect(
        channel.summarizedInstructions.single,
        contains('só o que estiver nessas falas'),
      );
      expect(
        channel.summarizedInstructions.single,
        contains('nunca de "você" nem de "a pessoa"'),
      );
    });
  });
}

import 'dart:async';

import 'package:evergreen/core/local_model/lm_studio_http.dart';
import 'package:evergreen/core/local_model/lm_studio_local_model.dart';
import 'package:evergreen/core/local_model/local_model.dart';
import 'package:evergreen/core/local_model/local_model_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_lm_studio_http.dart';

class _MemoryLedger implements LmStudioLedger {
  String? value;

  @override
  String? read() => value;

  @override
  Future<void> write(String? instanceId) async => value = instanceId;
}

class _AppleBackend implements LocalModelBackend {
  int opens = 0;

  @override
  Future<LocalModelSession> open(LocalModelChoice choice) async {
    opens++;
    return _AppleSession();
  }
}

class _AppleSession implements LocalModelSession {
  @override
  String get displayName => LocalModelChoice.appleName;

  @override
  int? get contextTokens => 4096;

  @override
  Future<String> generate({
    required String text,
    required String instructions,
    required int maxTokens,
    LocalModelCancellation? cancellation,
  }) async => 'apple';

  @override
  Future<void> close() async {}
}

/// O portão: um por aplicativo, um pedido por vez, carrega uma vez para a fila
/// inteira e descarrega quando ela esvazia — e só o que ele mesmo carregou.
void main() {
  const qwen = LocalModelChoice(
    source: LocalModelSource.lmStudio,
    modelId: 'qwen3.5-4b-mlx',
    modelName: 'Qwen3.5 4B',
  );

  late FakeLmStudioHttp http;
  late _AppleBackend apple;
  late LocalModelChoice choice;
  late LocalModelGate gate;

  setUp(() {
    http = FakeLmStudioHttp();
    apple = _AppleBackend();
    choice = qwen;
    final lmStudio = LmStudioLocalModel(
      api: LmStudioApi(http),
      ledger: _MemoryLedger(),
    );
    gate = LocalModelGate(
      choice: () async => choice,
      backendFor: (source) => switch (source) {
        LocalModelSource.apple => apple,
        LocalModelSource.lmStudio => lmStudio,
      },
    );
  });

  Future<LocalModelAnswer> ask(String text) =>
      gate.answer(text: text, instructions: 'Resuma.', maxTokens: 200);

  test('vários pedidos na fila: uma carga só, descarga no fim', () async {
    http.chatGate = Completer<void>();

    final first = ask('um');
    final second = ask('dois');
    final third = ask('três');
    await pumpEventQueue();

    // O primeiro está com o modelo; os outros esperam a vez.
    expect(http.chats, hasLength(1));
    expect(http.loads, 1);

    http.chatGate!.complete();
    final answers = await Future.wait([first, second, third]);

    expect(answers.map((answer) => answer.model), everyElement('Qwen3.5 4B'));
    expect(http.chats, hasLength(3));
    expect(http.loads, 1);
    expect(http.unloads, 1);
    expect(http.loaded, isEmpty);
  });

  test(
    'o Echo em blocos e o Track juntos: o Track não descarrega o Echo',
    () async {
      http.chatGate = Completer<void>();

      // O resumo do Echo: vários blocos dentro de um pedido só.
      final echo = gate.run((session) async {
        final parts = <String>[];
        for (final block in ['bloco 1', 'bloco 2', 'bloco 3']) {
          parts.add(
            await session.generate(
              text: block,
              instructions: 'Resuma.',
              maxTokens: 1500,
            ),
          );
        }
        return parts;
      });
      // O parágrafo do Track chega no meio.
      final track = ask('o dia');
      await pumpEventQueue();

      http.chatGate!.complete();
      await Future.wait([echo, track]);

      // O Track esperou o Echo terminar os três blocos, e o modelo só saiu da
      // memória depois dos dois.
      expect(http.chats.map((chat) => chat['input']), [
        'bloco 1',
        'bloco 2',
        'bloco 3',
        'o dia',
      ]);
      expect(http.loads, 1);
      expect(http.unloads, 1);
    },
  );

  test('o modelo que já estava aberto continua aberto', () async {
    http.loaded['qwen3.5-4b-mlx'] = 32768;

    await ask('um');
    await ask('dois');

    expect(http.loads, 0);
    expect(http.unloads, 0);
    expect(http.loaded, isNotEmpty);
  });

  test('um pedido que falha não trava a fila e não prende o modelo', () async {
    final failing = gate.run<void>((session) async {
      await session.generate(text: 'x', instructions: 'y', maxTokens: 10);
      throw StateError('quebrou');
    });
    final next = ask('dois');

    await expectLater(failing, throwsStateError);
    expect((await next).text, 'resumo');
    expect(http.loaded, isEmpty);
  });

  test(
    'servidor desligado falha calado para quem pediu, sem volta ao Apple',
    () async {
      http.offline = true;

      await expectLater(ask('um'), throwsA(isA<LocalModelException>()));
      // Quem escolheu o LM Studio espera o LM Studio: um texto escrito por
      // outro modelo sem aviso confundiria.
      expect(apple.opens, 0);
    },
  );

  group('com folga antes de descarregar', () {
    late LocalModelGate patient;

    setUp(() {
      final lmStudio = LmStudioLocalModel(
        api: LmStudioApi(http),
        ledger: _MemoryLedger(),
      );
      patient = LocalModelGate(
        idleGrace: const Duration(milliseconds: 50),
        choice: () async => choice,
        backendFor: (source) => switch (source) {
          LocalModelSource.apple => apple,
          LocalModelSource.lmStudio => lmStudio,
        },
      );
      addTearDown(patient.dispose);
    });

    Future<LocalModelAnswer> askPatient(String text) =>
        patient.answer(text: text, instructions: 'Resuma.', maxTokens: 200);

    test(
      'pedidos em sequência reaproveitam o modelo, e ele sai depois',
      () async {
        await askPatient('segunda');
        await askPatient('terça');
        await askPatient('quarta');

        // Passeando pelos dias do Track: uma carga só.
        expect(http.loads, 1);
        expect(http.loaded, isNotEmpty);

        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(http.unloads, 1);
        expect(http.loaded, isEmpty);
      },
    );

    test('o modelo ejetado na folga não prende os pedidos seguintes', () async {
      await askPatient('um');
      // Ejetado no LM Studio: o chat responde 404.
      http.loaded.clear();
      http.chatFailure = const LmStudioResponse(404, null);

      await expectLater(
        askPatient('dois'),
        throwsA(isA<LocalModelException>()),
      );

      // O seguinte abre uma sessão nova — e carrega de novo.
      final answer = await askPatient('três');
      expect(answer.text, 'resumo');
      expect(http.loads, 2);
    });

    test('trocar de modelo na folga fecha o anterior', () async {
      await askPatient('um');
      choice = LocalModelChoice.apple;

      final answer = await askPatient('dois');

      expect(answer.model, 'Apple Intelligence');
      expect(http.loaded, isEmpty);
    });
  });

  test('a escolha é lida a cada abertura', () async {
    choice = LocalModelChoice.apple;
    expect((await ask('um')).model, 'Apple Intelligence');

    choice = qwen;
    expect((await ask('dois')).model, 'Qwen3.5 4B');
  });
}

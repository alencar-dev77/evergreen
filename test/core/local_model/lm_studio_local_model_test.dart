import 'package:evergreen/core/local_model/lm_studio_http.dart';
import 'package:evergreen/core/local_model/lm_studio_local_model.dart';
import 'package:evergreen/core/local_model/local_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_lm_studio_http.dart';

class _MemoryLedger implements LmStudioLedger {
  String? value;

  @override
  String? read() => value;

  @override
  Future<void> write(String? instanceId) async => value = instanceId;
}

/// O LM Studio pela API nativa: carrega com o contexto pedido, escreve com o
/// raciocínio desligado e só descarrega o que ele mesmo carregou.
void main() {
  const qwen = LocalModelChoice(
    source: LocalModelSource.lmStudio,
    modelId: 'qwen3.5-4b-mlx',
    modelName: 'Qwen3.5 4B',
  );

  late FakeLmStudioHttp http;
  late _MemoryLedger ledger;
  late LmStudioLocalModel backend;

  setUp(() {
    http = FakeLmStudioHttp();
    ledger = _MemoryLedger();
    backend = LmStudioLocalModel(api: LmStudioApi(http), ledger: ledger);
  });

  group('a lista de /api/v1/models', () {
    test('lê nome, contexto, instâncias e o que o raciocínio aceita', () {
      final models = LmStudioModel.listFromJson({
        'models': [
          {
            'key': 'qwen3.5-4b-mlx',
            'display_name': 'Qwen3.5 4B',
            'type': 'llm',
            'max_context_length': 262144,
            'loaded_instances': [
              {
                'id': 'qwen3.5-4b-mlx',
                'config': {'context_length': 8192},
              },
            ],
            'capabilities': {
              'reasoning': {
                'allowed_options': ['off', 'on'],
              },
            },
          },
          {
            'key': 'text-embedding-nomic-embed-text-v1.5',
            'type': 'embedding',
            'loaded_instances': <Object?>[],
          },
          {'display_name': 'sem chave'},
        ],
      });

      expect(models, hasLength(2));
      final qwen = models.first;
      expect(qwen.key, 'qwen3.5-4b-mlx');
      expect(qwen.displayName, 'Qwen3.5 4B');
      expect(qwen.isLlm, isTrue);
      expect(qwen.maxContextLength, 262144);
      expect(qwen.loadedInstances.single.contextLength, 8192);
      expect(qwen.reasoningOptions, ['off', 'on']);

      // Sem nome de exibição, a chave assina; e modelo de embedding não
      // escreve texto.
      expect(models.last.displayName, 'text-embedding-nomic-embed-text-v1.5');
      expect(models.last.isLlm, isFalse);
      expect(models.last.reasoningOptions, isEmpty);
    });

    test('resposta torta é lista vazia, não exceção', () {
      expect(LmStudioModel.listFromJson(null), isEmpty);
      expect(LmStudioModel.listFromJson({'models': 'nada'}), isEmpty);
    });
  });

  group('o raciocínio que vaza para a resposta', () {
    test('o bloco inteiro sai', () {
      expect(
        ThinkCleaner.clean('<think>vou resumir</think>\n\nO resumo.'),
        'O resumo.',
      );
    });

    test('o fechamento sem a abertura leva o que vem antes', () {
      expect(ThinkCleaner.clean('vou resumir</think>O resumo.'), 'O resumo.');
    });

    test('a abertura sem fechamento é pensamento cortado pelo teto', () {
      expect(ThinkCleaner.clean('O resumo.<think>e mais'), 'O resumo.');
      expect(ThinkCleaner.clean('<think>só pensou'), '');
    });

    test('texto sem bloco passa intacto', () {
      expect(ThinkCleaner.clean('  O resumo.  '), 'O resumo.');
    });

    test('só as mensagens viram texto — o raciocínio do chat fica de fora', () {
      expect(
        LmStudioApi.messageOf({
          'output': [
            {'type': 'reasoning', 'content': 'pensando'},
            {'type': 'message', 'content': 'O resumo.'},
          ],
        }),
        'O resumo.',
      );
    });
  });

  group('os erros do servidor', () {
    test('o texto que não coube vira estouro de janela', () async {
      http.chatFailure = const LmStudioResponse(400, {
        'error': {
          'message':
              'The number of tokens to keep from the initial prompt is '
              'greater than the context length',
        },
      });

      final session = await backend.open(qwen);
      await expectLater(
        session.generate(text: 'x', instructions: 'y', maxTokens: 10),
        throwsA(
          isA<LocalModelException>().having(
            (error) => error.isContextWindowExceeded,
            'estouro',
            isTrue,
          ),
        ),
      );
    });

    test('a mensagem de erro é achada em qualquer forma', () {
      expect(LmStudioApi.errorMessageOf({'error': 'falhou'}), 'falhou');
      expect(
        LmStudioApi.errorMessageOf({
          'error': {'message': 'falhou'},
        }),
        'falhou',
      );
      expect(LmStudioApi.errorMessageOf({'message': 'falhou'}), 'falhou');
      expect(LmStudioApi.errorMessageOf('falhou'), '');
    });
  });

  group('abrir e fechar', () {
    test('servidor desligado é "indisponível", como o macOS antigo', () async {
      http.offline = true;

      await expectLater(
        backend.open(qwen),
        throwsA(
          isA<LocalModelException>()
              .having((error) => error.code, 'code', 'unsupported_os')
              .having(
                (error) => error.message,
                'message',
                'O servidor do LM Studio está desligado.',
              ),
        ),
      );
    });

    test('modelo que saiu do disco também é indisponível', () async {
      await expectLater(
        backend.open(
          const LocalModelChoice(
            source: LocalModelSource.lmStudio,
            modelId: 'apagado',
          ),
        ),
        throwsA(
          isA<LocalModelException>().having(
            (error) => error.code,
            'code',
            'unsupported_os',
          ),
        ),
      );
    });

    test(
      'carrega com 32k, escreve sem raciocínio e descarrega no fim',
      () async {
        final session = await backend.open(qwen);

        expect(http.loaded, {'qwen3.5-4b-mlx': 32768});
        expect(session.contextTokens, 32768);
        expect(session.displayName, 'Qwen3.5 4B');
        expect(ledger.value, 'qwen3.5-4b-mlx');

        http.chatAnswer = '<think>hmm</think>O resumo.';
        final text = await session.generate(
          text: 'Você: oi',
          instructions: 'Resuma.',
          maxTokens: 1500,
        );

        expect(text, 'O resumo.');
        final chat = http.chats.single;
        expect(chat['model'], 'qwen3.5-4b-mlx');
        expect(chat['input'], 'Você: oi');
        expect(chat['system_prompt'], 'Resuma.');
        expect(chat['max_output_tokens'], 1500);
        expect(chat['reasoning'], 'off');
        expect(chat['store'], isFalse);

        await session.close();
        expect(http.loaded, isEmpty);
        expect(ledger.value, isNull);
      },
    );

    test('modelo sem raciocínio não recebe o campo', () async {
      final plain = FakeLmStudioHttp(
        models: const [
          {'key': 'gemma', 'display_name': 'Gemma', 'type': 'llm'},
        ],
      );
      final session =
          await LmStudioLocalModel(
            api: LmStudioApi(plain),
            ledger: ledger,
          ).open(
            const LocalModelChoice(
              source: LocalModelSource.lmStudio,
              modelId: 'gemma',
            ),
          );

      await session.generate(text: 'x', instructions: 'y', maxTokens: 10);

      expect(plain.chats.single.containsKey('reasoning'), isFalse);
    });

    test(
      'o modelo que a pessoa já tinha aberto é usado e continua aberto',
      () async {
        http.loaded['qwen3.5-4b-mlx'] = 8192;

        final session = await backend.open(qwen);

        expect(http.loads, 0);
        // O contexto é o da instância dela, não os 32k: o bloco precisa caber
        // no modelo que está de fato na memória.
        expect(session.contextTokens, 8192);

        await session.close();
        expect(http.unloads, 0);
        expect(http.loaded, {'qwen3.5-4b-mlx': 8192});
        expect(ledger.value, isNull);
      },
    );

    test('a varredura descarrega o que uma queda deixou na memória', () async {
      http.loaded['qwen3.5-4b-mlx'] = 32768;
      ledger.value = 'qwen3.5-4b-mlx';

      await backend.sweep();

      expect(http.loaded, isEmpty);
      expect(ledger.value, isNull);
    });

    test('sem registro, a varredura não toca em nada', () async {
      http.loaded['qwen3.5-4b-mlx'] = 8192;

      await backend.sweep();

      expect(http.unloads, 0);
      expect(http.loaded, isNotEmpty);
    });
  });
}

import 'dart:async';

import 'package:evergreen/core/local_model/lm_studio_http.dart';
import 'package:evergreen/core/local_model/local_model.dart';

/// O servidor do LM Studio de mentira, com um estado que o teste observa: quais
/// modelos estão no disco e quais estão na memória.
class FakeLmStudioHttp implements LmStudioHttp {
  FakeLmStudioHttp({
    this.models = const [
      {
        'key': 'qwen3.5-4b-mlx',
        'display_name': 'Qwen3.5 4B',
        'type': 'llm',
        'max_context_length': 262144,
        'capabilities': {
          'reasoning': {
            'allowed_options': ['off', 'on'],
            'default': 'on',
          },
        },
      },
    ],
  });

  /// O que `/api/v1/models` devolve, menos as instâncias.
  final List<Map<String, Object?>> models;

  /// Servidor desligado: toda chamada é recusada.
  bool offline = false;

  /// A memória do servidor: chave do modelo → contexto da instância.
  final loaded = <String, int>{};

  int loads = 0;
  int unloads = 0;
  final chats = <Map<String, Object?>>[];

  String chatAnswer = 'resumo';

  /// O chat fica esperando até o teste soltar — para ver a fila andando.
  Completer<void>? chatGate;

  /// A resposta de erro do próximo chat.
  LmStudioResponse? chatFailure;

  @override
  Future<LmStudioResponse> get(String path, {required Duration timeout}) async {
    if (offline) throw const LmStudioUnreachable();
    if (path != '/api/v1/models') return const LmStudioResponse(404, null);

    return LmStudioResponse(200, {
      'models': [
        for (final model in models)
          {
            ...model,
            'loaded_instances': [
              if (loaded.containsKey(model['key']))
                {
                  'id': model['key'],
                  'config': {'context_length': loaded[model['key']]},
                },
            ],
          },
      ],
    });
  }

  @override
  Future<LmStudioResponse> post(
    String path,
    Map<String, Object?> body, {
    required Duration timeout,
    LocalModelCancellation? cancellation,
  }) async {
    if (offline) throw const LmStudioUnreachable();

    switch (path) {
      case '/api/v1/models/load':
        loads++;
        final key = body['model']! as String;
        loaded[key] = body['context_length']! as int;
        return LmStudioResponse(200, {
          'type': 'llm',
          'instance_id': key,
          'status': 'loaded',
          'load_config': {'context_length': loaded[key]},
        });
      case '/api/v1/models/unload':
        unloads++;
        loaded.remove(body['instance_id']);
        return LmStudioResponse(200, {'instance_id': body['instance_id']});
      case '/api/v1/chat':
        chats.add(body);
        await chatGate?.future;
        final failure = chatFailure;
        if (failure != null) {
          chatFailure = null;
          return failure;
        }
        return LmStudioResponse(200, {
          'model_instance_id': body['model'],
          'output': [
            {'type': 'reasoning', 'content': 'pensando'},
            {'type': 'message', 'content': chatAnswer},
          ],
        });
    }

    return const LmStudioResponse(404, null);
  }
}

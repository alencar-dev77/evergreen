import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lm_studio_http.dart';
import 'local_model.dart';

/// Uma instância de modelo que está na memória do LM Studio.
@immutable
class LmStudioInstance {
  const LmStudioInstance({required this.id, required this.contextLength});

  final String id;
  final int? contextLength;
}

/// Um modelo que o LM Studio tem no disco, como `/api/v1/models` o descreve.
@immutable
class LmStudioModel {
  const LmStudioModel({
    required this.key,
    required this.displayName,
    required this.type,
    this.maxContextLength,
    this.loadedInstances = const [],
    this.reasoningOptions = const [],
  });

  /// Lê um item da lista. `null` quando falta a chave — sem ela não há como
  /// pedir o modelo, então ele não serve para nada aqui.
  static LmStudioModel? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    if (key is! String || key.isEmpty) return null;

    final displayName = json['display_name'];
    final capabilities = json['capabilities'];
    final reasoning = capabilities is Map ? capabilities['reasoning'] : null;
    final options = reasoning is Map ? reasoning['allowed_options'] : null;

    return LmStudioModel(
      key: key,
      displayName: displayName is String && displayName.trim().isNotEmpty
          ? displayName.trim()
          : key,
      type: json['type'] is String ? json['type'] as String : '',
      maxContextLength: _int(json['max_context_length']),
      loadedInstances: [
        for (final raw in _list(json['loaded_instances']))
          if (raw is Map && raw['id'] is String)
            LmStudioInstance(
              id: raw['id'] as String,
              contextLength: raw['config'] is Map
                  ? _int((raw['config'] as Map)['context_length'])
                  : null,
            ),
      ],
      reasoningOptions: [
        for (final option in _list(options))
          if (option is String) option,
      ],
    );
  }

  /// A lista inteira, como o servidor a devolve.
  static List<LmStudioModel> listFromJson(Object? json) {
    final models = json is Map ? json['models'] : null;

    return [for (final raw in _list(models)) ?fromJson(raw)];
  }

  /// O identificador que se pede ao servidor (`qwen3.5-4b-mlx`).
  final String key;

  /// O nome que o LM Studio mostra (`Qwen3.5 4B`). Na falta dele, a chave.
  final String displayName;

  /// `llm`, `embedding`… Só `llm` escreve texto.
  final String type;

  final int? maxContextLength;
  final List<LmStudioInstance> loadedInstances;

  /// O que o campo `reasoning` aceita para este modelo. Vazio quando o modelo
  /// não raciocina — e aí mandar o campo seria um erro do servidor.
  final List<String> reasoningOptions;

  bool get isLlm => type == 'llm';
  bool get isLoaded => loadedInstances.isNotEmpty;

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static List<Object?> _list(Object? value) => value is List ? value : const [];
}

/// O raciocínio que vazou para a resposta, tirado dela.
///
/// O pedido vai com o raciocínio desligado, mas modelo de raciocínio às vezes
/// escreve o bloco mesmo assim — e às vezes só a metade dele: o fechamento sem
/// a abertura (quando o molde da conversa já abriu a tag) ou a abertura sem o
/// fechamento (quando o teto de tokens cortou no meio do pensamento).
abstract final class ThinkCleaner {
  static final _pairs = RegExp(r'<think>[\s\S]*?</think>');

  static String clean(String text) {
    var result = text.replaceAll(_pairs, '');

    final orphanClose = result.lastIndexOf('</think>');
    if (orphanClose >= 0) {
      result = result.substring(orphanClose + '</think>'.length);
    }

    final orphanOpen = result.indexOf('<think>');
    if (orphanOpen >= 0) result = result.substring(0, orphanOpen);

    return result.trim();
  }
}

/// Onde o Evergreen anota a instância que ele mesmo carregou.
///
/// O `load` da API nativa não aceita prazo de inatividade: um modelo carregado
/// fica na memória até alguém o tirar. Se o Evergreen cair entre o `load` e o
/// `unload`, este registro é o que faz a abertura seguinte terminar o serviço
/// ([LmStudioLocalModel.sweep]).
abstract interface class LmStudioLedger {
  String? read();
  Future<void> write(String? instanceId);
}

class PrefsLmStudioLedger implements LmStudioLedger {
  PrefsLmStudioLedger(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'app.local_model_loaded_instance';

  @override
  String? read() => _prefs.getString(_key);

  @override
  Future<void> write(String? instanceId) async {
    if (instanceId == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, instanceId);
    }
  }
}

/// As chamadas da API nativa do LM Studio (`/api/v1/...`).
///
/// A nativa, e não a compatível com a OpenAI: só ela deixa escolher o contexto
/// no carregamento e descarregar quando se quer.
class LmStudioApi {
  const LmStudioApi(this._http);

  final LmStudioHttp _http;

  static const _listTimeout = Duration(seconds: 5);
  static const _loadTimeout = Duration(minutes: 3);
  static const _unloadTimeout = Duration(seconds: 30);

  /// Uma reunião inteira num bloco, num modelo de 4B: a leitura do texto leva
  /// dezenas de segundos e a escrita, outro tanto. Dez minutos é a margem para
  /// um Mac ocupado — e o prazo que impede "Resumindo…" para sempre.
  static const _chatTimeout = Duration(minutes: 10);

  /// Lança [LmStudioUnreachable] com o servidor desligado.
  Future<List<LmStudioModel>> models() async {
    final response = await _http.get('/api/v1/models', timeout: _listTimeout);
    // A lista é a primeira coisa que se pede, e o único 404 que significa
    // outra coisa que "modelo apagado": a API nativa não existe neste LM
    // Studio.
    if (response.status == 404) throw outdated;
    _check(response);

    return LmStudioModel.listFromJson(response.json);
  }

  Future<LmStudioInstance> load(
    String key, {
    required int contextLength,
  }) async {
    final response = await _http.post('/api/v1/models/load', {
      'model': key,
      'context_length': contextLength,
      'echo_load_config': true,
    }, timeout: _loadTimeout);
    _check(response, canOverflow: false);

    final json = response.json;
    final id = json is Map ? json['instance_id'] : null;
    final config = json is Map ? json['load_config'] : null;
    final loaded = config is Map ? config['context_length'] : null;

    return LmStudioInstance(
      id: id is String && id.isNotEmpty ? id : key,
      contextLength: loaded is num ? loaded.toInt() : contextLength,
    );
  }

  Future<void> unload(String instanceId) async {
    final response = await _http.post('/api/v1/models/unload', {
      'instance_id': instanceId,
    }, timeout: _unloadTimeout);
    _check(response);
  }

  Future<String> chat({
    required String model,
    required String text,
    required String instructions,
    required int maxTokens,
    required bool reasoningOff,
    LocalModelCancellation? cancellation,
  }) async {
    final response = await _http.post(
      '/api/v1/chat',
      {
        'model': model,
        'input': text,
        'system_prompt': instructions,
        'max_output_tokens': maxTokens,
        'temperature': 0.3,
        'store': false,
        if (reasoningOff) 'reasoning': 'off',
      },
      timeout: _chatTimeout,
      cancellation: cancellation,
    );
    _check(response);

    return ThinkCleaner.clean(messageOf(response.json));
  }

  /// O texto das mensagens de uma resposta do chat, sem o raciocínio.
  @visibleForTesting
  static String messageOf(Object? json) {
    final output = json is Map ? json['output'] : null;
    if (output is! List) return '';

    return [
      for (final item in output)
        if (item is Map &&
            item['type'] == 'message' &&
            item['content'] is String)
          item['content'] as String,
    ].join('\n');
  }

  static const unauthorized = LocalModelException(
    LocalModelException.unauthorized,
    'O servidor do LM Studio pede um token de API. Desligue essa exigência '
    'nas configurações do servidor.',
  );

  static const outdated = LocalModelException(
    LocalModelException.outdated,
    'Atualize o LM Studio para a versão 0.4 ou mais nova.',
  );

  /// O que estourou a janela, em qualquer redação que o servidor use.
  static final _overflow = RegExp(
    r'context|n_ctx|too (long|many tokens)|exceed',
    caseSensitive: false,
  );

  /// [canOverflow] só no chat: no `load`, "context" na mensagem é a recusa de
  /// carregar com aquele contexto (memória, quase sempre), e não um texto que
  /// não coube — repartir o texto não resolveria nada.
  static void _check(LmStudioResponse response, {bool canOverflow = true}) {
    if (response.isOk) return;

    if (response.status == 401 || response.status == 403) throw unauthorized;

    final message = errorMessageOf(response.json);
    if (canOverflow && _overflow.hasMatch(message)) {
      throw LocalModelException(
        LocalModelException.contextWindowExceeded,
        'O texto não coube no modelo.',
      );
    }
    if (response.status == 404) {
      throw const LocalModelException(
        LocalModelException.unsupported,
        'O modelo escolhido não está mais no LM Studio.',
      );
    }

    throw LocalModelException(
      LocalModelException.failed,
      'O LM Studio recusou o pedido (${response.status}).',
    );
  }

  /// A mensagem de erro, onde quer que o servidor a tenha posto.
  @visibleForTesting
  static String errorMessageOf(Object? json) {
    if (json is! Map) return '';
    final error = json['error'];
    if (error is String) return error;
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    final message = json['message'];

    return message is String ? message : '';
  }
}

/// Um modelo do LM Studio: carrega, escreve, descarrega.
///
/// **Só descarrega o que ele mesmo carregou.** Se a pessoa já estava com o
/// modelo aberto no LM Studio, a sessão usa aquela instância — com o contexto
/// dela — e não a fecha no fim. Fechar tiraria o modelo de baixo de quem está
/// trabalhando no chat do LM Studio.
class LmStudioLocalModel implements LocalModelBackend {
  const LmStudioLocalModel({
    required LmStudioApi api,
    required LmStudioLedger ledger,
  }) : _api = api,
       _ledger = ledger;

  /// O contexto pedido no carregamento: uma reunião de uma hora em português
  /// cabe num bloco só, e o resumo deixa de ser um resumo de resumos.
  static const contextLength = 32768;

  final LmStudioApi _api;
  final LmStudioLedger _ledger;

  static const offline = LocalModelException(
    LocalModelException.unsupported,
    'O servidor do LM Studio está desligado.',
  );

  @override
  Future<LocalModelSession> open(LocalModelChoice choice) async {
    if (choice.isIncomplete) {
      throw const LocalModelException(
        LocalModelException.unsupported,
        'Nenhum modelo do LM Studio foi escolhido.',
      );
    }

    final List<LmStudioModel> models;
    try {
      models = await _api.models();
    } on LmStudioUnreachable {
      throw offline;
    }

    final model = models
        .where((model) => model.key == choice.modelId)
        .firstOrNull;
    if (model == null) {
      throw const LocalModelException(
        LocalModelException.unsupported,
        'O modelo escolhido não está mais no LM Studio.',
      );
    }

    // O que o Evergreen deixou na memória numa vez anterior — um `load` que
    // estourou o prazo e terminou do lado do servidor, ou um `unload` recusado.
    final leftover = _ledger.read();

    if (model.isLoaded) {
      final ours = model.loadedInstances
          .where((instance) => instance.id == leftover)
          .firstOrNull;
      // A instância que o registro aponta é do Evergreen, e é ele quem a
      // descarrega no fim; qualquer outra é da pessoa, e fica aberta.
      return _LmStudioSession(
        api: _api,
        ledger: _ledger,
        model: model,
        instance: ours ?? model.loadedInstances.first,
        owned: ours != null,
      );
    }

    // Sobra de outro modelo: sai antes, senão o registro novo a esqueceria.
    if (leftover != null) await sweep();

    final wanted = math.min(
      contextLength,
      model.maxContextLength ?? contextLength,
    );
    // Anotado **antes** do `load`: se ele estourar o prazo, o servidor termina
    // de carregar sozinho, e sem o registro o modelo ficaria na memória como
    // se fosse da pessoa. O id da instância é a chave do modelo até o servidor
    // dizer outro.
    await _ledger.write(model.key);
    final LmStudioInstance instance;
    try {
      instance = await _api.load(model.key, contextLength: wanted);
    } on LmStudioUnreachable {
      // Servidor fora não carregou nada.
      await _ledger.write(null);
      throw offline;
    }
    await _ledger.write(instance.id);

    return _LmStudioSession(
      api: _api,
      ledger: _ledger,
      model: model,
      instance: instance,
      owned: true,
    );
  }

  /// Descarrega o que uma execução anterior deixou na memória.
  ///
  /// Roda na abertura da janela 0. Sem registro, não faz nada.
  ///
  /// Um limite que não tem conserto daqui: o id da instância é a chave do
  /// modelo, e se a pessoa abrir **o mesmo modelo** no LM Studio entre a queda
  /// e a abertura seguinte, a varredura o descarrega — o servidor não diz quem
  /// carregou o quê.
  Future<void> sweep() async {
    final leftover = _ledger.read();
    if (leftover == null) return;

    try {
      await _api.unload(leftover);
    } on Object {
      // Servidor desligado também descarrega: não há mais o que tirar.
    }
    await _ledger.write(null);
  }
}

class _LmStudioSession implements LocalModelSession {
  _LmStudioSession({
    required LmStudioApi api,
    required LmStudioLedger ledger,
    required LmStudioModel model,
    required LmStudioInstance instance,
    required bool owned,
  }) : _api = api,
       _ledger = ledger,
       _model = model,
       _instance = instance,
       _owned = owned;

  final LmStudioApi _api;
  final LmStudioLedger _ledger;
  final LmStudioModel _model;
  final LmStudioInstance _instance;
  final bool _owned;

  @override
  String get displayName => _model.displayName;

  @override
  int? get contextTokens => _instance.contextLength;

  @override
  Future<String> generate({
    required String text,
    required String instructions,
    required int maxTokens,
    LocalModelCancellation? cancellation,
  }) async {
    try {
      return await _api.chat(
        model: _instance.id,
        text: text,
        instructions: instructions,
        maxTokens: maxTokens,
        reasoningOff: _model.reasoningOptions.contains('off'),
        cancellation: cancellation,
      );
    } on LmStudioUnreachable {
      throw LmStudioLocalModel.offline;
    }
  }

  @override
  Future<void> close() async {
    if (!_owned) return;

    try {
      await _api.unload(_instance.id);
    } on LmStudioUnreachable {
      // Servidor que caiu no meio já soltou a memória sozinho.
    } on Object {
      // Qualquer outra recusa deixa o registro: a varredura da próxima
      // abertura tenta de novo.
      return;
    }
    await _ledger.write(null);
  }
}

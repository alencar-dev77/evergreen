import 'dart:async';

import 'package:flutter/foundation.dart';

/// De onde vem o modelo que escreve os textos do Evergreen.
///
/// Dois hoje. O Ollama cabe aqui do mesmo jeito que o LM Studio: o ciclo de
/// carregar, gerar e descarregar é o mesmo, com outros nomes.
enum LocalModelSource {
  /// O modelo do Apple Intelligence, pelo canal do Echo. É o padrão.
  apple('apple'),

  /// Um modelo que a pessoa baixou no LM Studio, pelo servidor local dele.
  lmStudio('lm_studio');

  const LocalModelSource(this.id);

  /// O que vai para o disco. Nunca o `name`, que é do código.
  final String id;

  static LocalModelSource fromId(String? id) => values.firstWhere(
    (source) => source.id == id,
    orElse: () => LocalModelSource.apple,
  );
}

/// Qual modelo a pessoa escolheu.
///
/// Guarda o nome junto do id porque a tela do aplicativo precisa mostrar o
/// escolhido com o servidor desligado — e é com o servidor desligado que a
/// pessoa mais olha para essa linha.
@immutable
class LocalModelChoice {
  const LocalModelChoice({
    this.source = LocalModelSource.apple,
    this.modelId = '',
    this.modelName = '',
  });

  static const apple = LocalModelChoice();

  /// O nome do Apple Intelligence onde quer que ele assine um texto.
  static const appleName = 'Apple Intelligence';

  final LocalModelSource source;

  /// A chave do modelo no LM Studio (`qwen3.5-4b-mlx`). Vazia com o Apple.
  final String modelId;

  /// O nome que o LM Studio dá ao modelo (`Qwen3.5 4B`). Vazio com o Apple.
  final String modelName;

  /// LM Studio sem modelo escolhido ainda: não há quem escreva.
  bool get isIncomplete =>
      source == LocalModelSource.lmStudio && modelId.isEmpty;

  /// O nome que assina o texto: "Resumido por …".
  String get displayName => switch (source) {
    LocalModelSource.apple => appleName,
    LocalModelSource.lmStudio => modelName.isEmpty ? modelId : modelName,
  };

  /// Uma chave curta e estável — o que entra na assinatura do dia do Track,
  /// para trocar de modelo refazer o parágrafo.
  String get key => switch (source) {
    LocalModelSource.apple => source.id,
    LocalModelSource.lmStudio => '${source.id}:$modelId',
  };

  @override
  bool operator ==(Object other) =>
      other is LocalModelChoice &&
      other.source == source &&
      other.modelId == modelId &&
      other.modelName == modelName;

  @override
  int get hashCode => Object.hash(source, modelId, modelName);
}

/// O modelo não respondeu — por um motivo que a tela sabe explicar.
///
/// Dois códigos são fluxo, não falha: [unsupported] (o modelo não existe nesta
/// máquina agora — Mac abaixo do 26, servidor do LM Studio desligado, modelo
/// apagado do disco) e [contextWindowExceeded] (o texto não coube, e quem
/// chama reparte).
class LocalModelException implements Exception {
  const LocalModelException(this.code, this.message);

  static const unsupported = 'unsupported_os';
  static const contextWindowExceeded = 'context_window_exceeded';
  static const timeout = 'timeout';
  static const failed = 'failed';

  final String code;
  final String message;

  bool get isContextWindowExceeded => code == contextWindowExceeded;

  @override
  String toString() => 'LocalModelException($code): $message';
}

/// O aviso de que quem pediu desistiu.
///
/// Quem pode, interrompe o pedido em curso (o LM Studio, fechando a conexão);
/// quem não pode, ignora (o `FoundationModels` não para no meio).
class LocalModelCancellation {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Um modelo pronto para escrever — carregado, se carregar é coisa dele.
abstract interface class LocalModelSession {
  /// Quem está escrevendo. É o que vai gravado em "Resumido por".
  String get displayName;

  /// Quantos tokens cabem numa chamada, ou `null` se não deu para saber.
  int? get contextTokens;

  /// Escreve uma resposta para [text] seguindo [instructions].
  ///
  /// [maxTokens] é teto, não pedido: um modelo pequeno às vezes não para de
  /// gerar, e um resumo de reunião não precisa de mais que isso.
  Future<String> generate({
    required String text,
    required String instructions,
    required int maxTokens,
    LocalModelCancellation? cancellation,
  });

  /// Devolve a memória — mas só o que esta sessão ocupou.
  Future<void> close();
}

/// Quem sabe abrir uma sessão com um tipo de modelo.
abstract interface class LocalModelBackend {
  /// Abre a sessão: no LM Studio isso carrega o modelo (ou adota a instância
  /// que a pessoa já tinha aberto). Lança [LocalModelException] quando não dá.
  Future<LocalModelSession> open(LocalModelChoice choice);
}

/// Uma resposta escrita, com quem a escreveu.
@immutable
class LocalModelAnswer {
  const LocalModelAnswer({required this.text, required this.model});

  factory LocalModelAnswer.fromMap(Map<Object?, Object?> map) =>
      LocalModelAnswer(
        text: map['text'] as String? ?? '',
        model: map['model'] as String? ?? '',
      );

  final String text;

  /// O nome de quem escreveu — "Apple Intelligence", "Qwen3.5 4B".
  final String model;

  Map<String, Object?> toMap() => {'text': text, 'model': model};
}

/// Pedir **um** texto ao modelo escolhido, sem saber onde ele roda.
///
/// É o que o Track usa: um pedido, uma resposta. Na janela 0 quem atende é o
/// portão; no Hub, um canal até ele.
abstract interface class LocalModelClient {
  Future<LocalModelAnswer> answer({
    required String text,
    required String instructions,
    required int maxTokens,
  });
}

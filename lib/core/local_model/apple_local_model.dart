import '../../features/echo/data/echo_channel.dart';
import 'local_model.dart';

/// O modelo do Apple Intelligence — o canal do Echo de sempre.
///
/// Não há o que carregar nem descarregar: o sistema cuida da memória dele, e
/// abrir uma sessão é só perguntar o tamanho da janela.
class AppleLocalModel implements LocalModelBackend {
  const AppleLocalModel(this._channel);

  final EchoChannel _channel;

  @override
  Future<LocalModelSession> open(LocalModelChoice choice) async {
    return _AppleSession(_channel, await _channel.summaryContextSize());
  }
}

class _AppleSession implements LocalModelSession {
  _AppleSession(this._channel, this.contextTokens);

  final EchoChannel _channel;

  @override
  final int? contextTokens;

  @override
  String get displayName => LocalModelChoice.appleName;

  /// O teto de resposta não atravessa o canal: o `FoundationModels` decide o
  /// tamanho da resposta pela janela dele, e mudar isso mudaria o Echo de quem
  /// nunca escolheu outro modelo.
  @override
  Future<String> generate({
    required String text,
    required String instructions,
    required int maxTokens,
    LocalModelCancellation? cancellation,
  }) async {
    try {
      return await _channel.summarize(text: text, instructions: instructions);
    } on EchoException catch (error) {
      throw LocalModelException(error.code, error.message);
    }
  }

  @override
  Future<void> close() async {}
}

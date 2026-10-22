import 'package:evergreen/core/local_model/local_model.dart';

/// O modelo local de mentira: responde o que o teste mandar, e anota o que
/// recebeu.
class FakeLocalModelClient implements LocalModelClient {
  FakeLocalModelClient({this.answerValue = 'resposta', this.model = 'Modelo'});

  String answerValue;
  String model;
  LocalModelException? failWith;

  final texts = <String>[];
  final instructions = <String>[];

  @override
  Future<LocalModelAnswer> answer({
    required String text,
    required String instructions,
    required int maxTokens,
  }) async {
    texts.add(text);
    this.instructions.add(instructions);

    final failure = failWith;
    if (failure != null) throw failure;

    return LocalModelAnswer(text: answerValue, model: model);
  }
}

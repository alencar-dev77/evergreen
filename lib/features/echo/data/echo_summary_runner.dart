import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import '../models/echo_summary_status.dart';
import '../models/summary_chunker.dart';
import 'echo_channel.dart';
import 'echo_repository.dart';
import 'echo_settings_repository.dart';

/// Quem resume uma reunião.
///
/// Duas implementações, e a diferença entre elas é só o transporte: o
/// [LocalEchoSummaryRunner] faz o trabalho, o [WindowEchoSummaryRunner] pede
/// para quem faz. Quem chama não sabe qual tem na mão.
abstract interface class EchoSummaryRunner {
  /// Põe a reunião para ser resumida e **volta sem esperar o fim**.
  ///
  /// Voltar sem esperar é o ponto do módulo inteiro: um resumo de meia hora de
  /// reunião leva minutos, e ninguém fica olhando a janela até lá.
  Future<void> start(int meetingId);

  /// O andamento agora.
  Future<EchoSummaryStatus> status();
}

/// O resumo acontecendo de verdade, no engine que o pediu.
///
/// **Este objeto vive no engine da janela 0**, junto do cronômetro do Focus e
/// da captura do Pin, e é isso que conserta o resumo que se perdia: o Hub é uma
/// sub-janela, e fechá-la destrói o engine dela. Enquanto o trabalho morava
/// lá, pedir o resumo e sair da janela cancelava o resumo no meio — sem aviso,
/// sem linha no banco, e a reunião reaparecia sem resumo na volta.
class LocalEchoSummaryRunner implements EchoSummaryRunner {
  LocalEchoSummaryRunner({
    required EchoRepository repository,
    required EchoSettingsRepository settings,
    required EchoChannel channel,
  }) : _repository = repository,
       _settings = settings,
       _channel = channel;

  /// Instrução dos resumos de bloco.
  ///
  /// Fixa e neutra de propósito: os blocos são matéria-prima, não resposta. Se
  /// o formato pedido pela pessoa fosse aplicado aqui, o passo final receberia
  /// tópicos de tópicos e perderia o material bruto de que precisa para
  /// organizar. Bloco preserva fato; o formato entra só no fim — e é o do fim
  /// que fica gravado na reunião.
  static const blockInstructions =
      'Resuma este trecho de reunião preservando fatos, decisões, números e '
      'nomes próprios. Escreva em texto corrido, sem formatação. Não invente '
      'nada que não esteja no trecho.';

  final EchoRepository _repository;
  final EchoSettingsRepository _settings;
  final EchoChannel _channel;

  EchoSummaryStatus _status = const EchoSummaryStatus();

  /// A falha é **entregue uma vez** e some.
  ///
  /// Ela precisa esperar por quem pediu o resumo — que pode ter fechado o Hub e
  /// só voltar meia hora depois —, e por isso não é descartada quando o
  /// trabalho termina. Mas guardá-la para sempre faria o mesmo aviso reaparecer
  /// em toda abertura da tela do Echo, por um resumo de terça-feira que a
  /// pessoa já leu e já esqueceu.
  @override
  Future<EchoSummaryStatus> status() async {
    final current = _status;
    if (!current.isRunning && current.errorMessage != null) {
      _status = const EchoSummaryStatus();
    }

    return current;
  }

  @override
  Future<void> start(int meetingId) async {
    if (_status.isRunning) return;

    final meeting = _repository.findById(meetingId);
    if (meeting == null || meeting.isEmpty) return;

    // A instrução mora no Hub, em outro engine: sem reler, o resumo sai com a
    // instrução de ontem. É a mesma armadilha que a gravação já tinha.
    await _settings.reload();
    final instructions = _settings.load().resolvedSummaryInstructions;

    final chunks = SummaryChunker.chunk(meeting.plainText);
    if (chunks.isEmpty) return;

    _status = EchoSummaryStatus(meetingId: meetingId, total: chunks.length);
    unawaited(_run(meetingId, chunks, instructions));
  }

  /// Em dois passos quando o texto não cabe de uma vez: cada bloco vira um
  /// resumo neutro, e o passo final junta os resumos aplicando a instrução que
  /// a pessoa escreveu. Com um bloco só, o passo final é o único que existe.
  Future<void> _run(
    int meetingId,
    List<String> chunks,
    String instructions,
  ) async {
    try {
      final summary = chunks.length == 1
          ? await _summarize(chunks.single, instructions)
          : await _summarizeInBlocks(chunks, instructions);

      _repository.setSummary(meetingId, summary, prompt: instructions);
      _status = const EchoSummaryStatus();
    } on EchoException catch (error) {
      _status = EchoSummaryStatus(errorMessage: error.message);
    } catch (error) {
      // Nada aqui roda sob uma tela: uma exceção não prevista escapando de um
      // `unawaited` derrubaria o engine que segura a gravação, o cronômetro e
      // a captura do clipboard. O resumo é a única coisa que pode falhar.
      _status = EchoSummaryStatus(errorMessage: 'O resumo falhou: $error');
    }
  }

  Future<String> _summarizeInBlocks(
    List<String> chunks,
    String instructions,
  ) async {
    final partials = <String>[];

    for (var index = 0; index < chunks.length; index++) {
      _status = EchoSummaryStatus(
        meetingId: _status.meetingId,
        done: index + 1,
        total: chunks.length,
      );
      partials.add(await _summarize(chunks[index], blockInstructions));
    }

    return _summarize(partials.join('\n\n'), instructions);
  }

  /// Uma chamada ao modelo, com a saída para o texto que não coube.
  ///
  /// O estouro de janela é o único erro que dá para resolver aqui: repartir o
  /// bloco ao meio e resumir as metades chega no mesmo lugar, só mais devagar.
  Future<String> _summarize(String text, String instructions) async {
    try {
      return await _channel.summarize(text: text, instructions: instructions);
    } on EchoException catch (error) {
      if (!error.isContextWindowExceeded || text.length < 500) rethrow;

      final halves = SummaryChunker.chunk(text, maxChars: text.length ~/ 2);
      final partials = <String>[];
      for (final half in halves) {
        partials.add(await _summarize(half, blockInstructions));
      }

      return _summarize(partials.join('\n\n'), instructions);
    }
  }
}

/// O mesmo pedido, feito de outra janela.
///
/// O Hub é quem tem a tela do resumo e é quem some no meio do trabalho — então
/// ele não faz o trabalho: manda fazer, e depois pergunta como vai. É o mesmo
/// arranjo dos outros serviços que precisam sobreviver a todas as janelas
/// fechadas, só que aqui o pedido vem de fora em vez de nascer no lugar certo.
///
/// [EchoSummaryHost] é o outro lado deste canal.
class WindowEchoSummaryRunner implements EchoSummaryRunner {
  const WindowEchoSummaryRunner();

  @override
  Future<void> start(int meetingId) async {
    await _invoke<void>('start', {'meetingId': meetingId});
  }

  @override
  Future<EchoSummaryStatus> status() async {
    final raw = await _invoke<Map<Object?, Object?>>('status');

    return raw == null ? const EchoSummaryStatus() : EchoSummaryStatus.fromMap(raw);
  }

  /// Falha de canal vira [EchoException] porque é assim que o resto do Echo
  /// conta um problema, e a tela já sabe mostrar isso. Calar seria pior que o
  /// erro: o botão "Resumir" ficaria clicável para sempre sem nunca resumir.
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await EchoSummaryHost.channel.invokeMethod<T>(method, arguments);
    } on WindowChannelException catch (error) {
      throw EchoException('summary_channel', _failure(error.message));
    } on MissingPluginException {
      throw EchoException('summary_channel', _failure('canal indisponível'));
    }
  }

  String _failure(String detail) =>
      'Não foi possível falar com o Evergreen que está rodando ao fundo, e é '
      'ele quem resume ($detail). Encerre e abra o aplicativo de novo.';
}

/// O lado que atende: registra o canal do resumo no engine da janela 0.
///
/// Unidirecional e registrado uma vez só, na inicialização. A alternativa —
/// canal nos dois sentidos, com o Hub também registrando para receber avisos —
/// esbarra no fato de o Hub ser destruído e recriado: o registro do engine
/// morto some por referência fraca, mas só quando ele é liberado, e um Hub
/// reaberto rápido demais encontraria o canal ainda ocupado. Perguntar de
/// tempos em tempos não tem esse problema, e é o Hub aberto quem pergunta.
abstract final class EchoSummaryHost {
  static const channel = WindowMethodChannel(
    'echo_summary',
    mode: ChannelMode.unidirectional,
  );

  static Future<void> register(EchoSummaryRunner runner) async {
    try {
      await channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'start':
            final arguments = call.arguments as Map<Object?, Object?>;
            await runner.start(arguments['meetingId']! as int);
            return null;
          case 'status':
            return (await runner.status()).toMap();
          default:
            throw MissingPluginException('echo_summary: ${call.method}');
        }
      });
    } on WindowChannelException {
      // Sem o canal, o Hub avisa que não conseguiu falar com o fundo — que é
      // melhor do que este engine não subir.
    } on MissingPluginException {
      // Em teste não há lado nativo, e o Hub de teste fala com o runner local
      // direto.
    }
  }
}

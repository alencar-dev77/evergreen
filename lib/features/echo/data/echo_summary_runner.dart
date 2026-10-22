import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import '../../../core/local_model/local_model.dart';
import '../../../core/local_model/local_model_gate.dart';
import '../../home/data/app_settings_repository.dart';
import '../models/echo_summary_status.dart';
import '../models/meeting.dart';
import '../models/meeting_segment.dart';
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

  /// Desiste do resumo em curso. Sem nada em curso, não faz nada.
  ///
  /// **Com o Apple Intelligence, desistir é entre blocos, não no meio de um.**
  /// A chamada ao modelo é uma só, do outro lado do canal, e o
  /// `FoundationModels` não a interrompe: o bloco que já está com ele termina e
  /// é descartado. O LM Studio larga o bloco no meio — a conexão é fechada.
  ///
  /// Nada é gravado: a reunião fica exatamente como estava, com o resumo antigo
  /// se havia um. Cancelar não é apagar.
  Future<void> cancel();
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
    required AppSettingsRepository appSettings,
    required LocalModelGate gate,
  }) : _repository = repository,
       _settings = settings,
       _appSettings = appSettings,
       _gate = gate;

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

  /// Quem disse o quê — a regra que vale para todo resumo, com ou sem nome.
  ///
  /// Sem vozes separadas, o Echo só sabe de qual faixa veio cada fala: o
  /// microfone é quem pediu, o áudio do computador é "Reunião", e ali pode
  /// haver cinco pessoas ou um vídeo do YouTube. Sem esta regra o modelo dá
  /// dono ao que não tem: num
  /// vídeo assistido em silêncio, com 62 falas da "Reunião" e uma só do
  /// microfone, o resumo saiu inteiro como "Lucas afirma…", "Lucas menciona…".
  /// Por isso o resumo fala do assunto, e nome só entra quando a própria
  /// conversa o diz.
  ///
  /// O "sem negrito" é porque o resumo é desenhado como texto puro: os `**`
  /// que o modelo põe por hábito apareciam na tela como asteriscos.
  static final attribution =
      'Escreva sobre o que foi dito, não sobre quem disse. As falas marcadas '
      '"${Speaker.others.label}:" vêm do áudio do computador e podem ser de várias pessoas '
      'ou de um vídeo: não as atribua a ninguém. Só cite o nome de alguém '
      'quando esse nome for dito na própria conversa. Não use negrito nem outra '
      'marcação.';

  /// A frase que apresenta a pessoa ao modelo — só quando ela falou.
  ///
  /// O rótulo da transcrição sozinho não basta: o modelo vê "Lucas: ..." e não
  /// tem como saber que Lucas é quem está pedindo o resumo — ele escreve sobre
  /// um participante qualquer, e volta a dizer "a pessoa" na hora de falar de
  /// quem lê. Mas apresentar alguém que não abriu a boca faz o contrário: o
  /// único nome do texto vira o dono de todas as falas. Por isso a frase
  /// também cerca o nome — ele só leva o que está nas falas marcadas com ele.
  /// Sem gênero de propósito: o Evergreen pede um nome, não um cadastro.
  static String presentation(String userName) =>
      'As falas marcadas "$userName:" são de quem pediu este resumo. Atribua a '
      '$userName só o que estiver nessas falas, chamando pelo nome, nunca de '
      '"você" nem de "a pessoa". Não escreva que $userName pediu o resumo.';

  /// A [attribution] de quando a reunião separou vozes — e é no lugar dela,
  /// não ao lado.
  ///
  /// Ao lado, as duas brigavam: uma dizia "não atribua o áudio do computador
  /// a ninguém", a outra deixava atribuir a "Pessoa 2" — e um modelo pequeno,
  /// diante de uma proibição seguida de uma exceção, escolhe um lado ao acaso.
  /// Com vozes separadas não sobra nenhuma fala "Reunião:" para a proibição
  /// alcançar, então quem fala do áudio do computador é só esta.
  ///
  /// Sem a frase do número, o modelo lê o rótulo como nome próprio e escreve
  /// "Pessoa 2 é a gerente do projeto", ou casa o número com um nome dito na
  /// conversa. Os números são palpite de timbre, e por isso entram só onde
  /// distinguir pessoas é o conteúdo — quem ficou com a tarefa, quem
  /// discordou de quem. O "mantenha ao lado" é para os resumos de bloco: eles
  /// preservam "nomes próprios", e "Pessoa 2" não é um, então sem o pedido o
  /// rótulo sumia no bloco e o passo final não tinha mais de onde tirá-lo.
  static String voicesAttribution(int count) =>
      'Escreva sobre o que foi dito, não sobre quem disse. As falas marcadas '
      '"${Speaker.voiceLabel(1)}:", "${Speaker.voiceLabel(2)}:" e assim por '
      'diante são $count vozes diferentes do áudio do computador, separadas '
      'pelo timbre. O número não é nome: não tente descobrir quem são. Só '
      'escreva "${Speaker.voiceLabel(1)}" ou "${Speaker.voiceLabel(2)}" quando '
      'for preciso distinguir quem ficou com uma tarefa ou quem discordou de '
      'quem, e mantenha o rótulo ao lado dessa tarefa ou dessa discordância. '
      'Só cite o nome de alguém quando esse nome for dito na própria conversa. '
      'Não use negrito nem outra marcação.';

  /// As regras que vão junto de qualquer instrução, para [meeting].
  static String rulesFor(Meeting meeting, String userName) {
    final spoke = meeting.segments.any(
      (segment) => segment.speaker == Speaker.me,
    );
    final voiceCount = meeting.voiceCount;

    return [
      voiceCount >= 2 ? voicesAttribution(voiceCount) : attribution,
      if (spoke && userName.isNotEmpty) presentation(userName),
    ].join(' ');
  }

  final EchoRepository _repository;
  final EchoSettingsRepository _settings;
  final AppSettingsRepository _appSettings;
  final LocalModelGate _gate;

  /// O teto de cada resposta do modelo.
  ///
  /// Um resumo de reunião cabe folgado; um modelo pequeno às vezes não para de
  /// gerar, e sem teto ele escreveria até a janela acabar. O Apple
  /// Intelligence não recebe o teto — ver `AppleLocalModel`.
  static const maxAnswerTokens = 1500;

  EchoSummaryStatus _status = const EchoSummaryStatus();

  /// Qual resumo é o de agora.
  ///
  /// Cancelar não interrompe o `await` que está de pé — ele incrementa este
  /// número, e o trabalho que voltar com um número velho se descobre demitido e
  /// sai sem gravar nada. É mais simples e mais seguro que um sinalizador
  /// booleano: entre o cancelamento e o retorno do bloco, a pessoa pode ter
  /// pedido um resumo novo, e o antigo não pode confundir o dela com o seu.
  int _generation = 0;

  /// O aviso de desistência do resumo de agora — o que deixa o LM Studio
  /// largar o bloco no meio em vez de terminá-lo para ninguém.
  LocalModelCancellation? _cancellation;

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
  Future<void> cancel() async {
    if (!_status.isRunning) return;

    _generation++;
    _cancellation?.cancel();
    // A tela precisa parar de mostrar "Resumindo…" agora, e não quando o bloco
    // em curso voltar do modelo — que é o que a pessoa acabou de dizer que não
    // quer mais esperar.
    _status = const EchoSummaryStatus();
  }

  @override
  Future<void> start(int meetingId) async {
    if (_status.isRunning) return;

    final meeting = _repository.findById(meetingId);
    if (meeting == null || meeting.isEmpty) return;

    // A instrução mora no Hub, em outro engine: sem reler, o resumo sai com a
    // instrução de ontem. É a mesma armadilha que a gravação já tinha — e o
    // nome, que também é escrito lá, cai nela do mesmo jeito.
    await _settings.reload();
    await _appSettings.reload();

    final userName = _appSettings.load().userName;
    final written = _settings.load().resolvedSummaryInstructions;
    final rules = rulesFor(meeting, userName);
    final prompts = _Prompts(
      written: written,
      finalStep: '$written\n\n$rules',
      block: '$blockInstructions $rules',
    );

    final text = meeting.plainText(userName: userName);
    if (text.trim().isEmpty) return;

    // Um bloco até a sessão abrir: quantos blocos são depende da janela do
    // modelo, e só se sabe a janela com o modelo carregado.
    _status = EchoSummaryStatus(meetingId: meetingId, total: 1);
    final cancellation = _cancellation = LocalModelCancellation();
    unawaited(_run(meetingId, text, prompts, ++_generation, cancellation));
  }

  /// Este trabalho ainda é o trabalho de agora?
  bool _isCurrent(int generation) => generation == _generation;

  /// Em dois passos quando o texto não cabe de uma vez: cada bloco vira um
  /// resumo neutro, e o passo final junta os resumos aplicando a instrução que
  /// a pessoa escreveu. Com um bloco só, o passo final é o único que existe.
  ///
  /// Tudo dentro de **um** pedido ao portão: o modelo é carregado uma vez para
  /// a reunião inteira e descarregado depois do passo final, nunca a cada
  /// bloco.
  Future<void> _run(
    int meetingId,
    String text,
    _Prompts prompts,
    int generation,
    LocalModelCancellation cancellation,
  ) async {
    try {
      final (summary, model) = await _gate.run((session) async {
        if (!_isCurrent(generation)) throw const _Cancelled();

        final job = _Job(session, prompts, generation, cancellation);
        final chunks = SummaryChunker.chunk(
          text,
          maxChars: SummaryChunker.maxCharsFor(session.contextTokens),
        );
        _status = EchoSummaryStatus(meetingId: meetingId, total: chunks.length);

        final summary = chunks.length == 1
            ? await _summarize(chunks.single, prompts.finalStep, job)
            : await _summarizeInBlocks(chunks, job);

        return (summary, session.displayName);
      });

      // Resposta vazia não é resumo: um modelo que gastou o teto pensando
      // devolve nada, e gravar nada apagaria o resumo que já existia.
      if (summary.trim().isEmpty) {
        throw const LocalModelException(
          LocalModelException.failed,
          'O modelo não escreveu nada. Tente outro modelo ou resuma de novo.',
        );
      }

      // Grava a instrução que a pessoa escolheu, não as regras do aplicativo:
      // a tela a mostra como "Instrução deste resumo" para ser copiada de
      // volta às preferências, e as regras iriam junto, dobradas.
      _repository.setSummary(
        meetingId,
        summary,
        prompt: prompts.written,
        model: model,
      );
      _status = const EchoSummaryStatus();
    } on _Cancelled {
      // Nada a gravar e nada a dizer: o `cancel` já limpou o estado, e a pessoa
      // sabe o que pediu. Um aviso de "cancelado" seria o aplicativo repetindo
      // de volta o próprio clique dela.
      return;
    } on LocalModelException catch (error) {
      if (!_isCurrent(generation)) return;
      _status = EchoSummaryStatus(errorMessage: error.message);
    } catch (error) {
      // Nada aqui roda sob uma tela: uma exceção não prevista escapando de um
      // `unawaited` derrubaria o engine que segura a gravação, o cronômetro e
      // a captura do clipboard. O resumo é a única coisa que pode falhar.
      // O pedido que o cancelamento interrompeu também cai aqui, e sai calado.
      if (!_isCurrent(generation)) return;
      _status = EchoSummaryStatus(errorMessage: 'O resumo falhou: $error');
    }
  }

  Future<String> _summarizeInBlocks(List<String> chunks, _Job job) async {
    final partials = <String>[];

    for (var index = 0; index < chunks.length; index++) {
      // A checagem vem antes de anunciar o bloco: sem ela, um resumo cancelado
      // continuaria escrevendo "bloco 4 de 12" por cima do estado limpo, e a
      // tela voltaria a dizer que está resumindo.
      if (!_isCurrent(job.generation)) throw const _Cancelled();

      _status = EchoSummaryStatus(
        meetingId: _status.meetingId,
        done: index + 1,
        total: chunks.length,
      );
      partials.add(await _summarize(chunks[index], job.prompts.block, job));
    }

    return _summarize(partials.join('\n\n'), job.prompts.finalStep, job);
  }

  /// Uma chamada ao modelo, com a saída para o texto que não coube.
  ///
  /// O estouro de janela é o único erro que dá para resolver aqui: repartir o
  /// bloco ao meio e resumir as metades chega no mesmo lugar, só mais devagar.
  Future<String> _summarize(String text, String instructions, _Job job) async {
    if (!_isCurrent(job.generation)) throw const _Cancelled();

    final String answer;
    try {
      answer = await job.session.generate(
        text: text,
        instructions: instructions,
        maxTokens: maxAnswerTokens,
        cancellation: job.cancellation,
      );
    } on LocalModelException catch (error) {
      if (!error.isContextWindowExceeded || text.length < 500) rethrow;

      final halves = SummaryChunker.chunk(text, maxChars: text.length ~/ 2);
      final partials = <String>[];
      for (final half in halves) {
        partials.add(await _summarize(half, job.prompts.block, job));
      }

      return _summarize(partials.join('\n\n'), instructions, job);
    }

    // De novo na volta: o bloco levou minutos com o modelo, e é justamente
    // nesse intervalo que a desistência acontece.
    if (!_isCurrent(job.generation)) throw const _Cancelled();

    return answer;
  }
}

/// O que acompanha cada chamada de um resumo: a sessão aberta, as instruções e
/// como saber se ele ainda é o de agora.
class _Job {
  const _Job(this.session, this.prompts, this.generation, this.cancellation);

  final LocalModelSession session;
  final _Prompts prompts;
  final int generation;
  final LocalModelCancellation cancellation;
}

/// As instruções de um resumo: a que a pessoa escreveu, e as duas que vão de
/// fato ao modelo — a do passo final e a dos blocos, ambas com as regras de
/// quem disse o quê.
class _Prompts {
  const _Prompts({
    required this.written,
    required this.finalStep,
    required this.block,
  });

  final String written;
  final String finalStep;
  final String block;
}

/// A desistência, subindo pela pilha do trabalho até quem sabe descartá-lo.
///
/// Privada e sem mensagem: ela nunca chega a uma tela — quem a captura é o
/// [LocalEchoSummaryRunner._run], que sai calado. Não é um [LocalModelException]
/// porque não é uma falha: a diferença entre "não deu" e "não quis" é toda a
/// diferença para quem está olhando.
class _Cancelled implements Exception {
  const _Cancelled();
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

    return raw == null
        ? const EchoSummaryStatus()
        : EchoSummaryStatus.fromMap(raw);
  }

  @override
  Future<void> cancel() async => _invoke<void>('cancel');

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
          case 'cancel':
            await runner.cancel();
            return null;
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

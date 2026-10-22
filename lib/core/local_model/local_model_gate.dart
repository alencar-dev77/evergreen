import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import '../diagnostics/app_log.dart';
import 'local_model.dart';

/// A única porta para o modelo local — e ela mora na janela 0.
///
/// **Uma por aplicativo**, e é por isso que existe. O resumo do Echo roda na
/// janela 0 e o parágrafo do Track é pedido do Hub, que é outro engine: se
/// cada um carregasse e descarregasse por conta própria, o Track terminaria,
/// descarregaria o modelo e mataria o resumo do Echo no meio.
///
/// **Um pedido por vez.** O modelo é aberto uma vez para tudo o que estiver na
/// fila e fechado quando ela esvazia: num resumo em blocos isso acontece
/// depois do último bloco, nunca a cada um. Fechar só devolve a memória que a
/// própria sessão ocupou — ver [LocalModelSession.close].
class LocalModelGate implements LocalModelClient {
  LocalModelGate({
    required Future<LocalModelChoice> Function() choice,
    required LocalModelBackend Function(LocalModelSource source) backendFor,
    this.idleGrace = Duration.zero,
  }) : _choice = choice,
       _backendFor = backendFor;

  final Future<LocalModelChoice> Function() _choice;
  final LocalModelBackend Function(LocalModelSource source) _backendFor;

  /// Quanto a sessão espera, com a fila vazia, antes de devolver a memória.
  ///
  /// Quem passeia pelos dias do Track pede um parágrafo por clique, e sem
  /// folga cada clique carregaria e descarregaria 3 GB. Com ela, os pedidos
  /// que chegam em sequência reaproveitam o modelo, e ele sai da memória
  /// pouco depois do último. Zero é fechar na hora — o que os testes usam.
  final Duration idleGrace;

  Future<void> _tail = Future.value();
  int _pending = 0;
  LocalModelSession? _session;
  LocalModelChoice? _sessionChoice;
  Timer? _idle;

  /// Põe [work] na fila e devolve o que ele devolver.
  ///
  /// A sessão que [work] recebe vale só durante ele: guardá-la para depois é
  /// usar um modelo que pode já ter saído da memória.
  Future<T> run<T>(Future<T> Function(LocalModelSession session) work) {
    _pending++;
    _idle?.cancel();
    final result = _tail.then((_) => _execute(work));
    // A fila anda mesmo quando um pedido falha: o erro é de quem pediu.
    _tail = result.then<void>((_) {}, onError: (Object _) {});

    return result;
  }

  Future<T> _execute<T>(
    Future<T> Function(LocalModelSession session) work,
  ) async {
    try {
      return await work(await _sessionFor(await _choice()));
    } on LocalModelException catch (error) {
      // O que é fluxo não vai ao registro: o servidor desligado e o texto que
      // não coube acontecem toda hora e já têm tratamento. O resto — prazo,
      // recusa, LM Studio antigo — é o que se procura num diagnóstico. Só o
      // código: a mensagem é nossa, mas o código basta.
      if (error.code != LocalModelException.unsupported &&
          !error.isContextWindowExceeded) {
        AppLog.info('local_model', 'falhou: ${error.code}');
      }
      rethrow;
    } finally {
      _pending--;
      if (_pending == 0) await _release();
    }
  }

  /// A sessão aberta, se ela ainda é do modelo escolhido; senão, uma nova.
  ///
  /// A escolha é lida a cada pedido: ela é gravada no Hub, e a janela 0 só a
  /// vê relendo o disco. Trocar de modelo durante a folga fecha o anterior.
  Future<LocalModelSession> _sessionFor(LocalModelChoice choice) async {
    final open = _session;
    if (open != null && _sessionChoice == choice) return open;

    await _close();
    final session = await _backendFor(choice.source).open(choice);
    _session = session;
    _sessionChoice = choice;

    return session;
  }

  Future<void> _release() async {
    if (idleGrace == Duration.zero) {
      await _close();
      return;
    }

    _idle = Timer(idleGrace, () {
      // Pela fila, para não fechar debaixo de um pedido que acabou de entrar.
      _tail = _tail.then((_) async {
        if (_pending == 0) await _close();
      });
    });
  }

  /// Para o relógio da folga. A sessão aberta fica: quem sai é o
  /// aplicativo, e o que ele deixar no LM Studio a varredura da próxima
  /// abertura tira.
  void dispose() => _idle?.cancel();

  Future<void> _close() async {
    final session = _session;
    _session = null;
    _sessionChoice = null;
    await session?.close();
  }

  @override
  Future<LocalModelAnswer> answer({
    required String text,
    required String instructions,
    required int maxTokens,
  }) {
    return run((session) async {
      final written = await session.generate(
        text: text,
        instructions: instructions,
        maxTokens: maxTokens,
      );

      return LocalModelAnswer(text: written, model: session.displayName);
    });
  }
}

/// O mesmo pedido, feito do Hub.
///
/// Fechar o Hub no meio não deixa o modelo preso: quem segura a sessão é o
/// portão, na janela 0, e ele a fecha quando a fila esvazia — tenha alguém
/// esperando a resposta ou não.
class WindowLocalModelClient implements LocalModelClient {
  const WindowLocalModelClient();

  @override
  Future<LocalModelAnswer> answer({
    required String text,
    required String instructions,
    required int maxTokens,
  }) async {
    final Map<Object?, Object?>? raw;
    try {
      raw = await LocalModelHost.channel.invokeMethod<Map<Object?, Object?>>(
        'answer',
        {'text': text, 'instructions': instructions, 'maxTokens': maxTokens},
      );
    } on WindowChannelException {
      throw _unreachable;
    } on MissingPluginException {
      throw _unreachable;
    }

    if (raw == null) throw _unreachable;
    final code = raw['error'];
    if (code is String) {
      throw LocalModelException(code, raw['message'] as String? ?? '');
    }

    return LocalModelAnswer.fromMap(raw);
  }

  static const _unreachable = LocalModelException(
    LocalModelException.unsupported,
    'Não foi possível falar com o Evergreen que está rodando ao fundo.',
  );
}

/// O lado que atende: registra o canal do modelo local na janela 0.
///
/// Unidirecional e registrado uma vez só — o arranjo (e as razões) do
/// `EchoSummaryHost`. A falha volta como dado, e não como exceção, para o Hub
/// saber o código e não só que "deu errado".
abstract final class LocalModelHost {
  static const channel = WindowMethodChannel(
    'local_model',
    mode: ChannelMode.unidirectional,
  );

  static Future<void> register(LocalModelClient client) async {
    try {
      await channel.setMethodCallHandler((call) async {
        if (call.method != 'answer') {
          throw MissingPluginException('local_model: ${call.method}');
        }

        final arguments = call.arguments as Map<Object?, Object?>;
        try {
          final answer = await client.answer(
            text: arguments['text']! as String,
            instructions: arguments['instructions']! as String,
            maxTokens: arguments['maxTokens']! as int,
          );
          return answer.toMap();
        } on LocalModelException catch (error) {
          return {'error': error.code, 'message': error.message};
        } catch (_) {
          return {
            'error': LocalModelException.failed,
            'message': 'O modelo local falhou.',
          };
        }
      });
    } on WindowChannelException {
      // Sem canal, o Track fica sem parágrafo — que é o que ele faz sempre que
      // o modelo não responde.
    } on MissingPluginException {
      // Em teste não há lado nativo.
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:sqlite3/sqlite3.dart';

import 'log_store.dart';

/// O registro de erros do Evergreen.
///
/// **Nenhum conteúdo de quem usa entra aqui**: nada do que passou pela área de
/// transferência (senha inclusive), texto do Leaf, transcrição do Echo, nome de
/// arquivo do Nest. Só o que aconteceu, onde e de que tipo foi o erro — a mesma
/// régua do Track. Quem garante isso é [describe], e não quem chama: o erro
/// chega de qualquer lugar, e cada chamador lembrar da regra é o jeito de um
/// dia alguém esquecer.
///
/// Estático, e não provider, porque quem registra está em todo canto — o
/// handler de erro do isolate, o `_invoke` de cada canal nativo —, e boa parte
/// desses lugares não tem um `ref` à mão. Antes do [attach] (e em todo teste
/// que não o chame), registrar não faz nada.
abstract final class AppLog {
  static LogStore? _store;
  static String _engine = '';
  static DateTime Function() _now = DateTime.now;

  /// A última linha escrita, sem o carimbo, e quantas vezes ela se repetiu
  /// desde então. Ver [_write].
  static String? _lastLine;
  static int _repeats = 0;

  /// Liga o registro neste engine. Chamado no `main`, de cada janela.
  static void attach(
    LogStore store, {
    required String engine,
    DateTime Function()? clock,
  }) {
    _store = store;
    _engine = engine;
    _now = clock ?? DateTime.now;
    _lastLine = null;
    _repeats = 0;
  }

  /// Desliga o registro — para os testes não deixarem um ligado para o
  /// seguinte.
  @visibleForTesting
  static void detach() {
    _store = null;
    _engine = '';
    _now = DateTime.now;
    _lastLine = null;
    _repeats = 0;
  }

  /// Um acontecimento: [message] é texto do próprio app, nunca dado de
  /// alguém.
  static void info(String source, String message) =>
      _write('INFO', source, message);

  /// Um erro, com a pilha quando houver.
  static void error(String source, Object error, [StackTrace? stack]) {
    final frames = stack == null ? '' : _frames(stack);
    _write('ERRO', source, '${describe(error)}$frames');
  }

  /// Um canal nativo que recusou uma chamada. Vai o método e o código do
  /// erro; a mensagem e os detalhes, não — são do lado nativo, e é por eles
  /// que um caminho de arquivo ou um texto chegaria aqui.
  static void channelError(String channel, String method, Object error) =>
      _write('AVISO', channel, '$method: ${describe(error)}');

  /// Como um erro é escrito no registro, sem nada de quem usa.
  ///
  /// Os tipos que carregam dado no `toString` são tratados um a um — é lá
  /// que mora o vazamento, e uma regra genérica não o alcança:
  /// - `SqliteException` imprime os **parâmetros** da instrução, e o
  ///   parâmetro de uma escrita do Pin é o texto copiado;
  /// - `FileSystemException` imprime o caminho, e o `copy`/`rename` ainda põe
  ///   o destino dentro da mensagem — num arquivo do Nest, o nome dele. Vai
  ///   só o começo da mensagem, antes do primeiro caminho, e o errno;
  /// - `PlatformException` traz a mensagem e os detalhes do lado nativo;
  /// - `FormatException` imprime o texto que não conseguiu ler;
  /// - `ProviderException` embrulha o erro de verdade, que é descrito por
  ///   esta mesma regra.
  ///
  /// `TypeError`, `NoSuchMethodError` e o erro de `late` falam de **código**
  /// — nome de tipo, de método, de campo —, e perder isso para o filtro de
  /// aspas tiraria do registro o que ele tem de útil. Vai a primeira linha: a
  /// do `NoSuchMethodError` que vem depois é o valor de quem recebeu a
  /// chamada, e esse é dado.
  ///
  /// O resto vai pela primeira linha do `toString`, passada pelo [redact].
  static String describe(Object error) => switch (error) {
    ProviderException(:final exception) => describe(exception),
    PlatformException(:final code) => 'PlatformException($code)',
    SqliteException(:final extendedResultCode, :final message) =>
      'SqliteException($extendedResultCode): ${redact(message)}',
    FileSystemException(:final message, :final osError) =>
      'FileSystemException: ${_beforeValue(message)}'
          '${osError == null ? '' : ' (errno ${osError.errorCode})'}',
    FormatException(:final message) => 'FormatException: ${redact(message)}',
    TypeError() || NoSuchMethodError() => _code(error),
    _ when '$error'.startsWith('LateInitializationError') => _code(error),
    _ => '${error.runtimeType}: ${redact(_firstLine('$error'))}',
  };

  /// Aspas de todo tipo, **gulosas**: da primeira à última da linha. Um nome
  /// de arquivo com apóstrofo fecharia uma regra que parasse na aspa seguinte
  /// no meio do nome, e o resto vazaria. Apagar demais é o erro certo para
  /// este lado.
  static final _quoted = RegExp(
    '"[^\\n]*"|\'[^\\n]*\'|“[^\\n]*”|‘[^\\n]*’',
  );
  static final _url = RegExp(r'[a-zA-Z][a-zA-Z0-9+.-]*://\S+');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _path = RegExp(r'(?:~|/(?:Users|Volumes|private|var|tmp))/\S*');
  static final _number = RegExp(r'\d[\d.\-/ ]{4,}\d');

  /// Onde começa o primeiro valor de uma mensagem de arquivo: aspa, dois
  /// pontos ou caminho.
  static final _valueStart = RegExp('[\'":/~“‘]');

  /// Tira de uma mensagem o que tem cara de dado: texto entre aspas, link,
  /// e-mail, caminho de arquivo e número longo (CPF, telefone, cartão). E
  /// corta no tamanho de uma linha.
  ///
  /// É a segunda rede, não a primeira: o que sabidamente carrega dado já foi
  /// separado por tipo em [describe]. Esta pega o que um erro qualquer
  /// resolver citar na mensagem — `StateError('falhou ao ler "…"')`.
  static String redact(String message) =>
      _cut(_values(message.replaceAll(_quoted, '‹…›')));

  static String _values(String text) => text
      .replaceAll(_url, '‹link›')
      .replaceAll(_email, '‹e-mail›')
      .replaceAll(_path, '‹caminho›')
      .replaceAll(_number, '‹número›');

  static String _cut(String text) =>
      text.length <= 240 ? text : '${text.substring(0, 240)}…';

  /// A primeira linha de um erro que só fala de código, sem o filtro de
  /// aspas — mas com o de link, caminho e número, de cinto.
  static String _code(Object error) =>
      '${error.runtimeType}: ${_cut(_values(_firstLine('$error')))}';

  /// "Cannot copy file to '/Users/…'" → "Cannot copy file to".
  static String _beforeValue(String message) {
    final end = message.indexOf(_valueStart);
    final head = end < 0 ? message : message.substring(0, end);
    return _cut(head.trim());
  }

  static String _firstLine(String text) {
    final end = text.indexOf('\n');
    return end < 0 ? text : text.substring(0, end);
  }

  /// As primeiras linhas da pilha, recuadas. A pilha é endereço de código —
  /// arquivo e linha do Evergreen ou do Flutter —, não dado de ninguém.
  static String _frames(StackTrace stack) {
    final lines = '$stack'
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(12);

    return lines.map((line) => '\n    $line').join();
  }

  static void _write(String level, String source, String message) {
    final store = _store;
    if (store == null) return;

    // Um erro de build se repete a cada quadro, e sessenta pilhas iguais por
    // segundo encheriam o disco e travariam a interface escrevendo. A linha
    // igual à anterior não é escrita; a contagem vai ao registro em 10, 100,
    // 1000… vezes, e uma última vez quando outra linha chega.
    final line = '[$_engine] $level $source: $message';
    if (line == _lastLine) {
      _repeats++;
      if (_isPowerOfTen(_repeats)) _append(store, _repeatedLine());
      return;
    }

    if (_repeats > 0 && !_isPowerOfTen(_repeats)) {
      _append(store, _repeatedLine());
    }
    _lastLine = line;
    _repeats = 0;
    _append(store, line);
  }

  static String _repeatedLine() =>
      '[$_engine] INFO registro: a linha anterior se repetiu $_repeats vezes';

  static bool _isPowerOfTen(int value) {
    if (value < 10) return false;
    var n = value;
    while (n % 10 == 0) {
      n ~/= 10;
    }
    return n == 1;
  }

  static void _append(LogStore store, String line) =>
      store.append('${_now().toIso8601String()} $line\n');
}

/// Liga o registro aos dois caminhos de erro não tratado do Flutter.
///
/// Encadeia com o que já estava instalado — o `KeyboardStateGuard` engole um
/// assert conhecido do teclado, e esse assert continua sem ir ao registro: ele
/// é ruído do embedder, não erro do Evergreen. O comportamento de antes
/// (imprimir, parar no depurador) segue igual; o registro só acrescenta a
/// linha.
abstract final class ErrorCapture {
  /// Chamado no `main` de cada engine, depois do `KeyboardStateGuard.install`.
  static void install({required bool Function(Object error) isIgnored}) {
    final dispatcher = PlatformDispatcher.instance;
    final previousIsolate = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      final handled = previousIsolate?.call(error, stack) ?? false;
      _record(isIgnored, 'isolate', error, stack);
      return handled;
    };

    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutter?.call(details);
      _record(
        isIgnored,
        'flutter${details.library == null ? '' : ' (${details.library})'}',
        details.exception,
        details.stack,
      );
    };
  }

  /// Registrar vem **depois** do handler de antes, e nunca lança: um
  /// `toString` que quebre dentro do [AppLog.describe] não pode esconder o
  /// erro original de quem já o mostrava.
  static void _record(
    bool Function(Object error) isIgnored,
    String source,
    Object error,
    StackTrace? stack,
  ) {
    try {
      if (!isIgnored(error)) AppLog.error(source, error, stack);
    } on Object {
      // O registro é o que pode falhar aqui sem custo.
    }
  }
}

import 'dart:io';
import 'dart:ui' show ErrorCallback;

import 'package:evergreen/core/diagnostics/app_log.dart';
import 'package:evergreen/core/diagnostics/log_store.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/pin/data/clipboard_repository.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// O registro em memória, para ler o que foi escrito.
class _MemoryLogStore implements LogStore {
  final buffer = StringBuffer();

  @override
  void append(String text) => buffer.write(text);

  @override
  Future<List<String>> tail(int count) async => '$buffer'.split('\n');

  @override
  Future<void> reveal() async {}

  @override
  String get directoryLabel => '';
}

class _Broken {
  @override
  String toString() => throw StateError('toString quebrado');
}

void main() {
  late _MemoryLogStore store;

  setUp(() {
    store = _MemoryLogStore();
    AppLog.attach(
      store,
      engine: 'overlay',
      clock: () => DateTime(2026, 10, 17, 9, 30),
    );
  });

  tearDown(AppLog.detach);

  /// A regra que não se negocia: o que o Pin capturou não vai ao registro.
  ///
  /// Pelo caminho de verdade, e não por uma exceção montada à mão: o
  /// repositório do Pin sobre um SQLite real, com a escrita recusada no meio.
  /// O `SqliteException` que sai dali traz o texto copiado nos parâmetros da
  /// instrução — o teste confere isso primeiro, senão ele passaria por não
  /// ter o que vazar.
  test('um item do Pin capturado não aparece no registro', () {
    const secret = 'senha do banco: Xk9#mPz2-correto';

    final database = sqlite3.openInMemory();
    addTearDown(database.close);
    AppDatabase.migrate(database);
    database.execute('''
      CREATE TRIGGER recusa BEFORE INSERT ON clipboard_items
      BEGIN SELECT RAISE(ABORT, 'disco cheio'); END;
    ''');

    Object? failure;
    StackTrace? stack;
    try {
      SqliteClipboardRepository(database).upsert(ClipboardItem.capture(secret));
    } on Object catch (error, trace) {
      failure = error;
      stack = trace;
    }

    expect(failure, isA<SqliteException>());
    expect('$failure', contains(secret), reason: 'o erro cru vaza o conteúdo');

    // Pelos dois caminhos por onde ele chegaria: o handler de erro não tratado
    // e um chamador que registra o que apanhou.
    AppLog.error('isolate', failure!, stack);
    AppLog.channelError('pin', 'upsert', failure);

    final log = '${store.buffer}';
    // O ramo por tipo, e não o genérico: é ele que separa a mensagem dos
    // parâmetros, e o código do erro só aparece nele.
    expect(log, contains(RegExp(r'SqliteException\(\d+\)')));
    expect(log, isNot(contains(secret)));
    expect(log, isNot(contains('Xk9')));
  });

  group('describe', () {
    test('canal nativo: só o código', () {
      final text = AppLog.describe(
        PlatformException(
          code: 'move_failed',
          message: 'Não deu para mover /Users/ana/Recibos/IR 2026.pdf',
          details: {'path': '/Users/ana/Recibos/IR 2026.pdf'},
        ),
      );

      expect(text, 'PlatformException(move_failed)');
    });

    test('arquivo: o motivo, nunca o caminho', () {
      final text = AppLog.describe(
        const FileSystemException(
          'Cannot open file',
          '/Users/ana/Recibos/IR 2026.pdf',
          OSError('Permission denied', 13),
        ),
      );

      expect(text, 'FileSystemException: Cannot open file (errno 13)');
    });

    test('FormatException: sem o texto que não conseguiu ler', () {
      final text = AppLog.describe(
        const FormatException('JSON inválido', '{"nota": "segredo"}'),
      );

      expect(text, 'FormatException: JSON inválido');
    });

    test('erro qualquer: aspas, link, e-mail, caminho e número saem', () {
      final text = AppLog.describe(
        StateError(
          'falhou com "minha anotação" de ana@exemplo.com em '
          'https://exemplo.com/x?token=1 lendo /Users/ana/a.txt, cpf 123.456.789-09',
        ),
      );

      expect(text, startsWith('StateError: '));
      for (final leak in [
        'minha anotação',
        'ana@exemplo.com',
        'token=1',
        '/Users/ana',
        '123.456.789-09',
      ]) {
        expect(text, isNot(contains(leak)));
      }
    });

    test('arquivo copiado com apóstrofo no nome: o destino não vaza', () {
      final text = AppLog.describe(
        const FileSystemException(
          "Cannot copy file to '/Users/ana/Nest/Lucas's salário 2026.pdf'",
          '/Users/ana/Downloads/a.pdf',
          OSError('No space left on device', 28),
        ),
      );

      expect(text, 'FileSystemException: Cannot copy file to (errno 28)');
    });

    test('aspas escapadas e apóstrofo não abrem buraco', () {
      final text = AppLog.describe(
        ArgumentError.value('minha "senha" forte', 'texto'),
      );

      expect(text, isNot(contains('senha')));
      expect(text, isNot(contains('forte')));
    });

    test('erro de tipo continua legível: ele fala de código', () {
      Object? failure;
      try {
        (Object() as dynamic) as String;
      } on Object catch (error) {
        failure = error;
      }

      final text = AppLog.describe(failure!);
      expect(text, contains("'Object'"));
      expect(text, contains("'String'"));
    });

    test('NoSuchMethodError: o método, nunca quem recebeu', () {
      Object? failure;
      try {
        ('conteúdo secreto' as dynamic).metodoQueNaoExiste();
      } on Object catch (error) {
        failure = error;
      }

      final text = AppLog.describe(failure!);
      expect(text, contains('metodoQueNaoExiste'));
      expect(text, isNot(contains('conteúdo secreto')));
    });

    test('erro do riverpod é descrito pelo erro de dentro', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final failing = Provider<int>(
        (ref) => throw const FileSystemException(
          'Cannot open file',
          '/Users/ana/segredo.txt',
        ),
      );

      Object? failure;
      try {
        container.read(failing);
      } on Object catch (error) {
        failure = error;
      }

      expect(failure, isA<ProviderException>());
      expect(
        AppLog.describe(failure!),
        'FileSystemException: Cannot open file',
      );
    });

    test('só a primeira linha da mensagem', () {
      final text = AppLog.describe(Exception('resumo\nconteúdo da linha 2'));

      expect(text, isNot(contains('linha 2')));
    });
  });

  test('a linha diz quando, em qual engine, o nível e de onde', () {
    AppLog.info('início', 'Evergreen 1.0');
    AppLog.error(
      'flutter',
      StateError('quebrou'),
      StackTrace.fromString('#0 a'),
    );

    expect(
      '${store.buffer}',
      '2026-10-17T09:30:00.000 [overlay] INFO início: Evergreen 1.0\n'
          '2026-10-17T09:30:00.000 [overlay] ERRO flutter: StateError: Bad state: quebrou\n'
          '    #0 a\n',
    );
  });

  test('a mesma linha repetida não enche o registro', () {
    for (var i = 0; i < 250; i++) {
      AppLog.error('flutter', StateError('a cada quadro'));
    }
    AppLog.info('início', 'outra coisa');

    final lines = '${store.buffer}'.trim().split('\n');
    expect(lines.where((line) => line.contains('a cada quadro')), hasLength(1));
    expect(
      lines
          .where((line) => line.contains('se repetiu'))
          .map((line) => line.substring(line.indexOf('se repetiu'))),
      ['se repetiu 10 vezes', 'se repetiu 100 vezes', 'se repetiu 249 vezes'],
    );
    expect(lines.last, contains('outra coisa'));
  });

  test('sem attach, registrar não faz nada', () {
    AppLog.detach();
    AppLog.error('isolate', StateError('x'));

    expect('${store.buffer}', isEmpty);
  });

  group('ErrorCapture', () {
    late ErrorCallback? previousIsolate;
    late FlutterExceptionHandler? previousFlutter;

    setUp(() {
      previousIsolate = PlatformDispatcher.instance.onError;
      previousFlutter = FlutterError.onError;
    });

    tearDown(() {
      PlatformDispatcher.instance.onError = previousIsolate;
      FlutterError.onError = previousFlutter;
    });

    test('erro não tratado vai ao registro, e o ignorado não', () {
      var downstream = 0;
      FlutterError.onError = (_) => downstream++;
      PlatformDispatcher.instance.onError = (_, _) => false;

      ErrorCapture.install(isIgnored: (error) => error is AssertionError);

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('do Flutter')),
      );
      FlutterError.onError!(FlutterErrorDetails(exception: AssertionError()));
      final handled = PlatformDispatcher.instance.onError!(
        StateError('do isolate'),
        StackTrace.empty,
      );

      final log = '${store.buffer}';
      expect(log, contains('do Flutter'));
      expect(log, contains('do isolate'));
      expect(log, isNot(contains('AssertionError')));
      // O que estava instalado antes continua recebendo tudo.
      expect(downstream, 2);
      expect(handled, isFalse);
    });

    test('preserva o "tratado" de quem estava antes', () {
      PlatformDispatcher.instance.onError = (_, _) => true;
      ErrorCapture.install(isIgnored: (_) => false);

      expect(
        PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty),
        isTrue,
      );
    });

    test('sem handler antes, registra e diz que não tratou', () {
      PlatformDispatcher.instance.onError = null;
      FlutterError.onError = null;
      ErrorCapture.install(isIgnored: (_) => false);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('sozinho'),
        StackTrace.empty,
      );
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('só')));

      expect(handled, isFalse);
      expect('${store.buffer}', contains('sozinho'));
      expect('${store.buffer}', contains('Bad state: só'));
    });

    test('um toString que quebra não derruba o handler', () {
      var downstream = 0;
      FlutterError.onError = (_) => downstream++;
      ErrorCapture.install(isIgnored: (_) => false);

      FlutterError.onError!(FlutterErrorDetails(exception: _Broken()));

      expect(downstream, 1);
    });
  });
}

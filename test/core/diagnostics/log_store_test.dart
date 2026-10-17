import 'dart:io';

import 'package:evergreen/core/diagnostics/log_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// O registro em disco de verdade — fora do binding de widget, onde a leitura
/// de arquivo responde.
void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('evergreen-log'));
  tearDown(() => directory.deleteSync(recursive: true));

  File file(String name) => File(p.join(directory.path, name));

  test('cria a pasta e acrescenta no fim', () async {
    final store = LocalLogStore(
      directory: Directory(p.join(directory.path, 'Diagnóstico')),
    );

    store
      ..append('um\n')
      ..append('dois\n');

    expect(await store.tail(10), ['um', 'dois']);
  });

  test('passando do tamanho, roda e guarda só os últimos arquivos', () async {
    final store = LocalLogStore(directory: directory, maxBytes: 10, keep: 3);

    for (final line in ['aaaaaaa\n', 'bbbbbbb\n', 'ccccccc\n', 'ddddddd\n']) {
      store.append(line);
    }

    expect(file('evergreen.log').readAsStringSync(), 'ddddddd\n');
    expect(file('evergreen.1.log').readAsStringSync(), 'ccccccc\n');
    expect(file('evergreen.2.log').readAsStringSync(), 'bbbbbbb\n');
    expect(file('evergreen.3.log').existsSync(), isFalse, reason: 'o "a" saiu');
  });

  test('as últimas linhas atravessam a rotação, na ordem', () async {
    final store = LocalLogStore(directory: directory, maxBytes: 10, keep: 3);
    for (final line in ['aaaaaaa\n', 'bbbbbbb\n', 'ccccccc\n']) {
      store.append(line);
    }

    expect(await store.tail(2), ['bbbbbbb', 'ccccccc']);
    expect(await store.tail(10), ['aaaaaaa', 'bbbbbbb', 'ccccccc']);
  });

  test('quem não roda só acrescenta, e para no dobro do tamanho', () {
    final store = LocalLogStore(
      directory: directory,
      maxBytes: 10,
      rotates: false,
    );

    for (final line in ['aaaaaaa\n', 'bbbbbbb\n', 'ccccccc\n', 'ddddddd\n']) {
      store.append(line);
    }

    // 24 bytes passaram de 20 (o dobro): o "d" ficou de fora, e nada rodou.
    expect(
      file('evergreen.log').readAsStringSync(),
      'aaaaaaa\nbbbbbbb\nccccccc\n',
    );
    expect(file('evergreen.1.log').existsSync(), isFalse);
  });

  test('sem arquivo ainda, não há linha nenhuma', () async {
    expect(await LocalLogStore(directory: directory).tail(5), isEmpty);
  });
}

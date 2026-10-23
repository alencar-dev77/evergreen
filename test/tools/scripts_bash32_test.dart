import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Os scripts rodam no bash 3.2 do macOS, e ele lê o primeiro byte de um
/// caractere não ASCII colado numa variável (`$TAG…`) como parte do nome dela.
/// Com o `set -u`, o script morre procurando uma variável que não existe — foi
/// o que parou o primeiro `./scripts/release` depois da notarização, antes do
/// upload. Variável colada em acento, reticências ou emoji vai entre chaves:
/// `${TAG}…`.
void main() {
  test('nenhum script cola uma variável num caractere não ASCII', () {
    final unsafe = RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]');
    final problems = <String>[];

    for (final file in Directory('scripts').listSync().whereType<File>()) {
      if (file.path.endsWith('.md')) continue;

      final lines = const LineSplitter().convert(file.readAsStringSync());
      for (final (index, line) in lines.indexed) {
        if (unsafe.hasMatch(line)) problems.add('${file.path}:${index + 1}');
      }
    }

    expect(problems, isEmpty, reason: 'use \${NOME} antes do caractere');
  });
}

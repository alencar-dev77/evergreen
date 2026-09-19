import 'dart:io';

import 'package:evergreen/core/storage/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Os textos que saem do Evergreen.
///
/// Este é o teste do disco de verdade — o da tela usa uma imitação em memória,
/// porque no relógio falso do binding a resposta de uma escrita em arquivo
/// nunca chega. O que se prende aqui é o que só aparece no disco: a pasta que
/// nasce sozinha e o nome que nunca é sobrescrito.
void main() {
  late Directory root;
  late LocalExportService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('evergreen-export-test');
    service = LocalExportService(
      directory: Directory('${root.path}/Exportações'),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('a pasta nasce na primeira exportação', () async {
    expect(service.directory.existsSync(), isFalse);

    // `reveal: false`: abrir o Finder no meio de uma suíte de testes seria
    // um processo do sistema por arquivo escrito.
    await service.write(
      baseName: 'reuniao-resumo',
      content: '# Reunião',
      reveal: false,
    );

    expect(service.directory.existsSync(), isTrue);
  });

  test('o texto chega inteiro ao arquivo', () async {
    final file = await service.write(
      baseName: 'reuniao-resumo',
      content: '# Reunião\n\nO time fechou o escopo.',
      reveal: false,
    );

    expect(file.path, endsWith('reuniao-resumo.md'));
    expect(file.readAsStringSync(), contains('O time fechou o escopo.'));
  });

  /// Exportar a mesma reunião duas vezes é o que se faz depois de refazer o
  /// resumo — e é para comparar um com o outro. Sobrescrever apagaria
  /// justamente o que se queria comparar.
  test('o segundo arquivo do mesmo nome não come o primeiro', () async {
    final first = await service.write(
      baseName: 'reuniao-resumo',
      content: 'primeiro',
      reveal: false,
    );
    final second = await service.write(
      baseName: 'reuniao-resumo',
      content: 'segundo',
      reveal: false,
    );

    expect(first.path, isNot(second.path));
    expect(second.path, endsWith('reuniao-resumo-2.md'));
    expect(first.readAsStringSync(), 'primeiro');
    expect(second.readAsStringSync(), 'segundo');
  });

  test('a pasta se apresenta pelo ~, não pelo caminho do usuário', () {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;

    final inside = LocalExportService(
      directory: Directory('$home/Library/Evergreen/Exportações'),
    );

    expect(inside.directoryLabel, startsWith('~/'));
    expect(inside.directoryLabel, isNot(contains(home)));
  });
}

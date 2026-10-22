import 'package:evergreen/core/diagnostics/diagnostic_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snapshot = DiagnosticSnapshot(
    appVersion: '0.31.5',
    macOS: 'Version 26.1 (Build 25B78)',
    chip: 'Apple M3 Pro',
    modules: [('Pin', true), ('Echo', false)],
    accessibility: DiagnosticPermission.granted,
    microphone: DiagnosticPermission.unavailable,
    screenRecording: DiagnosticPermission.unknown,
    databaseBytes: 2048,
    logTail: ['linha 1', '    #0 pilha'],
    localModel: 'LM Studio · Qwen3.5 4B',
  );

  test('identidade, módulos, permissões e o registro num bloco de código', () {
    final text = DiagnosticReport.render(snapshot);

    expect(text, startsWith('## Diagnóstico do Evergreen\n'));
    expect(text, contains('- Versão: 0.31.5'));
    expect(text, contains('- macOS: Version 26.1 (Build 25B78)'));
    expect(text, contains('- Chip: Apple M3 Pro'));
    expect(text, contains('- Modelo local: LM Studio · Qwen3.5 4B'));
    expect(text, contains('- Pin: ligado'));
    expect(text, contains('- Echo: desligado'));
    expect(text, contains('- Acessibilidade: concedida'));
    expect(text, contains('- Microfone: não se aplica (macOS abaixo do 26)'));
    expect(text, contains('- Gravação de tela: não deu para saber'));
    expect(text, contains('```\nlinha 1\n    #0 pilha\n```'));
  });

  test('registro vazio: diz isso em vez de um bloco vazio', () {
    final text = DiagnosticReport.render(
      const DiagnosticSnapshot(
        appVersion: '',
        macOS: '',
        chip: '',
        modules: [],
        accessibility: DiagnosticPermission.denied,
        microphone: DiagnosticPermission.notDetermined,
        screenRecording: DiagnosticPermission.notDetermined,
        databaseBytes: null,
        logTail: [],
      ),
    );

    expect(text, contains('O registro está vazio.'));
    expect(text, isNot(contains('```')));
    expect(text, contains('- Versão: desconhecido'));
    expect(text, contains('- Banco: não deu para medir'));
  });
}

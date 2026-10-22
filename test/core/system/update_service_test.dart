import 'package:evergreen/core/system/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateNote.parse', () {
    test('lê o HTML que o release escreve a partir do CHANGELOG', () {
      const html = '''
<h3>1.0.3 — 23/10/2026</h3>
<ul>
<li>Filtros &lt;Pin&gt; &amp; mais (#136)</li>
</ul>
<h3>1.0.0 — 22/10/2026</h3>
<p>A V1.</p>
<ul>
<li>Licenças dentro do app (#134)</li>
</ul>''';

      expect(UpdateNote.parse(html), const [
        UpdateNote.heading('1.0.3 — 23/10/2026'),
        UpdateNote.item('Filtros <Pin> & mais (#136)'),
        UpdateNote.heading('1.0.0 — 22/10/2026'),
        UpdateNote.paragraph('A V1.'),
        UpdateNote.item('Licenças dentro do app (#134)'),
      ]);
    });

    test('sem notas, nada', () {
      expect(UpdateNote.parse(null), isEmpty);
      expect(UpdateNote.parse('  '), isEmpty);
    });

    test('tag de fora da lista não vira texto marcado', () {
      expect(
        UpdateNote.parse('<li><b>Negrito</b> e <a href="x">link</a></li>'),
        const [UpdateNote.item('Negrito e link')],
      );
    });
  });

  group('UpdateState', () {
    test('lê o mapa do canal', () {
      final state = UpdateState.fromMap({
        'available': true,
        'automaticChecks': true,
        'canCheck': false,
        'lastCheckMs': 0,
        'phase': 'downloading',
        'version': '1.0.3',
        'notesHtml': '<li>Uma</li>',
        'progress': 0.5,
      });

      expect(state.available, isTrue);
      expect(state.phase, UpdatePhase.downloading);
      expect(state.progress, 0.5);
      expect(state.notes, const [UpdateNote.item('Uma')]);
      expect(state.hasUpdate, isTrue);
    });

    test('sem lado nativo, não se atualiza', () {
      final state = UpdateState.fromMap({'available': false});

      expect(state.available, isFalse);
      expect(state.phase, UpdatePhase.idle);
      expect(state.hasUpdate, isFalse);
    });

    test('só anuncia versão achada e ainda não instalada', () {
      for (final phase in UpdatePhase.values) {
        final state = UpdateState(phase: phase, version: '1.0.3');
        final expected =
            phase == UpdatePhase.available ||
            phase == UpdatePhase.downloading ||
            phase == UpdatePhase.extracting ||
            phase == UpdatePhase.installing;
        expect(state.hasUpdate, expected, reason: phase.name);
      }
      expect(
        const UpdateState(phase: UpdatePhase.available).hasUpdate,
        isFalse,
      );
    });
  });
}

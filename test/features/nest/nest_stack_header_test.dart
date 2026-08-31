import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/nest/models/nest_item.dart';
import 'package:evergreen/features/nest/presentation/widgets/nest_stack_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A capa da prateleira.
///
/// Ela responde o que a lista não responde de relance — quantos são, quanto
/// pesam e de onde vieram —, e cada uma dessas três respostas some sem quebrar
/// nada: a tela continua desenhando um cabeçalho, só que dizendo menos.
void main() {
  NestItem item(String path, int size) => NestItem(
    path: path,
    isDirectory: false,
    sizeInBytes: size,
    modifiedAt: DateTime(2026, 8, 30),
  );

  Future<void> pumpHeader(WidgetTester tester, List<NestItem> items) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: NestStackHeader(items: items, selected: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('conta os arquivos e soma o que eles pesam', (tester) async {
    await pumpHeader(tester, [
      item('/Users/lucas/Downloads/a.pdf', 2400),
      item('/Users/lucas/Downloads/b.png', 1200),
    ]);

    expect(find.textContaining('2 arquivos'), findsOneWidget);
    // 3600 bytes: KB não leva casa decimal (`ByteSize`).
    expect(find.textContaining('4 KB'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'a etiqueta da pilha');
  });

  group('a origem', () {
    testWidgets('é a pasta, quando todos vieram da mesma', (tester) async {
      await pumpHeader(tester, [
        item('/Users/lucas/Downloads/a.pdf', 10),
        item('/Users/lucas/Downloads/b.png', 10),
      ]);

      // Com `~`, e não `/Users/lucas`: é como o macOS escreve a casa.
      expect(find.text('~/Downloads'), findsOneWidget);
    });

    testWidgets('é a contagem, quando vieram de várias', (tester) async {
      await pumpHeader(tester, [
        item('/Users/lucas/Downloads/a.pdf', 10),
        item('/Users/lucas/Documentos/b.png', 10),
      ]);

      expect(find.text('de 2 pastas'), findsOneWidget);
    });

    testWidgets('caminho comprido é cortado no começo', (tester) async {
      await pumpHeader(tester, [
        item('/var/folders/q4/sn8_rnts6_s4by_gt1pj8mqw0000gn/T/nest/a.pdf', 10),
      ]);

      // O fim é o que identifica a pasta; cortar por ellipsis comum deixaria
      // na tela justamente o pedaço que não diz nada.
      expect(find.text('…/T/nest'), findsOneWidget);
    });
  });
}

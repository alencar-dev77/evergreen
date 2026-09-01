import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/echo/presentation/widgets/echo_level_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O equalizador de uma faixa.
///
/// O que ele promete é que **cada barra é uma medida diferente do mesmo
/// instante** — e isso não quebra nenhum outro teste quando some: a tela
/// continua desenhando dez barrinhas, todas do mesmo tamanho, e só uma captura
/// de tela denuncia.
void main() {
  Future<List<double>> heights(
    WidgetTester tester,
    List<double> bands,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: EchoLevelTrack(
              label: 'Você',
              bands: bands,
              color: const Color(0xFF22C55E),
            ),
          ),
        ),
      ),
    );
    // As barras sobem em 100 ms; sem esperar, mede-se o repouso.
    await tester.pump(const Duration(milliseconds: 150));

    return [
      for (final box in tester.widgetList<Container>(find.byType(Container)))
        tester.getSize(find.byWidget(box)).height,
    ];
  }

  testWidgets('cada banda tem a sua altura', (tester) async {
    final medidas = await heights(tester, const [0.1, 0.5, 1.0]);

    expect(medidas, hasLength(3));
    expect(medidas[0], lessThan(medidas[1]));
    expect(medidas[1], lessThan(medidas[2]));
  });

  testWidgets('silêncio descansa no chão, sem sumir', (tester) async {
    final medidas = await heights(tester, const [0, 0, 0]);

    expect(medidas.every((height) => height > 0), isTrue);
    expect(medidas.toSet(), hasLength(1));
  });
}

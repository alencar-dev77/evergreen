import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O sexto estado do botão: trabalhando.
///
/// Ele nasceu de um defeito concreto — o "Refazer resumo" do Echo saía da
/// árvore no instante em que era apertado, e a espera ficava sem lugar nenhum
/// para aparecer.
void main() {
  Future<Size> pumpButton(
    WidgetTester tester, {
    required bool isLoading,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: EgButton(
              label: 'Refazer resumo',
              onPressed: onPressed ?? () {},
              isLoading: isLoading,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return tester.getSize(find.byType(EgButton));
  }

  testWidgets('em repouso não há spinner', (tester) async {
    await pumpButton(tester, isLoading: false);

    expect(find.byType(EgSpinner), findsNothing);
    expect(find.text('Refazer resumo'), findsOneWidget);
  });

  testWidgets('carregando, o spinner aparece', (tester) async {
    await pumpButton(tester, isLoading: true);

    expect(find.byType(EgSpinner), findsOneWidget);
  });

  /// O ponto do defeito original: a tela não pode pular quando a pessoa aperta.
  testWidgets('carregando, o botão não muda de tamanho', (tester) async {
    final parado = await pumpButton(tester, isLoading: false);
    final carregando = await pumpButton(tester, isLoading: true);

    expect(carregando, parado);
  });

  /// O rótulo continua na árvore segurando a largura — mas invisível, senão
  /// competiria com o spinner desenhado por cima dele.
  testWidgets('carregando, o rótulo segura o lugar sem aparecer', (
    tester,
  ) async {
    await pumpButton(tester, isLoading: true);

    expect(find.text('Refazer resumo'), findsOneWidget);

    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Refazer resumo'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 0);
  });

  testWidgets('carregando, o toque não passa', (tester) async {
    var taps = 0;
    await pumpButton(tester, isLoading: true, onPressed: () => taps++);

    await tester.tap(find.byType(EgButton));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('carregando não é o mesmo que desabilitado', (tester) async {
    // Desabilitado esmaece; ocupado, não — o botão está trabalhando, não
    // indisponível. O `Opacity` mais externo é o que a variante controla.
    await pumpButton(tester, isLoading: true);
    final ocupado = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .toList();

    expect(ocupado, contains(1.0));
  });
}

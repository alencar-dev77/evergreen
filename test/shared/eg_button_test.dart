import 'dart:async';

import 'package:evergreen/core/design/app_metrics.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_icon.dart';
import 'package:evergreen/shared/widgets/eg_press_guard.dart';
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

  /// A guarda contra o segundo disparo — o "Fazer backup" que, clicado duas
  /// vezes, fazia dois backups.
  group('duplo clique', () {
    Future<void> pump(WidgetTester tester, Widget button) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: button)),
        ),
      );
    }

    testWidgets('a ação na hora não dispara duas vezes seguidas', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, EgButton(label: 'Copiar', onPressed: () => taps++));

      await tester.tap(find.byType(EgButton));
      await tester.pump();
      await tester.tap(find.byType(EgButton));
      await tester.pump();

      expect(taps, 1);
      expect(find.byType(EgSpinner), findsNothing);
    });

    testWidgets('passada a janela do duplo clique, o botão volta', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, EgButton(label: 'Copiar', onPressed: () => taps++));

      await tester.tap(find.byType(EgButton));
      await tester.pump(AppDurations.pressGuard);
      await tester.tap(find.byType(EgButton));
      await tester.pump();

      expect(taps, 2);
    });

    testWidgets('a ação que demora mostra o spinner e segura o toque', (
      tester,
    ) async {
      var taps = 0;
      final work = Completer<void>();
      await pump(
        tester,
        EgButton(
          label: 'Fazer backup',
          onPressed: () {
            taps++;
            return work.future;
          },
        ),
      );

      await tester.tap(find.byType(EgButton));
      await tester.pump(AppDurations.pressFeedback);
      expect(find.byType(EgSpinner), findsOneWidget);

      // Muito depois da janela do duplo clique: enquanto a ação não acaba, o
      // segundo toque não passa.
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(EgButton));
      await tester.pump();
      expect(taps, 1);

      work.complete();
      await tester.pump();
      expect(find.byType(EgSpinner), findsNothing);

      await tester.tap(find.byType(EgButton));
      await tester.pump();
      expect(taps, 2);

      // A segunda ação continua pendente; o teste a encerra para não deixar
      // o relógio do spinner de pé.
      await tester.pump(AppDurations.pressFeedback);
    });

    testWidgets('a ação rápida não pisca o spinner', (tester) async {
      await pump(
        tester,
        EgButton(label: 'Mostrar no Finder', onPressed: () async {}),
      );

      await tester.tap(find.byType(EgButton));
      await tester.pump();
      await tester.pump(AppDurations.pressFeedback);

      expect(find.byType(EgSpinner), findsNothing);
    });

    testWidgets('esperando a resposta de um diálogo não há spinner', (
      tester,
    ) async {
      // "Apagar tudo?" devolve um Future que só termina na resposta: a espera
      // é da pessoa, e não do app.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: EgButton(
                  label: 'Apagar tudo',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const Text('Apagar tudo?'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EgButton));
      await tester.pumpAndSettle();

      expect(find.text('Apagar tudo?'), findsOneWidget);
      expect(find.byType(EgSpinner), findsNothing);
    });

    testWidgets('o botão de ícone troca o ícone pelo spinner', (tester) async {
      final work = Completer<void>();
      await pump(
        tester,
        EgIconButton(
          icon: EgIconData.close,
          tooltip: 'Copiar',
          onPressed: () => work.future,
        ),
      );

      await tester.tap(find.byType(EgIconButton));
      await tester.pump(AppDurations.pressFeedback);
      expect(find.byType(EgSpinner), findsOneWidget);
      expect(find.byType(EgIcon), findsNothing);

      work.complete();
      await tester.pump();
      expect(find.byType(EgSpinner), findsNothing);
    });

    test('função sem retorno também serve', () {
      // Quem chama não precisa mudar: `void Function()` continua aceito.
      void action() {}
      final EgPressCallback callback = action;
      expect(callback(), isNull);
    });
  });
}

import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// O switch é o controle mais repetido das telas de configuração e o único com
/// duas colunas de estado (ligado e desligado). Estes testes prendem a matriz
/// documentada em `EgToggle` — em especial o `pressed`, que faltava até a
/// componentização do design system.
void main() {
  // O trilho conta o estado pela cor, e a cor é do tema: prendendo o do
  // Evergreen, o teste continua sendo sobre o estado, não sobre a pele.
  final eg = EgTokens.evergreen();

  Future<void> pump(
    WidgetTester tester, {
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: EgToggle(value: value, onChanged: onChanged),
        ),
      ),
    );
  }

  Color trackColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets('em repouso, o trilho conta o estado', (tester) async {
    await pump(tester, value: true, onChanged: (_) {});
    expect(trackColor(tester), eg.colors.accent);

    await pump(tester, value: false, onChanged: (_) {});
    // Apagado, o trilho é `hover`, e não a cor de divisor: dentro de um cartão
    // de seção um trilho na cor da linha some no próprio cartão, e um
    // interruptor que não se vê apagado não conta que existe.
    expect(trackColor(tester), eg.colors.hover);
  });

  testWidgets('o mouse por cima clareia o trilho nas duas colunas', (
    tester,
  ) async {
    await pump(tester, value: true, onChanged: (_) {});

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: tester.getCenter(find.byType(EgToggle)));
    addTearDown(pointer.removePointer);
    await tester.pumpAndSettle();

    expect(trackColor(tester), eg.colors.accentLight);
  });

  testWidgets('o clique dá sinal antes de a preferência virar', (tester) async {
    await pump(tester, value: true, onChanged: (_) {});

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(EgToggle)),
    );
    await tester.pump();

    expect(
      trackColor(tester),
      eg.colors.accentDeep,
      reason: 'ligado, o pressed escurece o verde',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('desligado, o pressed clareia o cinza', (tester) async {
    await pump(tester, value: false, onChanged: (_) {});

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(EgToggle)),
    );
    await tester.pump();

    expect(trackColor(tester), eg.colors.pressed);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('desabilitado não reage a clique nem muda de superfície', (
    tester,
  ) async {
    await pump(tester, value: false);

    await tester.tap(find.byType(EgToggle));
    await tester.pumpAndSettle();

    expect(trackColor(tester), eg.colors.hover);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
  });
}

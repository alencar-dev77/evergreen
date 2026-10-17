import 'package:evergreen/core/design/app_metrics.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Reduzir movimento" do macOS: o que desloca vira instantâneo, e a decisão
/// mora num ponto só (`AppDurations.movement`).
void main() {
  /// Liga a preferência do sistema pelo mesmo caminho do macOS — o binding,
  /// e não um `MediaQuery` montado à mão no teste.
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Monta um `MediaQuery` a partir da janela, como o `MaterialApp` faria.
  Widget app(Widget child) {
    return MediaQuery.fromView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );
  }

  Duration? measured;
  Widget probe() => Builder(
    builder: (context) {
      measured = AppDurations.movement(context, AppDurations.medium);
      return const SizedBox();
    },
  );

  testWidgets('sem a preferência, o deslocamento tem a duração dele', (
    tester,
  ) async {
    await tester.pumpWidget(app(probe()));
    expect(measured, AppDurations.medium);
  });

  testWidgets('com a preferência, o deslocamento é instantâneo', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(app(probe()));
    expect(measured, Duration.zero);
  });

  testWidgets('sem MediaQuery acima, nada quebra e nada muda', (tester) async {
    await tester.pumpWidget(probe());
    expect(measured, AppDurations.medium);
  });

  group('EgToggle', () {
    Duration thumbDuration(WidgetTester tester) =>
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration;

    testWidgets('a bolinha desliza com a preferência desligada', (
      tester,
    ) async {
      await tester.pumpWidget(app(EgToggle(value: false, onChanged: (_) {})));
      expect(thumbDuration(tester), AppDurations.instant);
    });

    testWidgets('com movimento reduzido, a bolinha troca de lado parada', (
      tester,
    ) async {
      reduceMotion(tester);
      await tester.pumpWidget(app(EgToggle(value: false, onChanged: (_) {})));
      expect(thumbDuration(tester), Duration.zero);

      final off = tester.getCenter(find.byType(Container).last);
      await tester.pumpWidget(app(EgToggle(value: true, onChanged: (_) {})));
      // O primeiro quadro já tem a bolinha no lugar final. O trilho continua
      // trocando de cor com transição — cor não é movimento.
      final firstFrame = tester.getCenter(find.byType(Container).last);
      await tester.pumpAndSettle();
      final settled = tester.getCenter(find.byType(Container).last);

      expect(firstFrame.dx, greaterThan(off.dx));
      expect(firstFrame, settled);
    });
  });
}

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/data/onboarding_repository.dart';
import 'package:evergreen/features/home/models/onboarding_step.dart';
import 'package:evergreen/features/home/presentation/viewmodels/onboarding_view_model.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evergreen/shared/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A apresentação de boas-vindas roda **uma vez por build instalada**, como a
/// abertura animada do Hub: instalar ou atualizar a traz de volta. Pular conta
/// como visto: quem fechou respondeu, e reabrir antes da próxima build seria
/// não escutar.
void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('a alavanca de desenvolvimento nasce desligada', () {
    // Se isto falhar, alguém subiu com a apresentação forçada e ela vai
    // aparecer em toda abertura do Hub, para todo mundo.
    expect(kAlwaysShowOnboarding, isFalse);
  });

  group('OnboardingRepository', () {
    test('mostra uma vez por build', () async {
      final repository = OnboardingRepository(preferences);

      expect(repository.shouldShow('build-1'), isTrue);

      await repository.markSeen('build-1');
      expect(repository.shouldShow('build-1'), isFalse);

      // Build nova — atualização, reinstalação, `run_build_copy` —, nova
      // apresentação: a versão nova pode ter painel novo.
      expect(OnboardingRepository(preferences).shouldShow('build-2'), isTrue);
    });

    test('sem carimbo, não mostra', () {
      // Vazio é "não consegui ler o executável". Mostrar seria mostrar em toda
      // abertura, para sempre.
      expect(OnboardingRepository(preferences).shouldShow(''), isFalse);
    });
  });

  /// A condução da apresentação — que só existe com a bandeira ligada. Com ela
  /// desligada não há passo por onde andar, e o "já vi" de ninguém é gravado.
  group('OnboardingViewModel', skip: !FeatureFlags.onboarding, () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          buildStampProvider.overrideWithValue('build-1'),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('anda até o último passo e então encerra', () async {
      final c = container();
      final model = c.read(onboardingViewModelProvider.notifier);

      expect(c.read(onboardingViewModelProvider).visible, isTrue);
      expect(c.read(onboardingViewModelProvider).index, 0);

      for (var i = 1; i < OnboardingStep.all.length; i++) {
        await model.next();
        expect(c.read(onboardingViewModelProvider).index, i);
        expect(c.read(onboardingViewModelProvider).visible, isTrue);
      }

      expect(c.read(onboardingViewModelProvider).isLast, isTrue);
      await model.next();

      expect(c.read(onboardingViewModelProvider).visible, isFalse);
      expect(preferences.getString('app.onboarding_seen_build'), 'build-1');
    });

    test('pular também conta como visto', () async {
      final c = container();
      await c.read(onboardingViewModelProvider.notifier).finish();

      expect(c.read(onboardingViewModelProvider).visible, isFalse);
      expect(preferences.getString('app.onboarding_seen_build'), 'build-1');
      expect(container().read(onboardingViewModelProvider).visible, isFalse);
    });

    test('voltar no primeiro passo não fecha a apresentação', () {
      final c = container();

      c.read(onboardingViewModelProvider.notifier).previous();

      // Sair é o que o "pular" faz. Uma tecla que às vezes volta e às vezes
      // fecha é uma tecla que ninguém aperta com confiança.
      expect(c.read(onboardingViewModelProvider).visible, isTrue);
      expect(c.read(onboardingViewModelProvider).index, 0);
    });

    test('não grava nada antes de a apresentação terminar', () async {
      final c = container();
      await c.read(onboardingViewModelProvider.notifier).next();

      expect(preferences.getString('app.onboarding_seen_build'), isNull);
    });
  });

  group('HubOnboarding', () {
    Future<void> pump(WidgetTester tester, int index) {
      tester.view.physicalSize = const Size(900, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: HubOnboarding(
            step: OnboardingStep.all[index],
            index: index,
            total: OnboardingStep.all.length,
            onNext: () {},
            onPrevious: () {},
            onSkip: () {},
          ),
        ),
      );
    }

    testWidgets('mostra o módulo, o atalho e a frase do passo', (tester) async {
      await pump(tester, 0);

      final passo = OnboardingStep.all.first;
      expect(find.text(passo.module.name), findsOneWidget);
      expect(find.text(passo.shortcut), findsOneWidget);
      expect(find.text(passo.line), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget);
    });

    testWidgets('o último passo muda o verbo do botão', (tester) async {
      await pump(tester, OnboardingStep.all.length - 1);

      // "Próximo" no último passo prometeria uma sexta tela que não existe.
      expect(find.text('Próximo'), findsNothing);
      expect(find.text('Começar'), findsOneWidget);
    });

    testWidgets('o voltar só aparece depois do primeiro passo', (tester) async {
      await pump(tester, 0);
      expect(find.text('voltar'), findsNothing);

      await pump(tester, 1);
      expect(find.text('voltar'), findsOneWidget);
    });

    testWidgets('toda frase tem exatamente duas linhas', (tester) async {
      // A régua da tela é essa: a frase mora entre o print e o botão, e uma
      // terceira linha empurra o botão para fora numa janela curta.
      for (final passo in OnboardingStep.all) {
        expect(
          '\n'.allMatches(passo.line).length,
          1,
          reason: '${passo.module.name} não tem duas linhas',
        );
      }
    });
  });
}

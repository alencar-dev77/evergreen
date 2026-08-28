import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/data/hub_intro_repository.dart';
import 'package:evergreen/features/home/presentation/viewmodels/hub_intro_view_model.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_intro.dart';
import 'package:evergreen/shared/widgets/eg_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A abertura animada do Hub roda uma vez por build instalada. O que decide é o
/// carimbo gravado, nunca o fato de a janela ser nova: fechar o Hub destrói a
/// sub-janela, e sem o carimbo a cena voltaria a cada `⌘⇧` — que é exatamente a
/// tela de loading que o `anti-patterns.md` proíbe.
void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  group('HubIntroRepository', () {
    test('mostra quando o carimbo guardado é de outra build', () async {
      final repository = HubIntroRepository(preferences);

      expect(repository.shouldShow('build-1'), isTrue);

      await repository.markSeen('build-1');
      expect(repository.shouldShow('build-1'), isFalse);

      // Reinstalar muda a data do executável: a marca aparece de novo.
      expect(repository.shouldShow('build-2'), isTrue);
    });

    test('carimbo vazio nunca mostra', () async {
      final repository = HubIntroRepository(preferences);

      // Vazio é "não consegui ler o executável". Mostrar aí faria a cena rodar
      // em toda abertura, para sempre.
      expect(repository.shouldShow(''), isFalse);
    });
  });

  group('HubIntroViewModel', () {
    ProviderContainer containerFor(String stamp) {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          buildStampProvider.overrideWithValue(stamp),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('grava o carimbo só quando a cena termina', () async {
      final container = containerFor('build-1');

      expect(container.read(hubIntroViewModelProvider), isTrue);
      // Ainda não terminou: quem fechar o Hub agora vê a marca na próxima vez.
      expect(preferences.getString('app.last_seen_build'), isNull);

      await container.read(hubIntroViewModelProvider.notifier).complete();

      expect(container.read(hubIntroViewModelProvider), isFalse);
      expect(preferences.getString('app.last_seen_build'), 'build-1');
    });

    test('não mostra de novo na mesma build', () async {
      await containerFor(
        'build-1',
      ).read(hubIntroViewModelProvider.notifier).complete();

      expect(containerFor('build-1').read(hubIntroViewModelProvider), isFalse);
      expect(containerFor('build-2').read(hubIntroViewModelProvider), isTrue);
    });
  });

  group('HubIntro', () {
    Future<void> pump(
      WidgetTester tester, {
      required VoidCallback onDone,
      bool reducedMotion = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: HubIntro(onDone: onDone),
          ),
        ),
      );
    }

    testWidgets('a lâmina sai do cabo e trava aberta', (tester) async {
      var done = 0;
      await pump(tester, onDone: () => done++);

      EgBrandMark mark() =>
          tester.widget<EgBrandMark>(find.byType(EgBrandMark));

      // Primeiro quadro: recolhida.
      expect(mark().openness, lessThan(0.05));

      // Na metade do giro ela está no meio do caminho. O giro dura 1,7s:
      // curto demais e a cena não é vista, que é o motivo de ela existir.
      await tester.pump(const Duration(milliseconds: 850));
      final meio = mark().openness;
      expect(meio, greaterThan(0.1));
      expect(meio, lessThan(1));

      // Ainda girando muito depois de onde uma transição comum já teria
      // acabado — a cena é deliberadamente maior que a escala de transições.
      await tester.pump(const Duration(milliseconds: 500));
      expect(mark().openness, lessThan(1));

      // Depois do assentamento, travada — o estado normal do ícone.
      await tester.pump(const Duration(milliseconds: 450));
      expect(mark().openness, moreOrLessEquals(1, epsilon: 0.001));

      expect(done, 0, reason: 'a cena ainda está na pausa');

      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('a lâmina passa do ponto antes de assentar', (tester) async {
      await pump(tester, onDone: () {});

      // O settle é o único spring do app: sem ele a lâmina para seca e a cena
      // parece cortada. Em algum quadro entre o fim do giro e a trava, a
      // abertura precisa passar de 1.
      // Direto para o fim do giro: o que se procura mora nos 60ms do settle.
      await tester.pump(const Duration(milliseconds: 1690));

      var passou = false;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final v = tester.widget<EgBrandMark>(find.byType(EgBrandMark)).openness;
        if (v > 1.001) passou = true;
      }

      expect(passou, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('com movimento reduzido nasce travada e não anima', (
      tester,
    ) async {
      var done = 0;
      await pump(tester, onDone: () => done++, reducedMotion: true);

      // Sem giro nenhum: já no primeiro quadro a lâmina está no estado final.
      expect(tester.widget<EgBrandMark>(find.byType(EgBrandMark)).openness, 1);

      await tester.pump(const Duration(milliseconds: 900));
      expect(done, 0);

      // A pausa é cumprida do mesmo jeito, e o carimbo acaba gravado — senão a
      // abertura voltaria a cada Hub para quem desligou animação.
      await tester.pump(const Duration(milliseconds: 900));
      expect(done, 1);
    });
  });
}

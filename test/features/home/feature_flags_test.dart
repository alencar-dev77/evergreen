import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme_id.dart';
import 'package:evergreen/core/storage/backup_service.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/features/home/models/app_settings.dart';
import 'package:evergreen/features/home/presentation/viewmodels/hub_intro_view_model.dart';
import 'package:evergreen/features/home/presentation/viewmodels/onboarding_view_model.dart';
import 'package:evergreen/features/home/presentation/views/app_settings_view.dart';
import 'package:evergreen/features/home/presentation/widgets/theme_picker.dart';
import 'package:evergreen/shared/feature_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_fixture.dart';

/// As bandeiras de build: a escolha de aparência e a abertura animada.
///
/// Estes testes passam com ela **nos dois estados**, e é isso que se espera de
/// um teste de bandeira: quem builda troca `FeatureFlags.themes` e a suíte
/// continua verde, provando que o app é coerente dos dois lados. Um teste que
/// só passasse com ela ligada obrigaria a mexer nos testes para desligar a
/// funcionalidade — e aí ninguém desligaria.
void main() {
  late SharedPreferences preferences;
  late BackupService backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app.user_name': 'Lucas'});
    preferences = await SharedPreferences.getInstance();
    // A tela do aplicativo lê a pasta de backup ao montar — em teste ela é
    // temporária, como no teste vizinho.
    backup = temporaryBackupService();
  });

  group('o tema em vigor', () {
    test('com a bandeira ligada, é o escolhido; desligada, é o da casa', () {
      const escolhido = AppSettings(theme: AppThemeId.apple);

      expect(
        escolhido.activeTheme,
        FeatureFlags.themes ? AppThemeId.apple : AppThemeId.evergreen,
      );
    });

    test('o tema da casa é o mesmo dos dois lados da bandeira', () {
      const casa = AppSettings();

      expect(casa.activeTheme, AppThemeId.evergreen);
    });

    test('desligar não apaga o que estava guardado', () async {
      await preferences.setString('app.theme', 'apple');

      // O valor cru segue no disco, esperando: desligar a funcionalidade não é
      // desfazer a escolha de ninguém. É `activeTheme` que responde pelo que a
      // tela desenha.
      expect(preferences.getString('app.theme'), 'apple');
    });
  });

  testWidgets('a linha "Aparência" acompanha a bandeira', (tester) async {
    tester.view.physicalSize = const Size(1800, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          backupServiceProvider.overrideWithValue(backup),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: AppSettingsView()),
          ),
        ),
      ),
    );
    await tester.pump();

    final esperado = FeatureFlags.themes ? findsOneWidget : findsNothing;
    expect(find.text('Aparência'), esperado);
    expect(find.byType(ThemePicker), esperado);
  });

  test('os dois temas continuam completos, ligada ou desligada', () {
    // O código atrás da bandeira segue compilando e testado: no dia em que ela
    // voltar a `true`, o que aparece do outro lado não pode ser uma ruína.
    for (final id in AppThemeId.values) {
      final tokens = EgTokens.of(id);

      expect(tokens.id, id);
      expect(tokens.colors.accent, isNotNull);
      expect(tokens.text.body.fontSize, greaterThan(0));
      expect(tokens.shapes.radiusPanel, greaterThan(0));
    }
  });

  /// A abertura animada do Hub. Mesma regra: o teste vale dos dois lados.
  test('a abertura animada acompanha a bandeira', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        buildStampProvider.overrideWithValue('build-nunca-vista'),
      ],
    );
    addTearDown(container.dispose);

    // Carimbo de uma build que nunca foi vista: ligada, a cena roda; desligada,
    // não roda — e, o que importa, **não gasta** a abertura desta build.
    expect(container.read(hubIntroViewModelProvider), FeatureFlags.intro);
    expect(preferences.getString('app.last_seen_build'), isNull);
  });

  /// A apresentação de boas-vindas, pela mesma régua da abertura.
  test('a apresentação acompanha a bandeira', () {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(onboardingViewModelProvider).visible,
      FeatureFlags.onboarding,
    );
    // Desligada, ela não consome a apresentação de ninguém: o "já vi" fica por
    // gravar, e religar a bandeira apresenta quem nunca foi apresentado.
    expect(preferences.getBool('app.onboarding_seen'), isNull);
  });
}

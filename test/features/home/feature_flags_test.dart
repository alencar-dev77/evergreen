import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/home/presentation/viewmodels/hub_intro_view_model.dart';
import 'package:evergreen/features/home/presentation/viewmodels/onboarding_view_model.dart';
import 'package:evergreen/shared/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// As bandeiras de build: a abertura animada e a apresentação de boas-vindas.
///
/// Estes testes passam com elas **nos dois estados**, e é isso que se espera de
/// um teste de bandeira: quem builda troca a constante e a suíte continua
/// verde, provando que o app é coerente dos dois lados. Um teste que só
/// passasse com ela ligada obrigaria a mexer nos testes para desligar a
/// funcionalidade — e aí ninguém desligaria.
///
/// Houve uma terceira, `themes`, e ela saiu junto com o tema `apple`: uma
/// bandeira existe para desligar algo pronto, e o que ela desligava deixou de
/// existir.
void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app.user_name': 'Lucas'});
    preferences = await SharedPreferences.getInstance();
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
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        buildStampProvider.overrideWithValue('build-nunca-vista'),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(onboardingViewModelProvider).visible,
      FeatureFlags.onboarding,
    );
    // Desligada, ela não consome a apresentação de ninguém: o "já vi" fica por
    // gravar, e religar a bandeira apresenta quem nunca foi apresentado.
    expect(preferences.getString('app.onboarding_seen_build'), isNull);
  });
}

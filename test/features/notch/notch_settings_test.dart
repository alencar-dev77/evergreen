import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/notch/data/notch_settings_repository.dart';
import 'package:evergreen/features/notch/models/notch_settings.dart';
import 'package:evergreen/features/notch/presentation/viewmodels/notch_settings_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nest/fake_nest_channel.dart';
import 'fake_notch_island_channel.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  group('NotchSettingsRepository', () {
    test('tudo nasce ligado, sem chave nenhuma', () {
      final settings = NotchSettingsRepository(preferences).load();

      for (final module in NotchModule.values) {
        expect(settings.isEnabled(module), isTrue);
      }
      expect(preferences.getKeys(), isEmpty);
    });

    test('só o desligado é gravado, e religar apaga a chave', () async {
      final repository = NotchSettingsRepository(preferences);

      await repository.save(NotchModule.echo, enabled: false);
      expect(preferences.getBool('notch.echo'), isFalse);
      expect(repository.load().isEnabled(NotchModule.echo), isFalse);
      expect(repository.load().isEnabled(NotchModule.focus), isTrue);

      await repository.save(NotchModule.echo, enabled: true);
      expect(preferences.containsKey('notch.echo'), isFalse);
    });
  });

  group('NotchSettingsViewModel', () {
    late FakeNestChannel nest;
    late FakeNotchIslandChannel island;
    late ProviderContainer container;

    setUp(() {
      nest = FakeNestChannel();
      island = FakeNotchIslandChannel();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          nestChannelProvider.overrideWithValue(nest),
          notchIslandChannelProvider.overrideWithValue(island),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      nest.dispose();
      island.dispose();
    });

    test('o Nest é porta e pilha: avisa o arraste e a ilha', () async {
      await container
          .read(notchSettingsViewModelProvider.notifier)
          .setEnabled(NotchModule.nest, enabled: false);

      expect(nest.isNotchEnabled, isFalse);
      expect(island.enabled, {NotchModule.nest: false});
    });

    test('o Echo e o Focus são vitrine: avisam a ilha', () async {
      final viewModel = container.read(notchSettingsViewModelProvider.notifier);

      await viewModel.setEnabled(NotchModule.echo, enabled: false);
      await viewModel.setEnabled(NotchModule.focus, enabled: true);

      expect(island.enabled, {
        NotchModule.echo: false,
        NotchModule.focus: true,
      });
      expect(
        container
            .read(notchSettingsViewModelProvider)
            .isEnabled(NotchModule.echo),
        isFalse,
      );
    });
  });
}

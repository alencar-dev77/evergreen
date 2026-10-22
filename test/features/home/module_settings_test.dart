import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/system/global_shortcut_slot.dart';
import 'package:evergreen/core/system/shortcut_binding.dart';
import 'package:evergreen/core/window/overlay_panel.dart';
import 'package:evergreen/features/home/data/module_settings_repository.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/models/module_settings.dart';
import 'package:evergreen/features/home/presentation/viewmodels/module_settings_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_module_settings_notifier.dart';

void main() {
  late SharedPreferences preferences;
  late FakeModuleSettingsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    notifier = FakeModuleSettingsNotifier();
  });

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        moduleSettingsNotifierProvider.overrideWithValue(notifier),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ModuleSettingsViewModel model(ProviderContainer container) =>
      container.read(moduleSettingsViewModelProvider.notifier);

  group('quais módulos estão ligados', () {
    test('de fábrica todos estão, e nada é gravado por isso', () {
      final settings = ModuleSettingsRepository(preferences).load();

      for (final module in EvergreenModule.values) {
        expect(settings.isEnabled(module), isTrue, reason: module.name);
      }
      expect(preferences.getKeys(), isEmpty);
    });

    test(
      'desligar grava; religar apaga a chave em vez de gravar true',
      () async {
        final repository = ModuleSettingsRepository(preferences);

        await repository.setEnabled(EvergreenModule.echo, enabled: false);
        expect(repository.load().isEnabled(EvergreenModule.echo), isFalse);
        expect(preferences.getKeys(), contains('module.echo.enabled'));

        await repository.setEnabled(EvergreenModule.echo, enabled: true);
        expect(repository.load().isEnabled(EvergreenModule.echo), isTrue);
        // Ligado é a ausência da chave: é o que faz um módulo novo nascer ligado
        // sem migração nenhuma.
        expect(preferences.getKeys(), isEmpty);
      },
    );

    test('módulo desligado sai dos atalhos que vão para o sistema', () {
      const settings = ModuleSettings(disabled: {EvergreenModule.nest});

      expect(
        settings.activeBindings.keys,
        isNot(contains(GlobalShortcutSlot.nest)),
      );
      // Mas a tecla continua sendo dele, para ninguém tomá-la enquanto isso.
      expect(settings.allBindings.keys, contains(GlobalShortcutSlot.nest));
    });

    test('o atalho do Hub nunca sai: é a porta para religar o resto', () {
      final settings = ModuleSettings(disabled: EvergreenModule.values.toSet());

      expect(settings.activeBindings.keys, [GlobalShortcutSlot.hub]);
    });

    test('cada módulo com painel tem um item de menu, e o Track não tem', () {
      for (final module in EvergreenModule.values) {
        expect(
          module.menuBarAction != null,
          module.shortcutSlot != null,
          reason: module.name,
        );
      }

      expect(EvergreenModule.track.menuBarAction, isNull);
      // O caminho de volta, que é o que decide se um arquivo solto no painel
      // pertence a um módulo ligado.
      expect(EvergreenModule.of(OverlayPanel.pin), EvergreenModule.pin);
    });
  });

  group('gravar um atalho', () {
    const livre = ShortcutBinding(
      key: PhysicalKeyboardKey.keyG,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.option},
    );

    test('a combinação aceita fica no estado e no disco', () async {
      final scope = container();

      expect(await model(scope).record(GlobalShortcutSlot.pin, livre), isNull);

      expect(
        scope
            .read(moduleSettingsViewModelProvider)
            .bindingFor(GlobalShortcutSlot.pin),
        livre,
      );
      expect(
        ModuleSettingsRepository(
          preferences,
        ).load().bindingFor(GlobalShortcutSlot.pin),
        livre,
      );
    });

    test('a recusa não grava nada', () async {
      final scope = container();

      final refusal = await model(scope).record(
        GlobalShortcutSlot.pin,
        // A tecla do Echo.
        GlobalShortcutSlot.echo.fallback,
      );

      expect(refusal, contains('do Echo'));
      expect(
        scope
            .read(moduleSettingsViewModelProvider)
            .bindingFor(GlobalShortcutSlot.pin),
        GlobalShortcutSlot.pin.fallback,
      );
      expect(preferences.getKeys(), isEmpty);
    });

    test('regravar o padrão é o mesmo que restaurar', () async {
      final scope = container();

      await model(scope).record(GlobalShortcutSlot.pin, livre);
      expect(
        scope
            .read(moduleSettingsViewModelProvider)
            .isCustom(GlobalShortcutSlot.pin),
        isTrue,
      );

      await model(
        scope,
      ).record(GlobalShortcutSlot.pin, GlobalShortcutSlot.pin.fallback);

      // Sem isto o slot ficaria "trocado" mostrando exatamente o padrão, com um
      // botão "Restaurar" que não faria diferença nenhuma.
      expect(
        scope
            .read(moduleSettingsViewModelProvider)
            .isCustom(GlobalShortcutSlot.pin),
        isFalse,
      );
      expect(preferences.getKeys(), isEmpty);
    });

    test('restaurar volta para a combinação de fábrica', () async {
      final scope = container();

      await model(scope).record(GlobalShortcutSlot.pin, livre);
      await model(scope).restoreDefault(GlobalShortcutSlot.pin);

      expect(
        scope
            .read(moduleSettingsViewModelProvider)
            .bindingFor(GlobalShortcutSlot.pin),
        GlobalShortcutSlot.pin.fallback,
      );
      expect(preferences.getKeys(), isEmpty);
    });

    test('a tecla de um módulo desligado continua reservada', () async {
      final scope = container();
      await model(scope).setEnabled(EvergreenModule.echo, enabled: false);

      final refusal = await model(
        scope,
      ).record(GlobalShortcutSlot.pin, GlobalShortcutSlot.echo.fallback);

      // Deixar tomar faria os dois disputarem a mesma tecla no dia em que o
      // Echo voltasse a ligar.
      expect(refusal, contains('do Echo'));
    });
  });

  group('a janela 0 é avisada', () {
    test('cada mudança dispara uma reaplicação', () async {
      final scope = container();

      await model(scope).setEnabled(EvergreenModule.leaf, enabled: false);
      expect(notifier.reapplied, 1);

      await model(scope).record(
        GlobalShortcutSlot.pin,
        const ShortcutBinding(
          key: PhysicalKeyboardKey.keyG,
          modifiers: {ShortcutModifier.meta, ShortcutModifier.option},
        ),
      );
      expect(notifier.reapplied, 2);

      await model(scope).restoreDefault(GlobalShortcutSlot.pin);
      expect(notifier.reapplied, 3);
    });

    test('a recusa não manda ninguém reaplicar nada', () async {
      final scope = container();

      await model(
        scope,
      ).record(GlobalShortcutSlot.pin, GlobalShortcutSlot.echo.fallback);

      expect(notifier.reapplied, isZero);
    });

    test('gravar suspende os atalhos do sistema e devolve depois', () async {
      final scope = container();

      await model(scope).setRecording(recording: true);
      await model(scope).setRecording(recording: false);

      expect(notifier.suspensions, [true, false]);
    });
  });
}

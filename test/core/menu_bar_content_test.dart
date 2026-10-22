import 'package:evergreen/core/system/global_shortcut_slot.dart';
import 'package:evergreen/core/system/menu_bar_service.dart';
import 'package:evergreen/core/system/shortcut_binding.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// O conteúdo da barra de menus — o que o menu lista e o que o título junta.
/// O ícone de verdade (`MenuBarService`) fica fora: criá-lo num teste poria um
/// ícone na barra de menus de quem roda a suíte.
void main() {
  List<String> labels(MenuBarContent content) => [
    for (final entry in content.entries()) entry.label,
  ];

  test('nasce com todos os módulos, as preferências e as duas saídas', () {
    final entries = MenuBarContent().entries();

    expect(entries.first, const MenuBarEntry.item('Evergreen'));
    expect(entries.first.action, isNull, reason: 'o topo é só texto');
    expect(
      [for (final entry in entries) entry.action],
      [
        null,
        MenuBarAction.openPin,
        MenuBarAction.openFocus,
        MenuBarAction.openLeaf,
        MenuBarAction.openAwake,
        MenuBarAction.openEcho,
        MenuBarAction.openNest,
        MenuBarAction.openHub,
        null,
        MenuBarAction.uninstall,
        MenuBarAction.quit,
      ],
    );
    expect(entries[entries.length - 3].isSeparator, isTrue);
  });

  test('a versão nova vira o primeiro item, com a bolinha, e some depois', () {
    final content = MenuBarContent()..updateVersion = '1.0.3';
    final entries = content.entries();

    expect(
      entries[1],
      const MenuBarEntry.item(
        '● Atualizar para a 1.0.3…',
        action: MenuBarAction.update,
      ),
    );
    expect(entries[2].isSeparator, isTrue);
    expect(entries[3].action, MenuBarAction.openPin);
    // O título ao lado do ícone não muda: ali o ponto é do Awake.
    expect(content.title(), isEmpty);

    content.updateVersion = null;
    expect(
      content.entries().where((entry) => entry.action == MenuBarAction.update),
      isEmpty,
    );
  });

  test('cada item leva a tecla em vigor; as saídas não têm', () {
    final content = MenuBarContent();

    expect(labels(content), contains('Pin   ⌘⇧C'));
    expect(labels(content), contains('Encerrar Evergreen'));
    expect(labels(content), contains('Desinstalar Evergreen…'));
  });

  test('módulo desligado sai do menu e a tecla regravada aparece', () {
    final content = MenuBarContent()
      ..modules = [MenuBarAction.openPin, MenuBarAction.openNest]
      ..bindings = {
        ...MenuBarContent().bindings,
        GlobalShortcutSlot.pin: const ShortcutBinding(
          key: PhysicalKeyboardKey.keyV,
          modifiers: {ShortcutModifier.meta, ShortcutModifier.option},
        ),
      };

    final actions = [for (final entry in content.entries()) entry.action];
    expect(actions, isNot(contains(MenuBarAction.openFocus)));
    expect(actions, contains(MenuBarAction.openNest));
    // As preferências ficam sempre: é a porta para religar o resto.
    expect(actions, contains(MenuBarAction.openHub));

    final pin = content.entries().firstWhere(
      (entry) => entry.action == MenuBarAction.openPin,
    );
    expect(pin.label, isNot(contains('⌘⇧C')));
    expect(pin.label, 'Pin   ⌘⌥V');
  });

  test('com todos os módulos desligados, as saídas continuam', () {
    final content = MenuBarContent()..modules = [];

    final actions = [for (final entry in content.entries()) entry.action];
    expect(actions, contains(MenuBarAction.uninstall));
    expect(actions, contains(MenuBarAction.quit));
  });

  test('com o Awake ligado, o item diz quanto falta', () {
    final content = MenuBarContent()..awakeDetail = '38 min';

    expect(labels(content), contains('Awake · 38 min   ⌘⇧X'));
  });

  group('título', () {
    test('vazio quando nada está rodando', () {
      expect(MenuBarContent().title(), isEmpty);
    });

    test('Awake, Echo e Focus juntos, nessa ordem', () {
      final content = MenuBarContent()
        ..sessionLabel = '12:30'
        ..echoLabel = '04:10'
        ..awakeDetail = 'sem limite';

      expect(content.title(), '● ◉ 04:10 12:30');
    });

    test('o relógio que a ilha do notch mostra sai do título', () {
      final content = MenuBarContent()
        ..sessionLabel = '12:30'
        ..echoLabel = '04:10'
        ..awakeDetail = 'sem limite';

      content.inNotch = MenuBarAction.openEcho;
      expect(
        content.title(),
        '● 12:30',
        reason: 'a ilha mostra uma coisa só; o foco continua ao lado do ícone',
      );

      content.inNotch = MenuBarAction.openFocus;
      expect(content.title(), '● ◉ 04:10');

      content.inNotch = null;
      expect(content.title(), '● ◉ 04:10 12:30', reason: 'sem ilha, volta');
    });

    test('só a reunião, e ela no notch: título vazio', () {
      final content = MenuBarContent()
        ..echoLabel = '04:10'
        ..inNotch = MenuBarAction.openEcho;

      expect(content.title(), isEmpty);
    });
  });
}

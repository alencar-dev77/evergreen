import 'package:evergreen/core/system/global_shortcut_slot.dart';
import 'package:evergreen/core/system/shortcut_binding.dart';
import 'package:evergreen/core/system/shortcut_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ShortcutBinding _binding(
  PhysicalKeyboardKey key,
  Set<ShortcutModifier> modifiers,
) => ShortcutBinding(key: key, modifiers: modifiers);

void main() {
  group('como a combinação se escreve', () {
    test('os key-caps saem na ordem da casa, com a tecla por último', () {
      final binding = _binding(PhysicalKeyboardKey.keyC, {
        // De propósito fora de ordem: quem grava aperta na ordem que quiser.
        ShortcutModifier.shift,
        ShortcutModifier.meta,
      });

      expect(binding.caps, ['⌘', '⇧', 'C']);
      expect(binding.compact, '⌘⇧C');
    });

    test('a leitura em voz alta troca os símbolos por nomes', () {
      final binding = _binding(PhysicalKeyboardKey.arrowRight, {
        ShortcutModifier.meta,
        ShortcutModifier.option,
      });

      expect(binding.spoken, 'Command Option →');
    });

    test('a igualdade não depende da ordem em que as teclas foram apertadas', () {
      expect(
        _binding(PhysicalKeyboardKey.keyC, {
          ShortcutModifier.meta,
          ShortcutModifier.shift,
        }),
        _binding(PhysicalKeyboardKey.keyC, {
          ShortcutModifier.shift,
          ShortcutModifier.meta,
        }),
      );
    });
  });

  group('ida e volta do disco', () {
    test('o que foi gravado volta idêntico', () {
      for (final slot in GlobalShortcutSlot.values) {
        expect(
          ShortcutBinding.parse(slot.fallback.storageValue),
          slot.fallback,
          reason: 'o padrão do ${slot.name} não sobreviveu à volta',
        );
      }
    });

    test('texto ilegível vira nulo, e quem chama cai no padrão', () {
      for (final value in [
        null,
        '',
        'meta+shift',
        'meta+shift:',
        'meta+shift:abc',
        'meta+telepatia:6',
        'meta+shift:999999999',
      ]) {
        expect(ShortcutBinding.parse(value), isNull, reason: 'para "$value"');
      }
    });
  });

  group('o que pode virar atalho global', () {
    String? refuse(ShortcutBinding binding, {
      Map<GlobalShortcutSlot, ShortcutBinding> taken = const {},
    }) => ShortcutRules.refuse(
      binding,
      slot: GlobalShortcutSlot.pin,
      taken: taken,
      ownerOf: (slot) => 'do ${slot.name}',
    );

    test('os sete padrões da casa passam pelas próprias regras', () {
      final taken = {
        for (final slot in GlobalShortcutSlot.values) slot: slot.fallback,
      };

      for (final slot in GlobalShortcutSlot.values) {
        expect(
          ShortcutRules.refuse(
            slot.fallback,
            slot: slot,
            taken: taken,
            ownerOf: (slot) => slot.name,
          ),
          isNull,
          reason: 'o padrão do ${slot.name} seria recusado',
        );
      }
    });

    test('uma modificadora só é recusada — é aí que mora o ⌘C', () {
      expect(
        refuse(_binding(PhysicalKeyboardKey.keyC, {ShortcutModifier.meta})),
        contains('duas modificadoras'),
      );
    });

    test('⇧ e ⌥ juntos não bastam: sem ⌘ nem ⌃ a combinação é um caractere', () {
      expect(
        refuse(
          _binding(PhysicalKeyboardKey.keyK, {
            ShortcutModifier.shift,
            ShortcutModifier.option,
          }),
        ),
        contains('⌘ ou ⌃'),
      );
    });

    test('tecla que não serve de tecla final é recusada', () {
      expect(
        refuse(
          _binding(PhysicalKeyboardKey.escape, {
            ShortcutModifier.meta,
            ShortcutModifier.shift,
          }),
        ),
        contains('tecla final'),
      );
    });

    test('o que o macOS reserva não é entregue', () {
      // ⌘⇧4 é a captura de tela — passa nas duas primeiras regras e mesmo assim
      // não pode ser tomada.
      expect(
        refuse(
          _binding(PhysicalKeyboardKey.digit4, {
            ShortcutModifier.meta,
            ShortcutModifier.shift,
          }),
        ),
        contains('macOS'),
      );
    });

    test('conflito aponta o dono da tecla pelo nome', () {
      final refusal = refuse(
        _binding(PhysicalKeyboardKey.keyE, {
          ShortcutModifier.meta,
          ShortcutModifier.shift,
        }),
        taken: {GlobalShortcutSlot.echo: GlobalShortcutSlot.echo.fallback},
      );

      expect(refusal, contains('⌘⇧E'));
      expect(refusal, contains('echo'));
    });

    test('regravar a tecla que o próprio slot já tem é permitido', () {
      expect(
        refuse(
          GlobalShortcutSlot.pin.fallback,
          taken: {GlobalShortcutSlot.pin: GlobalShortcutSlot.pin.fallback},
        ),
        isNull,
      );
    });

    test('uma combinação livre passa', () {
      expect(
        refuse(
          _binding(PhysicalKeyboardKey.keyG, {
            ShortcutModifier.meta,
            ShortcutModifier.option,
          }),
        ),
        isNull,
      );
    });
  });
}

import 'package:flutter/services.dart';

import 'global_shortcut_slot.dart';
import 'shortcut_binding.dart';

/// O que decide se uma combinação pode virar atalho global.
///
/// Puro de propósito — nada aqui toca no sistema, no disco nem na tela. Um
/// atalho global é a única preferência do Evergreen capaz de estragar o
/// **resto do Mac**: registrada, a combinação para de chegar em todo aplicativo
/// que a usava, e quem gravou `⌘C` sem querer descobre isso na primeira vez que
/// tenta copiar alguma coisa. Por isso a recusa vem antes de qualquer escrita, e
/// vem com o motivo escrito.
abstract final class ShortcutRules {
  /// O piso: duas modificadoras, uma delas `⌘` ou `⌃`.
  ///
  /// É uma regra só, e ela sozinha faz o trabalho de uma lista de proibições
  /// enorme: `⌘C`, `⌘Q`, `⌘W`, `⌘Space`, `⌘Tab` e `⌃Space` são todos atalhos de
  /// uma modificadora — todo comando de menu do macOS é. Exigir duas devolve a
  /// combinação para o espaço em que a casa já vivia (`⌘⇧`), e onde a chance de
  /// atropelar outro aplicativo é pequena.
  ///
  /// `⇧` e `⌥` sozinhos não contam como a segunda: `⇧K` é a letra K maiúscula e
  /// `⌥K` é `˚` — os dois são caracteres que a pessoa digita, não atalhos.
  static const minimumModifiers = 2;

  /// Combinações que o macOS reserva para si, todas com duas modificadoras ou
  /// mais — as de uma só já caem no piso acima.
  ///
  /// A lista é curta e é uma escolha: só entram as que o sistema toma **de
  /// todos os aplicativos**, não as que um aplicativo qualquer usa. O Evergreen
  /// não tem como saber o que está instalado, e uma lista que tentasse adivinhar
  /// seria uma lista errada — o que ele pode fazer é não deixar a pessoa
  /// perder a captura de tela nem o bloqueio do Mac sem perceber.
  static final reserved = <ShortcutBinding>[
    // Captura de tela: ⌘⇧3, ⌘⇧4, ⌘⇧5, ⌘⇧6.
    for (final key in [
      PhysicalKeyboardKey.digit3,
      PhysicalKeyboardKey.digit4,
      PhysicalKeyboardKey.digit5,
      PhysicalKeyboardKey.digit6,
    ])
      ShortcutBinding(
        key: key,
        modifiers: const {ShortcutModifier.meta, ShortcutModifier.shift},
      ),
    // Encerrar sessão.
    const ShortcutBinding(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
    // Bloquear a tela.
    const ShortcutBinding(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.control},
    ),
    // Seletor de emoji.
    const ShortcutBinding(
      key: PhysicalKeyboardKey.space,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.control},
    ),
    // Tela cheia.
    const ShortcutBinding(
      key: PhysicalKeyboardKey.keyF,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.control},
    ),
    // Esconder o Dock.
    const ShortcutBinding(
      key: PhysicalKeyboardKey.keyD,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.option},
    ),
    // Busca da Ajuda.
    const ShortcutBinding(
      key: PhysicalKeyboardKey.slash,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ];

  /// O motivo da recusa, ou `null` quando a combinação serve.
  ///
  /// [taken] é o mapa **inteiro** dos atalhos em vigor, incluindo o do próprio
  /// [slot] — regravar a mesma combinação num slot que já a tem é permitido, e
  /// não custa nada.
  ///
  /// [ownerOf] devolve a frase já preposicionada — "do Echo", "das
  /// preferências" —, e não o nome cru: em português a preposição muda com o
  /// artigo, e montá-la aqui daria "o atalho de o Echo".
  ///
  /// A conferência de conflito é global mesmo a tela sendo a de um módulo só:
  /// quem está na tela do Leaf não faz ideia de que `⌘⇧E` é do Echo, e uma
  /// recusa que não dissesse **de quem** é a tecla mandaria a pessoa procurar
  /// nas outras seis telas.
  static String? refuse(
    ShortcutBinding binding, {
    required GlobalShortcutSlot slot,
    required Map<GlobalShortcutSlot, ShortcutBinding> taken,
    required String Function(GlobalShortcutSlot slot) ownerOf,
  }) {
    if (!ShortcutKeys.isUsable(binding.key)) {
      return 'Essa tecla não pode ser a tecla final de um atalho global.';
    }

    if (binding.modifiers.length < minimumModifiers) {
      return 'Um atalho global precisa de pelo menos duas modificadoras. Com '
          'uma só ele tomaria a tecla de todos os outros aplicativos — o '
          'prefixo da casa é ⌘⇧.';
    }

    if (!binding.modifiers.contains(ShortcutModifier.meta) &&
        !binding.modifiers.contains(ShortcutModifier.control)) {
      return 'Um atalho global precisa de ⌘ ou ⌃. Só com ⇧ e ⌥ a combinação '
          'vira um caractere que se digita.';
    }

    if (reserved.contains(binding)) {
      return 'O macOS usa ${binding.compact} para uma função do próprio '
          'sistema. Escolha outra combinação.';
    }

    for (final entry in taken.entries) {
      if (entry.key == slot || entry.value != binding) continue;

      return '${binding.compact} já é o atalho ${ownerOf(entry.key)}.';
    }

    return null;
  }
}

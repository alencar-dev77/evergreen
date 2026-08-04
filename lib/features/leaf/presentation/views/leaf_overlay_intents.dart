import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/leaf_note.dart';

/// Abre um cartão em branco na primeira vaga livre.
class LeafNewNoteIntent extends Intent {
  const LeafNewNoteIntent();
}

/// Enter: a ação principal da vaga selecionada — editar o que está lá ou
/// anotar onde não há nada.
class LeafActivateIntent extends Intent {
  const LeafActivateIntent();
}

/// Move a seleção pela grade.
class LeafMoveSelectionIntent extends Intent {
  const LeafMoveSelectionIntent({this.columns = 0, this.rows = 0});

  final int columns;
  final int rows;
}

/// Copia a anotação de uma vaga e fecha o painel.
class LeafCopySlotIntent extends Intent {
  const LeafCopySlotIntent(this.slot);

  final int slot;
}

/// Tira o cartão selecionado da parede.
class LeafDeleteIntent extends Intent {
  const LeafDeleteIntent();
}

/// Fecha o painel. O que estava escrito fica guardado.
class LeafCloseIntent extends Intent {
  const LeafCloseIntent();
}

/// Enter dentro do campo: guarda a anotação e devolve o teclado à parede.
class LeafCommitEditIntent extends Intent {
  const LeafCommitEditIntent();
}

/// Esc dentro do campo: desfaz o que foi digitado.
class LeafCancelEditIntent extends Intent {
  const LeafCancelEditIntent();
}

/// Abre as preferências (Hub) e fecha o painel.
class LeafOpenSettingsIntent extends Intent {
  const LeafOpenSettingsIntent();
}

/// Mapa de teclado do painel do Leaf.
///
/// São dois mapas, não um: enquanto um cartão está sendo escrito, o teclado
/// pertence ao texto. Setas, `⌘⌫` e os números voltam a ser caracteres, e
/// sobram as duas teclas que o campo precisa — Enter guarda, Esc desfaz. É a
/// mesma regra que o apelido do Pin já seguia.
///
/// O Enter é interceptado **aqui**, e não pelo `onSubmitted` do campo, e é isso
/// que abre espaço para o `⇧⏎`: o `Shortcuts` consome a tecla antes de ela
/// virar texto, mas só a combinação exata registrada — com o Shift junto, a
/// tecla não casa com nada neste mapa, desce até o campo e quebra a linha.
abstract final class LeafOverlayIntents {
  /// Teclas de `⌘1` a `⌘9`, na ordem das vagas.
  static const _numberKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  static final browsing = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.enter): const LeafActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const LeafActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const LeafCloseIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const LeafMoveSelectionIntent(columns: -1),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const LeafMoveSelectionIntent(columns: 1),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const LeafMoveSelectionIntent(rows: -1),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const LeafMoveSelectionIntent(rows: 1),
    // `⌘+` em qualquer teclado: o sinal de mais mora no `=` do ANSI e tem tecla
    // própria no numérico, e quem aperta `⌘⇧=` está apertando `⌘+`.
    const SingleActivator(LogicalKeyboardKey.equal, meta: true):
        const LeafNewNoteIntent(),
    const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true):
        const LeafNewNoteIntent(),
    const SingleActivator(LogicalKeyboardKey.add, meta: true):
        const LeafNewNoteIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
        const LeafNewNoteIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace, meta: true):
        const LeafDeleteIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, meta: true):
        const LeafOpenSettingsIntent(),
    for (var i = 0; i < LeafNote.maxNotes; i++)
      SingleActivator(_numberKeys[i], meta: true): LeafCopySlotIntent(i + 1),
  };

  /// Mapa enquanto um cartão está sendo escrito.
  static const editing = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): LeafCommitEditIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): LeafCommitEditIntent(),
    SingleActivator(LogicalKeyboardKey.escape): LeafCancelEditIntent(),
  };

  static Map<Type, Action<Intent>> actions({
    required VoidCallback onNewNote,
    required VoidCallback onActivate,
    required void Function({int columns, int rows}) onMoveSelection,
    required Future<void> Function(int slot) onCopySlot,
    required VoidCallback onDelete,
    required Future<void> Function() onClose,
    required VoidCallback onCommitEdit,
    required VoidCallback onCancelEdit,
    required Future<void> Function() onOpenSettings,
  }) {
    return <Type, Action<Intent>>{
      LeafNewNoteIntent: CallbackAction<LeafNewNoteIntent>(
        onInvoke: (_) => onNewNote(),
      ),
      LeafActivateIntent: CallbackAction<LeafActivateIntent>(
        onInvoke: (_) => onActivate(),
      ),
      LeafMoveSelectionIntent: CallbackAction<LeafMoveSelectionIntent>(
        onInvoke: (intent) =>
            onMoveSelection(columns: intent.columns, rows: intent.rows),
      ),
      LeafCopySlotIntent: CallbackAction<LeafCopySlotIntent>(
        onInvoke: (intent) => onCopySlot(intent.slot),
      ),
      LeafDeleteIntent: CallbackAction<LeafDeleteIntent>(
        onInvoke: (_) => onDelete(),
      ),
      LeafCloseIntent: CallbackAction<LeafCloseIntent>(
        onInvoke: (_) => onClose(),
      ),
      LeafCommitEditIntent: CallbackAction<LeafCommitEditIntent>(
        onInvoke: (_) => onCommitEdit(),
      ),
      LeafCancelEditIntent: CallbackAction<LeafCancelEditIntent>(
        onInvoke: (_) => onCancelEdit(),
      ),
      LeafOpenSettingsIntent: CallbackAction<LeafOpenSettingsIntent>(
        onInvoke: (_) => onOpenSettings(),
      ),
    };
  }
}

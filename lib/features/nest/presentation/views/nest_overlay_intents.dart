import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Manda a prateleira inteira para a pasta daquela posição.
class NestSendIntent extends Intent {
  const NestSendIntent(this.index);

  /// Zero-based; o `⌘1` é o índice 0.
  final int index;
}

/// Tira da prateleira o item selecionado. O arquivo não é tocado.
class NestRemoveIntent extends Intent {
  const NestRemoveIntent();
}

/// Esvazia a prateleira.
class NestClearIntent extends Intent {
  const NestClearIntent();
}

/// Desfaz a última transferência.
/// `⇧⌫`: tirar da prateleira o que sumiu do disco.
///
/// Vizinho do `⌫` (tira o escolhido) e do `⌘⌫` (esvazia): as três são a mesma
/// família — tirar linhas da prateleira sem tocar em arquivo nenhum —, e o
/// `⇧` é o que diz "esses aí" no lugar de "este" ou "todos".
class NestClearMissingIntent extends Intent {
  const NestClearMissingIntent();
}

class NestUndoIntent extends Intent {
  const NestUndoIntent();
}

/// Anda na lista. Com [extend], leva a escolha junto — o `⇧↑`/`⇧↓` de sempre.
class NestMoveCursorIntent extends Intent {
  const NestMoveCursorIntent(this.delta, {this.extend = false});

  final int delta;
  final bool extend;
}

/// Escolhe a prateleira inteira.
class NestSelectAllIntent extends Intent {
  const NestSelectAllIntent();
}

/// Mostra o original no Finder.
class NestRevealIntent extends Intent {
  const NestRevealIntent();
}

class NestCloseIntent extends Intent {
  const NestCloseIntent();
}

class NestOpenSettingsIntent extends Intent {
  const NestOpenSettingsIntent();
}

/// Mapa de teclado do painel do Nest.
///
/// O `⌘` escolhe o destino (`⌘1..⌘9`), como o `⌘1..⌘5` do Pin escolhe o item —
/// é o número que muda de significado, não a tecla. Por isso quem inverte
/// copiar/mover é o `⌥`, e ele não aparece aqui: não é um atalho, é uma
/// modificadora que o painel observa enquanto está pressionada.
///
/// O Enter manda para a primeira pasta. Todo painel do Evergreen tem uma
/// proposta única no Enter — no Awake é ligar, aqui é a pasta do topo da lista,
/// que é a que a pessoa pôs em primeiro lugar.
abstract final class NestOverlayIntents {
  /// Quantos destinos o teclado alcança. O mesmo teto da lista de pastas.
  static const maxShortcuts = 9;

  static final shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.escape): const NestCloseIntent(),
    const SingleActivator(LogicalKeyboardKey.enter): const NestSendIntent(0),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): const NestSendIntent(
      0,
    ),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const NestMoveCursorIntent(-1),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const NestMoveCursorIntent(1),
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        const NestMoveCursorIntent(-1, extend: true),
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        const NestMoveCursorIntent(1, extend: true),
    const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
        const NestSelectAllIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace):
        const NestRemoveIntent(),
    const SingleActivator(LogicalKeyboardKey.delete): const NestRemoveIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace, meta: true):
        const NestClearIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace, shift: true):
        const NestClearMissingIntent(),
    const SingleActivator(LogicalKeyboardKey.delete, shift: true):
        const NestClearMissingIntent(),
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
        const NestUndoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
        const NestRevealIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, meta: true):
        const NestOpenSettingsIntent(),
    for (var index = 0; index < maxShortcuts; index++)
      SingleActivator(_digits[index], meta: true): NestSendIntent(index),
    // Com o `⌥` segurado o atalho é outro para o Flutter, mas a intenção é a
    // mesma: o modo invertido não vem daqui, vem da modificadora que o painel
    // já está observando.
    for (var index = 0; index < maxShortcuts; index++)
      SingleActivator(_digits[index], meta: true, alt: true): NestSendIntent(
        index,
      ),
    const SingleActivator(LogicalKeyboardKey.enter, alt: true):
        const NestSendIntent(0),
  };

  static const _digits = <LogicalKeyboardKey>[
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

  static Map<Type, Action<Intent>> actions({
    required Future<void> Function(int index) onSend,
    required VoidCallback onRemove,
    required VoidCallback onClear,
    required VoidCallback onClearMissing,
    required Future<void> Function() onUndo,
    required void Function(int delta, {bool extend}) onMoveCursor,
    required VoidCallback onSelectAll,
    required Future<void> Function() onReveal,
    required Future<void> Function() onClose,
    required Future<void> Function() onOpenSettings,
  }) {
    return <Type, Action<Intent>>{
      NestSendIntent: CallbackAction<NestSendIntent>(
        onInvoke: (intent) => onSend(intent.index),
      ),
      NestRemoveIntent: CallbackAction<NestRemoveIntent>(
        onInvoke: (_) => onRemove(),
      ),
      NestClearIntent: CallbackAction<NestClearIntent>(
        onInvoke: (_) => onClear(),
      ),
      NestClearMissingIntent: CallbackAction<NestClearMissingIntent>(
        onInvoke: (_) => onClearMissing(),
      ),
      NestUndoIntent: CallbackAction<NestUndoIntent>(onInvoke: (_) => onUndo()),
      NestMoveCursorIntent: CallbackAction<NestMoveCursorIntent>(
        onInvoke: (intent) => onMoveCursor(intent.delta, extend: intent.extend),
      ),
      NestSelectAllIntent: CallbackAction<NestSelectAllIntent>(
        onInvoke: (_) => onSelectAll(),
      ),
      NestRevealIntent: CallbackAction<NestRevealIntent>(
        onInvoke: (_) => onReveal(),
      ),
      NestCloseIntent: CallbackAction<NestCloseIntent>(
        onInvoke: (_) => onClose(),
      ),
      NestOpenSettingsIntent: CallbackAction<NestOpenSettingsIntent>(
        onInvoke: (_) => onOpenSettings(),
      ),
    };
  }
}

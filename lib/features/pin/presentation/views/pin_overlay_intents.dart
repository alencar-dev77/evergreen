import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pin_quick_shortcut.dart';

/// Move a seleção na lista. [delta] é -1 (↑) ou +1 (↓).
class PinMoveSelectionIntent extends Intent {
  const PinMoveSelectionIntent(this.delta);

  final int delta;
}

/// Copia o item selecionado e fecha o overlay.
class PinActivateIntent extends Intent {
  const PinActivateIntent();
}

/// Fecha o overlay sem copiar nada.
class PinCloseIntent extends Intent {
  const PinCloseIntent();
}

/// Abre ou fecha a coluna de preview.
class PinTogglePreviewIntent extends Intent {
  const PinTogglePreviewIntent();
}

/// Copia direto o item na posição [number] do grupo [group].
class PinQuickCopyIntent extends Intent {
  const PinQuickCopyIntent(this.group, this.number);

  final PinShortcutGroup group;
  final int number;
}

/// Fixa ou desafixa o item selecionado.
class PinTogglePinIntent extends Intent {
  const PinTogglePinIntent();
}

/// Mapa de teclado do overlay.
///
/// Declarar as teclas como `Shortcuts` — e não como um `onKeyEvent` — é o que
/// permite sobrepor os atalhos padrão de edição de texto: as setas e o Enter
/// seriam consumidos pelo campo de busca antes de chegarem à lista.
abstract final class PinOverlayIntents {
  static final shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const PinMoveSelectionIntent(-1),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const PinMoveSelectionIntent(1),
    const SingleActivator(LogicalKeyboardKey.enter): const PinActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const PinActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const PinCloseIntent(),
    const SingleActivator(LogicalKeyboardKey.tab):
        const PinTogglePreviewIntent(),
    const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
        const PinTogglePinIntent(),
    ..._quickCopyShortcuts(),
  };

  /// `⌘1..⌘5` alcançam os recentes; `⌥1..⌥5`, os fixados.
  ///
  /// Duas camadas em vez de uma numeração corrida pela lista inteira: assim
  /// `⌘1` é sempre a última coisa copiada, não importa quantos itens estejam
  /// fixados acima dela.
  static Map<ShortcutActivator, Intent> _quickCopyShortcuts() {
    const digits = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];

    return {
      for (var slot = 0; slot < PinQuickShortcut.slotsPerGroup; slot++) ...{
        SingleActivator(digits[slot], meta: true):
            PinQuickCopyIntent(PinShortcutGroup.recent, slot + 1),
        SingleActivator(digits[slot], alt: true):
            PinQuickCopyIntent(PinShortcutGroup.pinned, slot + 1),
      },
    };
  }

  static Map<Type, Action<Intent>> actions({
    required void Function(int delta) onMove,
    required Future<void> Function() onActivate,
    required Future<void> Function() onClose,
    required VoidCallback onTogglePreview,
    required Future<void> Function(PinShortcutGroup group, int number)
        onQuickCopy,
    required VoidCallback onTogglePin,
  }) {
    return <Type, Action<Intent>>{
      PinMoveSelectionIntent: CallbackAction<PinMoveSelectionIntent>(
        onInvoke: (intent) {
          onMove(intent.delta);
          return null;
        },
      ),
      PinActivateIntent: CallbackAction<PinActivateIntent>(
        onInvoke: (_) => onActivate(),
      ),
      PinCloseIntent: CallbackAction<PinCloseIntent>(
        onInvoke: (_) => onClose(),
      ),
      PinTogglePreviewIntent: CallbackAction<PinTogglePreviewIntent>(
        onInvoke: (_) {
          onTogglePreview();
          return null;
        },
      ),
      PinQuickCopyIntent: CallbackAction<PinQuickCopyIntent>(
        onInvoke: (intent) => onQuickCopy(intent.group, intent.number),
      ),
      PinTogglePinIntent: CallbackAction<PinTogglePinIntent>(
        onInvoke: (_) {
          onTogglePin();
          return null;
        },
      ),
    };
  }
}

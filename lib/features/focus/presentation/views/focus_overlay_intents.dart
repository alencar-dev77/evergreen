import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Executa a ação principal do estado atual: iniciar, iniciar a pausa, voltar
/// ao foco. Sempre no Enter — a tecla que confirma o que a tela está propondo.
class FocusPrimaryIntent extends Intent {
  const FocusPrimaryIntent();
}

/// Pausa ou retoma a contagem.
class FocusTogglePauseIntent extends Intent {
  const FocusTogglePauseIntent();
}

/// Encerra a fase em andamento antes da hora.
class FocusStopIntent extends Intent {
  const FocusStopIntent();
}

/// Estende a sessão de foco em 5 minutos (uma única vez, na reta final).
class FocusExtendIntent extends Intent {
  const FocusExtendIntent();
}

/// Sai do painel. A sessão em andamento continua correndo.
class FocusCloseIntent extends Intent {
  const FocusCloseIntent();
}

/// Abre as preferências (Hub) e fecha o painel.
class FocusOpenSettingsIntent extends Intent {
  const FocusOpenSettingsIntent();
}

/// Mapa de teclado do painel do Focus.
///
/// O conjunto muda com o estado, e não por economia: `space` só vira "pausar"
/// quando não há campo de texto na tela. Com o campo de atividade ou de resumo
/// em foco, espaço é espaço — a regra de `ux.md` sobre teclas sem modificador
/// enquanto se digita.
abstract final class FocusOverlayIntents {
  /// [spaceTogglesPause] fica falso enquanto um campo de texto tem o foco:
  /// espaço então volta a ser espaço, e o Enter (que continua interceptado)
  /// vira "anotar" dentro do [FocusPrimaryIntent].
  static Map<ShortcutActivator, Intent> shortcuts({
    required bool spaceTogglesPause,
    required bool canExtend,
  }) {
    return <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.enter):
          const FocusPrimaryIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const FocusPrimaryIntent(),
      const SingleActivator(LogicalKeyboardKey.escape):
          const FocusCloseIntent(),
      // Convenção do macOS para cancelar o que está em curso.
      const SingleActivator(LogicalKeyboardKey.period, meta: true):
          const FocusStopIntent(),
      const SingleActivator(LogicalKeyboardKey.comma, meta: true):
          const FocusOpenSettingsIntent(),
      if (spaceTogglesPause)
        const SingleActivator(LogicalKeyboardKey.space):
            const FocusTogglePauseIntent(),
      if (canExtend) ...{
        // ⌘+ é a tecla de igual com meta — é assim que os apps do macOS
        // registram o atalho de "mais".
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            const FocusExtendIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
            const FocusExtendIntent(),
      },
    };
  }

  static Map<Type, Action<Intent>> actions({
    required VoidCallback onPrimary,
    required VoidCallback onTogglePause,
    required VoidCallback onStop,
    required VoidCallback onExtend,
    required Future<void> Function() onClose,
    required Future<void> Function() onOpenSettings,
  }) {
    return <Type, Action<Intent>>{
      FocusPrimaryIntent: CallbackAction<FocusPrimaryIntent>(
        onInvoke: (_) {
          onPrimary();
          return null;
        },
      ),
      FocusTogglePauseIntent: CallbackAction<FocusTogglePauseIntent>(
        onInvoke: (_) {
          onTogglePause();
          return null;
        },
      ),
      FocusStopIntent: CallbackAction<FocusStopIntent>(
        onInvoke: (_) {
          onStop();
          return null;
        },
      ),
      FocusExtendIntent: CallbackAction<FocusExtendIntent>(
        onInvoke: (_) {
          onExtend();
          return null;
        },
      ),
      FocusCloseIntent: CallbackAction<FocusCloseIntent>(
        onInvoke: (_) => onClose(),
      ),
      FocusOpenSettingsIntent: CallbackAction<FocusOpenSettingsIntent>(
        onInvoke: (_) => onOpenSettings(),
      ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A ação principal daquele estado: começar a gravar, ou parar e transcrever.
class EchoPrimaryIntent extends Intent {
  const EchoPrimaryIntent();
}

/// Desiste da gravação e joga o áudio fora (`⌘.`).
///
/// Separado do Esc de propósito: Esc fecha o painel e a reunião continua
/// gravando, que é o comportamento certo — a pessoa some com o painel para
/// voltar à reunião, não para cancelá-la. Descartar precisa ser um pedido
/// explícito, com modificadora.
class EchoDiscardIntent extends Intent {
  const EchoDiscardIntent();
}

/// Fecha o painel. A gravação, se houver, continua.
class EchoCloseIntent extends Intent {
  const EchoCloseIntent();
}

/// Abre as preferências (Hub) e fecha o painel.
class EchoOpenSettingsIntent extends Intent {
  const EchoOpenSettingsIntent();
}

/// Mapa de teclado do painel do Echo.
abstract final class EchoOverlayIntents {
  static const shortcuts = <ShortcutActivator, Intent>{
    // Sem repetição: o Enter é "gravar" num estado e "parar" no seguinte, e a
    // tecla segura um instante a mais pedia as duas coisas em sequência.
    SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
        EchoPrimaryIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false):
        EchoPrimaryIntent(),
    SingleActivator(LogicalKeyboardKey.escape): EchoCloseIntent(),
    SingleActivator(LogicalKeyboardKey.period, meta: true): EchoDiscardIntent(),
    SingleActivator(LogicalKeyboardKey.comma, meta: true):
        EchoOpenSettingsIntent(),
  };

  static Map<Type, Action<Intent>> actions({
    required Future<void> Function() onPrimary,
    required Future<void> Function() onDiscard,
    required Future<void> Function() onClose,
    required Future<void> Function() onOpenSettings,
  }) {
    return <Type, Action<Intent>>{
      EchoPrimaryIntent: CallbackAction<EchoPrimaryIntent>(
        onInvoke: (_) => onPrimary(),
      ),
      EchoDiscardIntent: CallbackAction<EchoDiscardIntent>(
        onInvoke: (_) => onDiscard(),
      ),
      EchoCloseIntent: CallbackAction<EchoCloseIntent>(
        onInvoke: (_) => onClose(),
      ),
      EchoOpenSettingsIntent: CallbackAction<EchoOpenSettingsIntent>(
        onInvoke: (_) => onOpenSettings(),
      ),
    };
  }
}

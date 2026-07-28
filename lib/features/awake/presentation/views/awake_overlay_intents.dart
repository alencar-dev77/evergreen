import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Liga ou desliga a trava. Sempre no Enter — a única proposta desta tela.
class AwakeToggleIntent extends Intent {
  const AwakeToggleIntent();
}

/// Anda uma opção na escala de durações.
class AwakeCycleDurationIntent extends Intent {
  const AwakeCycleDurationIntent(this.delta);

  final int delta;
}

/// Fecha o painel. A trava continua como estava.
class AwakeCloseIntent extends Intent {
  const AwakeCloseIntent();
}

/// Abre as preferências (Hub) e fecha o painel.
class AwakeOpenSettingsIntent extends Intent {
  const AwakeOpenSettingsIntent();
}

/// Mapa de teclado do painel do Awake.
///
/// Curto de propósito: o painel tem uma ação e um seletor.
///
/// As setas aparecem aqui **e** dentro do `EgSegmentedControl`, e isso não é
/// duplicação: o controle só as recebe quando ele próprio está focado, e o
/// painel abre com o foco nele mesmo. Sem este registro, o `← → duração` do
/// rodapé seria uma promessa que só se cumpre depois de um Tab. Quando o
/// controle tem o foco, ele trata a tecla primeiro e ela nunca chega até aqui.
abstract final class AwakeOverlayIntents {
  static const shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): AwakeToggleIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): AwakeToggleIntent(),
    SingleActivator(LogicalKeyboardKey.escape): AwakeCloseIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        AwakeCycleDurationIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowRight):
        AwakeCycleDurationIntent(1),
    SingleActivator(LogicalKeyboardKey.comma, meta: true):
        AwakeOpenSettingsIntent(),
  };

  static Map<Type, Action<Intent>> actions({
    required Future<void> Function() onToggle,
    required Future<void> Function(int delta) onCycleDuration,
    required Future<void> Function() onClose,
    required Future<void> Function() onOpenSettings,
  }) {
    return <Type, Action<Intent>>{
      AwakeToggleIntent: CallbackAction<AwakeToggleIntent>(
        onInvoke: (_) => onToggle(),
      ),
      AwakeCycleDurationIntent: CallbackAction<AwakeCycleDurationIntent>(
        onInvoke: (intent) => onCycleDuration(intent.delta),
      ),
      AwakeCloseIntent: CallbackAction<AwakeCloseIntent>(
        onInvoke: (_) => onClose(),
      ),
      AwakeOpenSettingsIntent: CallbackAction<AwakeOpenSettingsIntent>(
        onInvoke: (_) => onOpenSettings(),
      ),
    };
  }
}

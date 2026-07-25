import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/window/overlay_panel.dart';
import '../features/focus/presentation/views/focus_overlay_view.dart';
import '../features/pin/presentation/views/pin_overlay_view.dart';
import 'providers.dart';

/// Decide qual painel a janela flutuante mostra.
///
/// Trocar de painel é trocar de widget, não de janela: o atalho global de cada
/// módulo escreve em [overlayPanelProvider] antes de mandar a janela aparecer.
/// Sem transição entre um painel e outro — quem apertou `⌘⇧X` quer o Focus na
/// tela, não uma animação.
class OverlayHost extends ConsumerWidget {
  const OverlayHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(overlayPanelProvider)) {
      OverlayPanel.pin => const PinOverlayView(),
      OverlayPanel.focus => const FocusOverlayView(),
    };
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/window/overlay_panel.dart';
import '../core/window/overlay_window.dart';
import '../features/awake/presentation/views/awake_overlay_view.dart';
import '../features/echo/presentation/views/echo_overlay_view.dart';
import '../features/focus/presentation/views/focus_overlay_view.dart';
import '../features/leaf/presentation/views/leaf_overlay_view.dart';
import '../features/pin/presentation/views/pin_overlay_view.dart';
import '../features/home/presentation/viewmodels/app_settings_view_model.dart';
import 'providers.dart';

/// Decide qual painel a janela flutuante mostra.
///
/// Trocar de painel é trocar de widget, não de janela: o atalho global de cada
/// módulo escreve em [overlayPanelProvider] antes de mandar a janela aparecer.
/// Sem transição entre um painel e outro — quem apertou `⌘⇧F` quer o Focus na
/// tela, não uma animação.
///
/// O `Opacity` é o outro lado do quadro em branco descrito em
/// `OverlayWindow.hide`: enquanto a janela se esconde, o painel para de ser
/// desenhado sem ser desmontado — assim a superfície que o macOS guarda da
/// janela escondida não tem o painel antigo para mostrar quando ela reaparece.
class OverlayHost extends ConsumerStatefulWidget {
  const OverlayHost({super.key});

  @override
  ConsumerState<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends ConsumerState<OverlayHost> {
  @override
  void initState() {
    super.initState();

    // A aparência é escolhida no Hub, que é outro engine: quando um painel
    // aparece, ele relê o disco antes de desenhar. É a mesma armadilha da
    // instrução do resumo e do nome — cada engine tem a sua cópia em memória
    // das preferências, e esta janela nunca é avisada de nada.
    OverlayWindow.instance.isPanelHidden.addListener(_adoptSettings);
  }

  @override
  void dispose() {
    OverlayWindow.instance.isPanelHidden.removeListener(_adoptSettings);
    super.dispose();
  }

  void _adoptSettings() {
    if (OverlayWindow.instance.isPanelHidden.value) return;
    unawaited(
      ref.read(appSettingsViewModelProvider.notifier).refreshFromDisk(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = switch (ref.watch(overlayPanelProvider)) {
      OverlayPanel.pin => const PinOverlayView(),
      OverlayPanel.focus => const FocusOverlayView(),
      OverlayPanel.leaf => const LeafOverlayView(),
      OverlayPanel.awake => const AwakeOverlayView(),
      OverlayPanel.echo => const EchoOverlayView(),
    };

    return ValueListenableBuilder<bool>(
      valueListenable: OverlayWindow.instance.isPanelHidden,
      // O painel entra como `child` para ficar de fora da reconstrução: apagar
      // e reacender é só trocar a opacidade, nunca refazer a árvore.
      child: panel,
      builder: (context, isHidden, child) =>
          Opacity(opacity: isHidden ? 0 : 1, child: child),
    );
  }
}

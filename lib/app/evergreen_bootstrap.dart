import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/system/global_shortcut_service.dart';
import '../core/system/menu_bar_service.dart';
import '../core/system/startup_service.dart';
import '../core/window/hub_window.dart';
import '../core/window/pin_overlay_window.dart';
import '../features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import '../features/pin/presentation/viewmodels/pin_settings_view_model.dart';

/// Liga os serviços que rodam enquanto o Evergreen estiver aberto.
///
/// Tudo aqui vive no engine da janela 0 (o overlay do Pin), que nunca é
/// destruído — por isso a captura da área de transferência, o atalho global e o
/// ícone da barra de menus continuam funcionando com todas as janelas fechadas.
class EvergreenBootstrap {
  EvergreenBootstrap(this._container);

  final ProviderContainer _container;

  /// Fila de operações de janela, para que abrir e fechar nunca se cruzem.
  Future<void> _pending = Future<void>.value();

  Future<void> start() async {
    _container.read(pinOverlayViewModelProvider.notifier).startWatching();

    await _syncLaunchAtLogin();
    await _registerShortcuts();
    await _setUpMenuBar();
    await _openHubIfRequested();
  }

  Future<void> _registerShortcuts() async {
    final shortcuts = GlobalShortcutService.instance;
    await shortcuts.initialize();
    await shortcuts.registerPinToggle(togglePinOverlay);
  }

  Future<void> _setUpMenuBar() async {
    await MenuBarService.instance.initialize(onAction: _handleMenuAction);
  }

  /// Alinha a preferência salva com o estado real do sistema.
  ///
  /// O sistema é a autoridade: o usuário pode ter removido o Evergreen dos
  /// itens de início pelos Ajustes do macOS, e nesse caso é a preferência salva
  /// que está desatualizada — não o contrário.
  Future<void> _syncLaunchAtLogin() async {
    final actual = await StartupService.instance.isEnabled();

    await _container
        .read(pinSettingsViewModelProvider.notifier)
        .adoptSystemLaunchAtLogin(actual);
  }

  /// "Abrir minimizado" desligado significa mostrar o Hub ao iniciar.
  Future<void> _openHubIfRequested() async {
    if (_container.read(pinSettingsViewModelProvider).startMinimized) return;
    await HubWindow.instance.open();
  }

  /// Abre o overlay se estiver fechado, fecha se estiver aberto.
  ///
  /// Serializado: apertar o atalho duas vezes em sequência rápida faria as duas
  /// execuções lerem a visibilidade antes de qualquer uma mudá-la, e uma
  /// desfaria a outra.
  Future<void> togglePinOverlay() {
    return _pending = _pending
        .then((_) => _togglePinOverlay())
        .catchError((Object _) {});
  }

  Future<void> _togglePinOverlay() async {
    final overlay = PinOverlayWindow.instance;

    if (await overlay.isVisible()) {
      await overlay.hide();
      return;
    }

    _container.read(pinOverlayViewModelProvider.notifier).prepareForOpen();
    await overlay.show();
  }

  void _handleMenuAction(MenuBarAction action) {
    switch (action) {
      case MenuBarAction.openPin:
        togglePinOverlay();
      case MenuBarAction.openHub:
        HubWindow.instance.open();
      case MenuBarAction.quit:
        _quit();
    }
  }

  Future<void> _quit() async {
    await GlobalShortcutService.instance.dispose();
    await MenuBarService.instance.dispose();
    exit(0);
  }
}

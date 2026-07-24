import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

/// Ações que o menu da barra de status pode disparar.
enum MenuBarAction {
  openPin('open_pin', 'PIN'),
  openHub('open_hub', 'Preferências'),
  quit('quit', 'Encerrar Evergreen');

  const MenuBarAction(this.key, this.label);

  final String key;
  final String label;

  static MenuBarAction? fromKey(String? key) {
    for (final action in values) {
      if (action.key == key) return action;
    }
    return null;
  }
}

/// Ícone do Evergreen na barra de menus do macOS.
///
/// É a única presença permanente do app na tela — de onde o usuário abre o
/// painel do Pin, chega nas configurações e encerra o Evergreen.
class MenuBarService with TrayListener {
  MenuBarService._();

  static final instance = MenuBarService._();

  static const _iconPath = 'assets/icons/tray_icon.png';

  void Function(MenuBarAction action)? _onAction;

  Future<void> initialize({
    required void Function(MenuBarAction action) onAction,
  }) async {
    _onAction = onAction;
    trayManager.addListener(this);

    await trayManager.setIcon(_iconPath, isTemplate: true);
    await trayManager.setToolTip('Evergreen');
    await trayManager.setContextMenu(_buildMenu());
  }

  Menu _buildMenu() => Menu(
    items: [
      MenuItem(label: 'Evergreen', disabled: true),
      MenuItem(
        key: MenuBarAction.openPin.key,
        label: MenuBarAction.openPin.label,
      ),
      MenuItem(
        key: MenuBarAction.openHub.key,
        label: MenuBarAction.openHub.label,
      ),
      MenuItem.separator(),
      MenuItem(key: MenuBarAction.quit.key, label: MenuBarAction.quit.label),
    ],
  );

  @override
  void onTrayIconMouseDown() {
    // No macOS o clique esquerdo também deve abrir o menu.
    if (Platform.isMacOS) {
      trayManager.popUpContextMenu();
      return;
    }
    _onAction?.call(MenuBarAction.openPin);
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = MenuBarAction.fromKey(menuItem.key);
    if (action != null) _onAction?.call(action);
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}

import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// O Evergreen é um agente de background: fechar o Hub ou o overlay não pode
  /// encerrar o aplicativo. Só o item "Encerrar Evergreen" na barra de menus o
  /// faz.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

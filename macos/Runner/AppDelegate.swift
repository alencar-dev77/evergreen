import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// O item de início segue a cópia instalada, não a última build aberta.
  ///
  /// Antes do Flutter subir, porque a preferência de "iniciar com o macOS" é
  /// lida pelo Dart logo no arranque e deve encontrar o item já no lugar certo.
  /// Ver `LaunchAtLoginChannel.adoptInstalledBundle`.
  ///
  /// E antes dele, a oferta de mover para Aplicativos: aceita, este processo
  /// encerra aqui mesmo e quem adota o item é a cópia instalada.
  override func applicationWillFinishLaunching(_ notification: Notification) {
    AppLocationGuard.offerMoveIfNeeded()
    LaunchAtLoginChannel.adoptInstalledBundle()
    super.applicationWillFinishLaunching(notification)
  }

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

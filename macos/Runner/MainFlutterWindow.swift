import ApplicationServices
import Cocoa
import CoreGraphics
import FlutterMacOS
import ServiceManagement
import desktop_multi_window
import window_manager

/// Janela 0 do Evergreen: hospeda o overlay do Pin.
///
/// Nasce transparente e sem chrome porque tudo que ela mostra é o painel
/// flutuante desenhado pelo Flutter. O restante da configuração (posição,
/// nível, visibilidade) fica no lado Dart, em `PinOverlayWindow`.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // A superfície do Flutter é opaca por padrão. Sem zerá-la, a janela pinta
    // um retângulo preto atrás do painel — a transparência da NSWindow sozinha
    // não basta.
    flutterViewController.backgroundColor = .clear

    Self.registerChannels(for: flutterViewController)

    // Cada janela criada pelo desktop_multi_window roda um engine próprio, que
    // nasce sem plugin nenhum. Sem este callback o Hub não teria acesso a
    // SharedPreferences, ao banco ou a qualquer canal nativo.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      Self.registerChannels(for: controller)
      Self.applyHubGeometry(to: controller.view.window)
    }

    super.awakeFromNib()

    // Depois do super: o carregamento do nib redefine o fundo da janela.
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
  }

  private static func registerChannels(for controller: FlutterViewController) {
    RegisterGeneratedPlugins(registry: controller)
    LaunchAtLoginChannel.register(with: controller.engine.binaryMessenger)
    PreviousAppFocusChannel.register(with: controller.engine.binaryMessenger)
  }

  /// Dá ao Hub um tamanho de janela de preferências.
  ///
  /// O `desktop_multi_window` cria toda sub-janela com 800x600 fixos, sem
  /// tamanho mínimo e ancorada no canto — a `WindowConfiguration` do pacote só
  /// aceita `arguments` e `hiddenAtLaunch`, e o `WindowController` do Dart só
  /// expõe `show`/`hide`. Não há caminho em Flutter puro: `window_manager` age
  /// sobre a janela principal, que aqui é o overlay do Pin. Ver
  /// `docs/Ideis projeto/sugestoes-futuras-migracao-nativa.md`.
  ///
  /// Vale para qualquer sub-janela porque hoje só existe uma (o Hub). Quando
  /// aparecer uma segunda, a geometria precisará vir do lado Dart, por canal.
  private static func applyHubGeometry(to window: NSWindow?) {
    guard let window = window else { return }

    window.minSize = NSSize(width: 720, height: 480)
    window.setContentSize(NSSize(width: 880, height: 620))
    window.center()
  }

  /// Impede o flash da janela no lançamento: o overlay só aparece quando o
  /// usuário pede por ele.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}

/// Implementação nativa do canal `launch_at_startup`.
///
/// O pacote Dart `launch_at_startup` não embarca código macOS — ele espera que
/// o app forneça o canal. Usamos `SMAppService` (macOS 13+) em vez do pacote
/// LaunchAtLogin sugerido no README dele: é API do próprio sistema, não exige
/// dependência externa nem target auxiliar no Xcode.
enum LaunchAtLoginChannel {
  private static let channelName = "launch_at_startup"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(isEnabled())

      case "launchAtStartupSetEnabled":
        let arguments = call.arguments as? [String: Any]
        let enabled = arguments?["setEnabledValue"] as? Bool ?? false
        setEnabled(enabled, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func isEnabled() -> Bool {
    guard #available(macOS 13.0, *) else { return false }
    return SMAppService.mainApp.status == .enabled
  }

  private static func setEnabled(_ enabled: Bool, result: @escaping FlutterResult) {
    guard #available(macOS 13.0, *) else {
      result(
        FlutterError(
          code: "unsupported_os",
          message: "Iniciar com o macOS requer macOS 13 ou superior.",
          details: nil))
      return
    }

    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      result(nil)
    } catch {
      // Builds de desenvolvimento (fora de /Applications, sem assinatura
      // estável) costumam ser recusadas pelo sistema. O Dart trata isso como
      // "não foi possível ativar" em vez de quebrar.
      result(
        FlutterError(
          code: "login_item_failed",
          message: error.localizedDescription,
          details: nil))
    }
  }
}

/// Devolve o foco ao app anterior quando o overlay do Pin fecha.
///
/// Não existe equivalente em Flutter puro: `window_manager.show()` dispara
/// `NSApp.activate(ignoringOtherApps: true)`, que rouba o foco de quem quer
/// que estivesse digitando. Sem devolver esse foco explicitamente, o macOS não
/// garante que o app de origem (nem o cursor/seleção de texto que estava lá)
/// volte a ficar ativo — o usuário precisa clicar de novo no campo.
enum PreviousAppFocusChannel {
  private static let channelName = "previous_app_focus"
  private static var capturedApp: NSRunningApplication?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "capture":
        capture()
        result(nil)

      case "restore":
        restore()
        result(nil)

      case "restoreAndPaste":
        restoreAndPaste(result: result)

      case "hasAccessibilityPermission":
        result(AXIsProcessTrusted())

      case "requestAccessibilityPermission":
        // `true` no prompt abre o diálogo do sistema (e leva aos Ajustes) na
        // primeira vez que a permissão ainda não foi concedida.
        let options =
          [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
          as CFDictionary
        result(AXIsProcessTrustedWithOptions(options))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func capture() {
    capturedApp = NSWorkspace.shared.frontmostApplication
  }

  /// Devolve o foco ao app anterior e cola nele (⌘V sintético).
  ///
  /// Diferente do `restore`, aqui reativamos o app capturado sem exigir que o
  /// Evergreen ainda seja o frontmost: este caminho só é chamado quando o
  /// usuário selecionou um item de propósito, então trazer o app de volta e
  /// colar é exatamente o que ele pediu. Sem permissão de Acessibilidade não há
  /// como sintetizar a tecla — devolvemos um erro para o Dart tratar.
  private static func restoreAndPaste(result: @escaping FlutterResult) {
    guard AXIsProcessTrusted() else {
      capturedApp = nil
      result(
        FlutterError(
          code: "accessibility_denied",
          message: "Permissão de Acessibilidade necessária para colar automaticamente.",
          details: nil))
      return
    }

    let app = capturedApp
    capturedApp = nil
    if let app = app, !app.isTerminated {
      app.activate(options: [])
    }

    // Um respiro para o app anterior voltar a ser o frontmost antes do ⌘V — sem
    // isso a tecla pode chegar enquanto o Evergreen ainda está saindo de cena.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      sendPasteKeystroke()
      result(nil)
    }
  }

  /// Sintetiza um ⌘V no app em foco via CoreGraphics.
  private static func sendPasteKeystroke() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let vKeyCode: CGKeyCode = 0x09  // ANSI "v"

    guard
      let keyDown = CGEvent(
        keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
      let keyUp = CGEvent(
        keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
    else { return }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }

  /// Só reativa o app capturado se o Evergreen ainda for o frontmost.
  ///
  /// Se o usuário clicou em outro app enquanto o overlay estava aberto (o que
  /// fecha o overlay por perda de foco), esse outro app já é o frontmost aqui
  /// — reativar o app capturado nesse caso roubaria o foco de volta contra a
  /// vontade do usuário.
  private static func restore() {
    defer { capturedApp = nil }

    guard let app = capturedApp, !app.isTerminated else { return }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier
      == ProcessInfo.processInfo.processIdentifier
    else { return }

    app.activate(options: [])
  }
}

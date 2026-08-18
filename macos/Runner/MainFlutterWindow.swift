import ApplicationServices
import Cocoa
import CoreGraphics
import FlutterMacOS
import QuartzCore
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
    HubWindowChannel.register(with: controller.engine.binaryMessenger)
    PasteboardWatcherChannel.register(with: controller.engine.binaryMessenger)
    EchoChannel.register(with: controller.engine.binaryMessenger)
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

    window.minSize = NSSize(width: HubWindowChannel.baseMinWidth, height: 480)
    window.setContentSize(NSSize(width: 880, height: 620))
    HubWindowChannel.adopt(window)
  }

  /// Impede o flash da janela no lançamento: o overlay só aparece quando o
  /// usuário pede por ele.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}

/// Põe a janela do Hub na tela onde o usuário está.
///
/// `NSWindow.center()` — o que estava aqui antes — centraliza na tela em que a
/// janela *já* está, e uma sub-janela do `desktop_multi_window` nasce na origem
/// do sistema de coordenadas. Com dois monitores, isso significava o Hub abrir
/// no monitor de cima enquanto a pessoa trabalhava no de baixo: como o
/// `window_show` do pacote chama `NSApp.activate(ignoringOtherApps: true)`, o
/// foco do teclado ia para uma janela fora do campo de visão e o aplicativo
/// parecia travado.
///
/// A regra é a mesma que o painel flutuante já segue (`OverlayWindow`): quem
/// manda é a tela onde está o cursor. Só reposiciona quando a janela está
/// escondida — arrastar o Hub para um monitor e vê-lo pular de volta no próximo
/// atalho seria pior que o problema original.
///
/// Não tem equivalente em Flutter puro: `window_manager` age sobre a janela
/// principal (o overlay), e o `WindowController` do pacote só expõe
/// `show`/`hide`.
enum HubWindowChannel {
  private static let channelName = "hub_window"

  /// Fraca de propósito: quem retém a janela é o `desktop_multi_window`, e o
  /// Hub é destruído ao ser fechado.
  private static weak var window: NSWindow?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "moveToActiveDisplay":
        moveToActiveDisplay()
        result(nil)

      case "setDetailWidth":
        let width = (call.arguments as? [String: Any])?["width"] as? Double ?? 0
        setDetailWidth(CGFloat(width))
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Quanto a janela já cresceu para caber a região de leitura.
  ///
  /// Guardado aqui, e não deduzido da largura atual, porque a pessoa pode
  /// redimensionar a janela enquanto a região está aberta — o que precisa
  /// voltar ao fechar é exatamente o que foi somado ao abrir, não uma largura
  /// que o Dart imagina que a janela tem.
  private static var detailWidth: CGFloat = 0

  /// Largura mínima da janela sem a região aberta.
  static let baseMinWidth: CGFloat = 720

  /// Abre ou fecha a região dedicada, alargando a própria janela.
  ///
  /// A alternativa seria a região dividir a largura que já existe — foi o
  /// primeiro desenho, e ficou apertada: uma transcrição espremida em 350px ao
  /// lado de uma lista é pior que não ter região nenhuma. Aqui o conteúdo que
  /// já estava na tela não encolhe; o espaço novo vem da janela.
  ///
  /// Animado porque o contrário se lê como "a janela piscou": um salto de 480px
  /// sem transição não parece a mesma janela do quadro anterior.
  private static func setDetailWidth(_ width: CGFloat) {
    guard let window = window else { return }

    let delta = width - detailWidth
    if abs(delta) < 1 { return }
    detailWidth = width

    let screen = window.screen ?? activeScreen()
    let visible = screen.visibleFrame
    var frame = window.frame

    // Com a região aberta, a janela não pode ser arrastada para uma largura em
    // que ela não caiba: abaixo disso é a área de conteúdo que se espreme, e
    // linha de configuração espremida estoura o layout. Limitado à tela porque
    // um mínimo maior que o monitor deixaria a janela pendurada para fora dele.
    window.minSize.width = min(
      width > 0 ? baseMinWidth + width : baseMinWidth,
      visible.width)

    // Nunca mais larga que a área útil: num monitor estreito, crescer 480px
    // jogaria metade da janela para fora da tela.
    frame.size.width = min(frame.width + delta, visible.width)
    frame.size.width = max(frame.width, window.minSize.width)

    // Cresce para a direita enquanto couber; encostando na borda, é a janela
    // que anda para a esquerda, e não a região que encolhe.
    if frame.maxX > visible.maxX {
      frame.origin.x = max(visible.minX, visible.maxX - frame.width)
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.22
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      window.animator().setFrame(frame, display: true)
    }
  }

  /// Guarda a janela recém-criada e já a posiciona — na criação ela ainda está
  /// escondida, então este é o momento certo.
  static func adopt(_ window: NSWindow) {
    self.window = window
    // Janela nova nasce sem região de leitura aberta: o Hub é recriado a cada
    // abertura, e um resto de estado aqui somaria a largura duas vezes.
    detailWidth = 0
    moveToActiveDisplay()
  }

  private static func moveToActiveDisplay() {
    guard let window = window, !window.isVisible else { return }

    let screen = activeScreen()
    let visible = screen.visibleFrame
    let size = window.frame.size

    // Um pouco acima do centro vertical, como o painel flutuante e como o
    // próprio `center()` do AppKit: uma janela exatamente no meio parece baixa.
    let origin = NSPoint(
      x: visible.midX - size.width / 2,
      y: visible.midY - size.height / 2 + visible.height * 0.08)

    window.setFrameOrigin(origin)
  }

  /// A tela que contém o cursor, com a principal como reserva.
  private static func activeScreen() -> NSScreen {
    let cursor = NSEvent.mouseLocation

    return NSScreen.screens.first { NSMouseInRect(cursor, $0.frame, false) }
      ?? NSScreen.main ?? NSScreen.screens[0]
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

  /// Caminho do bundle a partir do qual registramos o item de início.
  ///
  /// O `SMAppService` diz se o item está ligado, mas não para onde ele aponta —
  /// e é isso que precisamos saber para descobrir que ele ficou para trás.
  private static let registeredPathKey = "evergreen.launchAtLogin.bundlePath"

  /// Só a cópia instalada manda no item de início.
  ///
  /// `SMAppService.mainApp` registra o bundle de quem chamou. Sem esta regra,
  /// abrir uma build de trabalho com o item ligado fazia o macOS passar a subir
  /// aquela build no login — e ela envelhece no lugar onde foi compilada,
  /// enquanto as correções seguem para `/Applications`. O sintoma é o pior de
  /// todos, porque não parece um bug: o app abre, funciona, e as correções
  /// simplesmente não estão nele.
  private static let installPrefix = "/Applications/"

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

  /// Reaponta o item de início para esta cópia, quando ela é a instalada.
  ///
  /// Chamada a cada abertura, mas só faz alguma coisa quando o caminho mudou —
  /// tipicamente uma vez, na primeira vez que o app é aberto de
  /// `/Applications` depois de o item ter sido ligado a partir de outro lugar.
  /// Ver [installPrefix] para o porquê da regra.
  static func adoptInstalledBundle() {
    guard #available(macOS 13.0, *) else { return }

    let path = Bundle.main.bundleURL.path
    guard path.hasPrefix(installPrefix) else { return }
    guard SMAppService.mainApp.status == .enabled else { return }

    let defaults = UserDefaults.standard
    guard defaults.string(forKey: registeredPathKey) != path else { return }

    do {
      try SMAppService.mainApp.register()
    } catch {
      // O sistema recusa registrar o que já está registrado, e é justamente
      // esse o caso aqui: o item existe, apontando para o lugar errado. Só
      // desfazendo o registro antigo o novo caminho entra no lugar.
      try? SMAppService.mainApp.unregister()

      guard (try? SMAppService.mainApp.register()) != nil else { return }
    }

    defaults.set(path, forKey: registeredPathKey)
  }

  /// Guarda de onde o item de início foi ligado — ver [adoptInstalledBundle].
  private static func rememberRegistration(enabled: Bool) {
    let defaults = UserDefaults.standard

    if enabled {
      defaults.set(Bundle.main.bundleURL.path, forKey: registeredPathKey)
    } else {
      defaults.removeObject(forKey: registeredPathKey)
    }
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
      rememberRegistration(enabled: enabled)
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

/// Observa a área de transferência e avisa o Dart a cada cópia nova.
///
/// O macOS não notifica mudança de pasteboard — nem em Swift. O que muda aqui é
/// **o que** se observa: `NSPasteboard.general.changeCount` é um inteiro que o
/// sistema incrementa a cada escrita, então a mudança *dele* é o evento. O lado
/// Dart comparava o conteúdo lido, e conteúdo não é evento:
///
/// - **recopiar a mesma coisa era invisível.** A string era igual à anterior,
///   o polling desistia e o item não subia para o topo da lista;
/// - **a leitura era cara.** Trazer a string inteira do pasteboard para o Dart
///   a cada 600ms atravessa o canal de plataforma; ler um inteiro não sai
///   daqui, e por isso pode ser feito com muito mais frequência.
///
/// A janela em que duas cópias muito rápidas viram uma só encolhe de 600ms para
/// [pollInterval] — mas não fecha: quando o `changeCount` pula mais de um entre
/// dois ciclos, o conteúdo intermediário já foi substituído no pasteboard e não
/// há de onde recuperá-lo. Não existe API de notificação que resolva isso; o que
/// existe é diminuir o intervalo, e a leitura barata é o que permite diminuir.
enum PasteboardWatcherChannel {
  private static let channelName = "pasteboard_watcher"

  /// Um ciclo é uma leitura de inteiro — três vezes mais frequente que o
  /// polling antigo e ainda assim mais barato que ele, que trazia a string
  /// inteira pelo canal de plataforma a cada volta.
  private static let pollInterval: TimeInterval = 0.2

  /// Deixa o sistema agrupar este timer com outros e acordar o processador
  /// menos vezes — o ciclo não tem hora certa, só um teto.
  private static let pollTolerance: TimeInterval = 0.05

  private static var timer: Timer?

  /// O canal do engine que pediu a captura.
  ///
  /// Cada engine registra o seu (a janela 0 e o Hub), mas só um chama `start` —
  /// o da janela 0, onde a captura vive. Guardar o canal de quem pediu é o que
  /// impede o aviso de sair pelo engine errado, onde ninguém escuta.
  private static weak var activeChannel: FlutterMethodChannel?

  private static var lastChangeCount = NSPasteboard.general.changeCount

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        start(pushingTo: channel)
        result(nil)

      case "stop":
        stop()
        result(nil)

      case "acknowledge":
        acknowledge(call.arguments as? String)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Começa a observar, avisando o que já está na área de transferência.
  ///
  /// O aviso inicial mantém o comportamento que o Dart tinha: o que estava
  /// copiado quando o Evergreen subiu entra no histórico. Sem ele, a primeira
  /// coisa do dia só seria registrada se a pessoa copiasse de novo.
  private static func start(pushingTo channel: FlutterMethodChannel) {
    activeChannel = channel

    guard timer == nil else { return }

    lastChangeCount = NSPasteboard.general.changeCount
    emitCurrentContent()

    let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
      poll()
    }
    timer.tolerance = pollTolerance
    self.timer = timer
  }

  private static func stop() {
    timer?.invalidate()
    timer = nil
  }

  /// Marca a escrita que o próprio Pin acabou de fazer como já conhecida.
  ///
  /// Só quando o pasteboard de fato contém [content]: se outro aplicativo
  /// copiou alguma coisa entre a nossa escrita e esta chamada, engolir o
  /// `changeCount` dele apagaria uma cópia de verdade do usuário.
  private static func acknowledge(_ content: String?) {
    let pasteboard = NSPasteboard.general

    guard content == nil || pasteboard.string(forType: .string) == content else { return }

    lastChangeCount = pasteboard.changeCount
  }

  private static func poll() {
    let changeCount = NSPasteboard.general.changeCount
    guard changeCount != lastChangeCount else { return }

    lastChangeCount = changeCount
    emitCurrentContent()
  }

  private static func emitCurrentContent() {
    guard let content = NSPasteboard.general.string(forType: .string) else { return }
    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    activeChannel?.invokeMethod("onCopy", arguments: content)
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

  /// Se o Evergreen ainda era o app da frente quando o fechamento começou.
  ///
  /// Tirado no início do `hide`, e não dentro do `restore`: esconder a janela
  /// já entrega a frente para outro app, então perguntar depois responde sobre
  /// o mundo *pós*-fechamento e o `restore` desistia achando que o usuário
  /// tinha trocado de app sozinho — era daí que vinha o "copiei e o foco não
  /// voltou".
  private static var wasFrontmostAtHide = false

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "capture":
        capture()
        result(nil)

      case "beginHide":
        noteFrontmost()
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

  /// Prazo máximo para o app anterior voltar a ser o frontmost.
  ///
  /// Generoso de propósito: um app pesado (Chrome, Xcode) pode demorar mais que
  /// os 120ms que este canal esperava antes — e um ⌘V disparado cedo demais vai
  /// para quem estiver na frente, que é justamente o bug de "às vezes não cola".
  private static let activationTimeout: TimeInterval = 0.8

  /// Prazo máximo esperando as modificadoras físicas serem soltas.
  private static let modifiersTimeout: TimeInterval = 0.6

  /// Intervalo entre duas verificações de estado.
  private static let pollInterval: TimeInterval = 0.02

  private static func capture() {
    let frontmost = NSWorkspace.shared.frontmostApplication

    // O próprio Evergreen não conta: com o Hub em foco, guardar a nós mesmos
    // faria o auto-colar digitar dentro das preferências.
    guard frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else {
      capturedApp = nil
      return
    }

    capturedApp = frontmost
  }

  /// Registra quem está na frente agora — ver [wasFrontmostAtHide].
  private static func noteFrontmost() {
    wasFrontmostAtHide =
      NSWorkspace.shared.frontmostApplication?.processIdentifier
      == ProcessInfo.processInfo.processIdentifier
  }

  /// Devolve o foco ao app anterior e cola nele (⌘V sintético).
  ///
  /// Diferente do `restore`, aqui reativamos o app capturado sem exigir que o
  /// Evergreen ainda seja o frontmost: este caminho só é chamado quando o
  /// usuário selecionou um item de propósito, então trazer o app de volta e
  /// colar é exatamente o que ele pediu.
  ///
  /// A colagem é confirmada em três passos, e não disparada num prazo fixo —
  /// era o prazo fixo que fazia o auto-colar funcionar "quase sempre":
  ///
  /// 1. pedimos a ativação (cedendo o turno explicitamente no macOS 14+, onde
  ///    ativar outro app "por fora" é ignorado em silêncio);
  /// 2. esperamos o app **realmente** virar o frontmost, verificando, em vez de
  ///    torcer para que 120ms bastem;
  /// 3. esperamos as modificadoras físicas serem soltas — o evento sintético é
  ///    postado no HID tap, onde ele se soma ao que estiver pressionado de
  ///    verdade: com o ⌥ do `⌥1` ainda no dedo, o app recebia ⌘⌥V e não colava
  ///    nada.
  ///
  /// Sem permissão de Acessibilidade não há como sintetizar a tecla, e sem
  /// conseguir devolver o foco não se cola às cegas — nos dois casos devolvemos
  /// erro, e o Dart cai no restore comum (o item já está na área de
  /// transferência de qualquer forma).
  private static func restoreAndPaste(result: @escaping FlutterResult) {
    // Em nenhum caminho de erro o app capturado é descartado: quem trata o erro
    // do outro lado é o `restore` comum, e sem o app guardado ele não teria a
    // quem devolver o foco. Era esse descarte que transformava "não consegui
    // colar" em "e ainda perdi o foco" — o caso mais comum de todos, já que a
    // permissão de Acessibilidade cai sozinha a cada build nova em
    // desenvolvimento.
    guard AXIsProcessTrusted() else {
      result(
        FlutterError(
          code: "accessibility_denied",
          message: "Permissão de Acessibilidade necessária para colar automaticamente.",
          details: nil))
      return
    }

    guard let app = capturedApp, !app.isTerminated else {
      result(
        FlutterError(
          code: "no_previous_app",
          message: "Nenhum aplicativo anterior para colar.",
          details: nil))
      return
    }

    activate(app)

    waitUntil(isFrontmost(app), timeout: activationTimeout) { activated in
      guard activated else {
        result(
          FlutterError(
            code: "activation_failed",
            message: "O aplicativo anterior não voltou ao foco a tempo.",
            details: nil))
        return
      }

      waitUntil(noModifiersPressed(), timeout: modifiersTimeout) { _ in
        // Mesmo com as modificadoras soltas, um respiro: o app acabou de ganhar
        // o foco e precisa ter o campo de texto pronto para receber a tecla.
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
          sendPasteKeystroke()
          capturedApp = nil
          result(nil)
        }
      }
    }
  }

  /// Traz um app para a frente.
  ///
  /// No macOS 14+ a ativação virou cooperativa: um app não tira o outro da
  /// frente sozinho. `yieldActivation` é o lado certo dessa conversa — somos
  /// nós que estamos entregando o turno, e é isso que o sistema espera ouvir.
  private static func activate(_ app: NSRunningApplication) {
    if #available(macOS 14.0, *) {
      NSApp.yieldActivation(to: app)
    }

    app.activate(options: [])
  }

  private static func isFrontmost(_ app: NSRunningApplication) -> () -> Bool {
    return {
      NSWorkspace.shared.frontmostApplication?.processIdentifier
        == app.processIdentifier
    }
  }

  /// Nenhuma modificadora pressionada no teclado físico.
  ///
  /// `combinedSessionState` é o estado real do hardware — é o mesmo que o
  /// sistema vai somar ao evento sintético.
  private static func noModifiersPressed() -> () -> Bool {
    return {
      let flags = CGEventSource.flagsState(.combinedSessionState)
      let modifiers: CGEventFlags = [
        .maskCommand, .maskShift, .maskAlternate, .maskControl,
      ]

      return flags.intersection(modifiers).isEmpty
    }
  }

  /// Verifica [condition] a cada [pollInterval] até ela valer ou o prazo
  /// vencer, e então chama [completion] dizendo qual dos dois aconteceu.
  ///
  /// Tudo na main queue: são leituras de estado do AppKit/CoreGraphics, e o
  /// custo de uma verificação a cada 20ms por meio segundo é irrelevante perto
  /// de colar no aplicativo errado.
  private static func waitUntil(
    _ condition: @escaping () -> Bool,
    timeout: TimeInterval,
    completion: @escaping (Bool) -> Void
  ) {
    let deadline = Date().addingTimeInterval(timeout)

    func check() {
      if condition() {
        completion(true)
        return
      }

      guard Date() < deadline else {
        completion(false)
        return
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval, execute: check)
    }

    check()
  }

  /// Sintetiza um ⌘V no app em foco via CoreGraphics.
  ///
  /// A fonte é `privateState`, e não `combinedSessionState`: a segunda herda o
  /// estado do teclado físico, e é dela que vinham as modificadoras extras
  /// grudadas no ⌘V.
  private static func sendPasteKeystroke() {
    let source = CGEventSource(stateID: .privateState)
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

  /// Só reativa o app capturado se o Evergreen ainda era o frontmost quando o
  /// fechamento começou.
  ///
  /// Se o usuário clicou em outro app enquanto o overlay estava aberto (o que
  /// fecha o overlay por perda de foco), esse outro app já era o frontmost lá
  /// — reativar o app capturado nesse caso roubaria o foco de volta contra a
  /// vontade do usuário.
  ///
  /// Quem responde é o instantâneo de [wasFrontmostAtHide], não o estado de
  /// agora: neste ponto a janela já saiu da tela e a frente já mudou de dono.
  private static func restore() {
    defer {
      capturedApp = nil
      wasFrontmostAtHide = false
    }

    guard wasFrontmostAtHide else { return }
    guard let app = capturedApp, !app.isTerminated else { return }

    activate(app)
  }
}

import ApplicationServices
import Cocoa
import CoreGraphics
import FlutterMacOS
import IOKit.pwr_mgt
import QuartzCore
import ServiceManagement
import desktop_multi_window
import window_manager

/// Janela 0 do Evergreen: hospeda os painéis flutuantes (Pin, Focus, Leaf,
/// Awake e Echo).
///
/// Nasce transparente e sem chrome porque tudo que ela mostra é o painel
/// flutuante desenhado pelo Flutter. Posição e visibilidade continuam vindo do
/// lado Dart, em `OverlayWindow`.
///
/// É um `NSPanel`, e não uma `NSWindow`, por causa de um único bit do
/// `styleMask`: `.nonactivatingPanel`, que só existe em painel. Sem ele, o
/// painel que recebe o teclado **desativa** o aplicativo que estava na frente —
/// e abrir o Focus no meio de uma sessão de 25 minutos fazia piscar justamente
/// o app em que a pessoa estava tentando focar.
///
/// O bit sozinho não basta: ele governa o que acontece quando alguém *clica* no
/// painel, e o `show()` do `window_manager` ativa o aplicativo por conta
/// própria. Por isso quem exibe a janela é o `OverlayWindowChannel`, não o
/// pacote. Os dois lados são necessários; um sem o outro não muda nada.
///
/// O `MainMenu.xib` continua com um elemento `<window>`: o documento está no
/// formato do Xcode 8 e o `ibtool` recusa `<panel>` nele ("Unknown element
/// name"). Não faz diferença — quem o nib instancia é o `customClass`, esta
/// classe, e o `styleMask` de painel é aplicado em `makeNonActivating`.
class MainFlutterWindow: NSPanel {
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

    Self.makeNonActivating(self)
    OverlayWindowChannel.adopt(self)
  }

  /// Faz da janela 0 um painel que não tira ninguém da frente.
  ///
  /// - `.nonactivatingPanel`: recebe teclado sem ativar o Evergreen.
  /// - `becomesKeyOnlyIfNeeded = false`: o painel precisa virar key assim que
  ///   aparece, senão a primeira tecla digitada (a busca do Pin, o Esc) se
  ///   perde — o padrão do `NSPanel` é o contrário, esperar um campo de texto
  ///   ser clicado.
  /// - `hidesOnDeactivate = false`: o padrão do painel é sumir quando o app sai
  ///   da frente, e aqui o app **está sempre** fora da frente. Quem esconde a
  ///   janela é o `OverlayWindow`, mais ninguém.
  /// - `level = .statusBar`: acima de app em tela cheia, que é o cenário de
  ///   quem está numa sessão de foco ou numa reunião com o Awake ligado.
  ///   `setAlwaysOnTop` do `window_manager` só alcança `.floating`, por isso o
  ///   nível saiu do lado Dart e passou a morar aqui.
  /// - `collectionBehavior`: aparecer em qualquer Space sem arrastar o Space
  ///   de volta junto.
  private static func makeNonActivating(_ panel: NSPanel) {
    panel.styleMask.insert(.nonactivatingPanel)
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = false
    panel.hidesOnDeactivate = false
    panel.level = .statusBar
    panel.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
  }

  private static func registerChannels(for controller: FlutterViewController) {
    RegisterGeneratedPlugins(registry: controller)
    LaunchAtLoginChannel.register(with: controller.engine.binaryMessenger)
    PreviousAppFocusChannel.register(with: controller.engine.binaryMessenger)
    HubWindowChannel.register(with: controller.engine.binaryMessenger)
    OverlayWindowChannel.register(with: controller.engine.binaryMessenger)
    PasteboardWatcherChannel.register(with: controller.engine.binaryMessenger)
    SleepAssertionChannel.register(with: controller.engine.binaryMessenger)
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

/// Exibe a janela 0 sem ativar o Evergreen.
///
/// Não tem equivalente em Flutter puro, e nem sequer é resolvido pelo
/// `styleMask` do painel: o `show()` do `window_manager` chama
/// `NSApp.activate(ignoringOtherApps: true)` de forma incondicional, e é essa
/// chamada — não o estilo da janela — que tira o app anterior da frente. Um
/// `NSPanel` não-ativante só decide o que acontece quando alguém clica no
/// painel; uma ativação pedida no braço acontece do mesmo jeito.
///
/// O que sobra aqui é o mínimo: pôr a janela na tela e entregar o teclado a
/// ela. É o que faz o painel se comportar como uma camada sobre o sistema, em
/// vez de um app que chega empurrando.
enum OverlayWindowChannel {
  private static let channelName = "overlay_window"

  /// Fraca por simetria com o `HubWindowChannel`: quem retém a janela 0 é o
  /// `NSApp`, e ela nunca é destruída — só escondida.
  private static weak var panel: NSPanel?

  /// Guarda a janela 0. Chamada pelo `MainFlutterWindow`, que é ela mesma.
  ///
  /// Também é aqui que o realinhamento das modificadoras se pendura — ver
  /// [resyncModifiers]. Pela notificação, e não pelo `show` deste canal, porque
  /// o que importa é o painel *ganhar o teclado*, seja pelo atalho global ou
  /// por um clique nele. O delegate da janela é do `window_manager`, então a
  /// notificação é o caminho que não disputa com ele.
  static func adopt(_ window: NSPanel) {
    panel = window

    NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: window,
      queue: .main
    ) { _ in resyncModifiers() }
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "show":
        show(result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Põe o painel na frente e entrega o teclado a ele, sem ativar o aplicativo.
  ///
  /// `orderFrontRegardless`, e não `orderFront`: com o Evergreen inativo — que
  /// aqui é o caso normal, e não a exceção — o `orderFront` fica na fila
  /// esperando uma ativação que não vem, e o atalho pareceria não fazer nada.
  ///
  /// `makeKey` sem `orderFront` junto: o `makeKeyAndOrderFront` reordena de
  /// novo, com a regra que acabamos de contornar.
  private static func show(result: @escaping FlutterResult) {
    guard let panel = panel else {
      result(
        FlutterError(
          code: "no_overlay_window",
          message: "A janela do overlay ainda não existe.",
          details: nil))
      return
    }

    panel.setIsVisible(true)
    panel.orderFrontRegardless()
    panel.makeKey()

    // A view do Flutter de volta como first responder.
    //
    // Ser key não basta: quem recebe a tecla é o first responder da janela, e
    // ele não sobrevive garantidamente a um `orderOut` — que é como o painel se
    // esconde, dezenas de vezes por dia. Com a janela key e o responder perdido,
    // a tecla sobe a cadeia sem ninguém para tratá-la e o macOS responde com o
    // bipe de "não posso": o painel fica na tela, visivelmente aberto, e mudo.
    //
    // Só quando já não é ela: `makeFirstResponder` desfaz a seleção de texto do
    // campo que estiver em foco, e reexibir o painel não pode mexer no que a
    // pessoa deixou escrito.
    if let view = panel.contentViewController?.view, panel.firstResponder !== view {
      panel.makeFirstResponder(view)
    }

    result(nil)
  }

  /// Código de tecla propositalmente fora do mapa do Flutter — ver
  /// [resyncModifiers].
  ///
  /// O evento sintético precisa de um `keyCode`, e ele não pode ser o de uma
  /// tecla de verdade: o engine olha se aquela tecla está no registro de
  /// pressionadas e, se estiver, emite um "soltou" por conta dela. Com `⌘` ou
  /// com uma letra que a pessoa esteja segurando, o realinhamento arrancaria a
  /// tecla da mão dela. Um código que não existe nunca está no registro, então
  /// a única coisa que o evento provoca é o acerto de contas.
  private static let resyncKeyCode: UInt16 = 0xFF

  /// Realinha o registro de modificadoras do Flutter com o teclado físico.
  ///
  /// Sem isto, `⌘2`, `⌥1`, `⌘P` e companhia falham calados no painel aberto
  /// pelo atalho global, e o macOS responde com o bipe de comando inexistente.
  ///
  /// O motivo: `SingleActivator` não olha as modificadoras do evento que
  /// chegou — ele compara com `HardwareKeyboard.logicalKeysPressed`, o estado
  /// que o Flutter foi acumulando tecla a tecla. E a janela 0 só presencia as
  /// modificadoras que sobem e descem **enquanto ela é a key window**. O
  /// `⌘⇧C` acontece antes disso: o Carbon come o atalho com outro app na
  /// frente, e o painel nasce depois, com as teclas já afundadas e sem
  /// registro nenhum delas. O `⌘` do `⌘2` seguinte é, para o Flutter, um `2`
  /// sozinho — e nenhum atalho casa. O Esc continua funcionando porque ele é o
  /// único que não exige modificadora alguma, e foi esse contraste que
  /// entregou o diagnóstico.
  ///
  /// Até a v0.4 isso não acontecia: o `show()` do `window_manager` chamava
  /// `NSApp.activate(ignoringOtherApps: true)`, e ativar o aplicativo é o que
  /// faz o AppKit entregar o ciclo inteiro das teclas a ele. O painel
  /// não-ativante trouxe de volta o app que não pisca — e junto o teclado que
  /// a janela 0 só enxerga pela metade.
  ///
  /// A correção é um `flagsChanged` sintético com o estado real das
  /// modificadoras. Ele atravessa `FlutterViewController.flagsChanged:` e cai
  /// no `synchronizeModifiers` do engine, que é a rotina que o próprio Flutter
  /// usa para reconciliar esse registro (ela roda em todo evento de mouse, e é
  /// por isso que clicar no painel também conserta). Consertar do lado Dart não
  /// é possível: `HardwareKeyboard.syncKeyboardState` só *acrescenta* teclas, e
  /// `clearState` é de teste e leva os handlers do teclado junto.
  private static func resyncModifiers() {
    guard let panel = panel else { return }

    guard
      let event = NSEvent.keyEvent(
        with: .flagsChanged,
        location: .zero,
        modifierFlags: currentModifierFlags(),
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: panel.windowNumber,
        context: nil,
        characters: "",
        charactersIgnoringModifiers: "",
        isARepeat: false,
        keyCode: resyncKeyCode)
    else { return }

    // Postado, e não entregue no braço: aqui ainda estamos dentro da virada de
    // key status, e o primeiro respondedor pode não ser o do Flutter ainda.
    NSApp.postEvent(event, atStart: false)
  }

  /// O que está pressionado agora, de verdade.
  ///
  /// As duas fontes somadas porque contam metades diferentes da mesma história:
  /// `NSEvent.modifierFlags` traz os bits genéricos (⌘, ⇧, ⌥) e o
  /// `CGEventSource` traz os de esquerda e direita — que são justamente os que
  /// o engine compara para decidir *qual* tecla sintetizar.
  private static func currentModifierFlags() -> NSEvent.ModifierFlags {
    let sided = CGEventSource.flagsState(.combinedSessionState).rawValue

    return NSEvent.ModifierFlags(
      rawValue: NSEvent.modifierFlags.rawValue | UInt(sided))
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

  /// O que a abertura da região ficou devendo à janela: quanto ela não
  /// conseguiu crescer (a tela era mais estreita que a soma) e quanto precisou
  /// andar de lado para não vazar da borda.
  ///
  /// Pago de volta no fechamento. Sem isso, abrir e fechar a região deixava a
  /// janela um pouco mais estreita e um pouco mais para o lado a cada volta —
  /// era daí que vinha o "expande centralizado, mas não volta centralizado":
  /// o desenho antigo devolvia a largura pelo mesmo delta que somou, mas nunca
  /// desfazia o passo lateral que deu para caber na tela.
  private static var widthDebt: CGFloat = 0
  private static var originDebt: CGFloat = 0

  /// Para onde a janela está indo, enquanto a animação corre.
  ///
  /// `window.frame` durante uma animação devolve o quadro **do meio do
  /// caminho**. Quem abre uma reunião e aperta `esc` antes dos 220ms terminarem
  /// faria a conta de fechar em cima de uma largura que não é nem a de antes
  /// nem a de depois — e a janela terminaria num tamanho que ninguém pediu.
  /// `nil` fora da animação, quando quem manda é o quadro real (a pessoa pode
  /// ter redimensionado a janela na mão).
  private static var animatedFrame: NSRect?

  /// Abre ou fecha a região dedicada, alargando a própria janela.
  ///
  /// A alternativa seria a região dividir a largura que já existe — foi o
  /// primeiro desenho, e ficou apertada: uma transcrição espremida em 350px ao
  /// lado de uma lista é pior que não ter região nenhuma. Aqui o conteúdo que
  /// já estava na tela não encolhe; o espaço novo vem da janela.
  ///
  /// Animado porque o contrário se lê como "a janela piscou": um salto de 480px
  /// sem transição não parece a mesma janela do quadro anterior.
  ///
  /// A janela cresce **em torno do próprio centro**, metade para cada lado, e
  /// volta pelo mesmo caminho. O primeiro desenho crescia só para a direita e
  /// devolvia a largura sem desfazer o passo lateral que deu para caber na
  /// tela: a janela saía do meio ao abrir a reunião e voltava torta ao fechar,
  /// como se tivesse sido arrastada sozinha. Quem abre o Hub o vê centralizado;
  /// abrir e fechar uma reunião não é motivo para ele deixar de estar.
  private static func setDetailWidth(_ width: CGFloat) {
    guard let window = window else { return }

    let delta = width - detailWidth
    if abs(delta) < 1 { return }

    // Fechar é o momento de acertar as contas: a janela volta ao tamanho e ao
    // lugar de antes, não a um lugar parecido.
    let isClosing = width <= 0
    detailWidth = width

    let screen = window.screen ?? activeScreen()
    let visible = screen.visibleFrame
    var frame = animatedFrame ?? window.frame

    // Com a região aberta, a janela não pode ser arrastada para uma largura em
    // que ela não caiba: abaixo disso é a área de conteúdo que se espreme, e
    // linha de configuração espremida estoura o layout. Limitado à tela porque
    // um mínimo maior que o monitor deixaria a janela pendurada para fora dele.
    window.minSize.width = min(
      width > 0 ? baseMinWidth + width : baseMinWidth,
      visible.width)

    // O centro de agora é o centro depois: é ele que a janela preserva ao
    // crescer e ao voltar. Lido do quadro atual, e não guardado da abertura,
    // para que arrastar a janela com a região aberta continue valendo.
    let center = frame.midX

    var targetWidth = frame.width + delta
    if isClosing {
      targetWidth += widthDebt
      widthDebt = 0
    }

    // Nunca mais larga que a área útil: num monitor estreito, crescer 480px
    // jogaria metade da janela para fora da tela.
    frame.size.width = min(targetWidth, visible.width)
    frame.size.width = max(frame.width, window.minSize.width)
    if !isClosing { widthDebt += targetWidth - frame.width }

    var targetX = center - frame.width / 2
    if isClosing {
      targetX -= originDebt
      originDebt = 0
    }

    // Encostando numa borda, é a janela que anda para dentro da tela — a região
    // não encolhe por isso. O mínimo vem por último porque, numa tela mais
    // estreita que a janela, é a borda esquerda que precisa ganhar.
    frame.origin.x = min(targetX, visible.maxX - frame.width)
    frame.origin.x = max(frame.origin.x, visible.minX)
    if !isClosing { originDebt += frame.origin.x - targetX }

    animatedFrame = frame

    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.22
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      window.animator().setFrame(frame, display: true)
    }, completionHandler: {
      // A partir daqui quem manda é o quadro real: a pessoa pode redimensionar
      // ou arrastar a janela, e a próxima conta precisa partir de onde ela
      // está de verdade.
      if animatedFrame == frame { animatedFrame = nil }
    })
  }

  /// Guarda a janela recém-criada e já a posiciona — na criação ela ainda está
  /// escondida, então este é o momento certo.
  static func adopt(_ window: NSWindow) {
    self.window = window
    // Janela nova nasce sem região de leitura aberta: o Hub é recriado a cada
    // abertura, e um resto de estado aqui somaria a largura duas vezes.
    detailWidth = 0
    widthDebt = 0
    originDebt = 0
    animatedFrame = nil
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

/// Segura o Mac acordado enquanto a trava do Awake estiver ligada.
///
/// Duas travas diferentes, e é essa escolha que não existe em Flutter puro: o
/// `wakelock_plus` sempre registra a de tela. Manter o **sistema** acordado com
/// a tela apagada — o build da madrugada, o download grande — é outro tipo de
/// assertion do IOKit, e o pacote não expõe qual usar.
///
/// Uma assertion por processo: ligar num modo com o outro valendo troca a que
/// existe, em vez de empilhar duas. O `IOPMAssertionRelease` da anterior vem
/// **depois** de a nova estar registrada, para não abrir uma janela em que o
/// Mac pode suspender no meio da troca.
///
/// Estático de propósito, como os outros canais daqui: a trava é do processo, e
/// os dois engines (a janela 0 e o Hub) registram o mesmo canal.
enum SleepAssertionChannel {
  private static let channelName = "sleep_assertion"

  /// A assertion viva, ou `kIOPMNullAssertionID` quando não há nenhuma.
  private static var assertion: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

  /// Aparece no `pmset -g assertions`, que é onde se investiga "por que este
  /// Mac não dorme" — o nome precisa dizer quem foi.
  private static let reason = "Evergreen: Awake" as CFString

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "enable":
        let keepsScreenOn = (call.arguments as? String) != "system"
        if enable(keepingScreenOn: keepsScreenOn) {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "assertion_failed",
              message: "O sistema recusou a trava de energia.",
              details: nil
            )
          )
        }

      case "disable":
        disable()
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func enable(keepingScreenOn: Bool) -> Bool {
    let type =
      keepingScreenOn
      ? kIOPMAssertionTypePreventUserIdleDisplaySleep
      : kIOPMAssertionTypePreventUserIdleSystemSleep

    var created: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    let status = IOPMAssertionCreateWithName(
      type as CFString,
      IOPMAssertionLevel(kIOPMAssertionLevelOn),
      reason,
      &created
    )
    guard status == kIOReturnSuccess else { return false }

    // Só agora: entre a criação da nova e a liberação da antiga o Mac está
    // coberto pelas duas, que é o lado certo de errar.
    disable()
    assertion = created

    return true
  }

  private static func disable() {
    guard assertion != IOPMAssertionID(kIOPMNullAssertionID) else { return }

    IOPMAssertionRelease(assertion)
    assertion = IOPMAssertionID(kIOPMNullAssertionID)
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

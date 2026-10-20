import Cocoa
import FlutterMacOS

/// Onde fica o recorte da câmera, quando há um.
///
/// Não existe API de recorte. Do macOS 12 em diante o que existe é
/// `safeAreaInsets.top > 0` para saber se há um, e as duas faixas auxiliares do
/// topo (`auxiliaryTopLeftArea`, `auxiliaryTopRightArea`) para achar onde ele
/// começa e termina — o que sobra entre as duas é o recorte.
///
/// **As duas faixas são opcionais, e nulo não é zero.** Tratar uma delas como
/// largura zero faz o recorte virar a tela inteira: um alvo invisível cobrindo
/// a barra de menus. Foi a rede que o documento do Nest pediu para quem fizesse
/// isto voltar, e por isso qualquer dúvida aqui responde "não há recorte".
///
/// A conta usa só as **larguras** das faixas, nunca a posição delas: a
/// documentação não diz em que espaço de coordenadas elas vêm, e a largura é a
/// mesma em qualquer um.
struct NotchGeometry {
  let screen: NSScreen

  /// O recorte, em coordenadas globais do AppKit (origem embaixo à esquerda):
  /// a largura entre as duas faixas, e a altura da barra de menus.
  let rect: NSRect

  /// O recorte da tela que tem um. Em Mac sem recorte, ou com a tampa fechada
  /// e só o monitor externo ligado, `nil` — e todo o resto do notch some com
  /// ele, sem notch virtual.
  static func current() -> NotchGeometry? {
    for screen in NSScreen.screens {
      let height = screen.safeAreaInsets.top
      guard height > 0,
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
      else { continue }

      let frame = screen.frame
      let width = frame.width - left.width - right.width

      // Um recorte de verdade é estreito. Metade da tela já é uma resposta
      // errada do sistema, e um alvo desse tamanho é exatamente o desastre
      // descrito acima.
      guard width > 0, width < frame.width / 2 else { continue }

      return NotchGeometry(
        screen: screen,
        rect: NSRect(
          x: frame.minX + left.width,
          y: frame.maxY - height,
          width: width,
          height: height))
    }

    return nil
  }
}

/// A ilha do notch: o que está rodando, desenhado em volta do recorte.
///
/// **Uma segunda janela sempre no topo, e a exceção é de propósito.** A regra
/// da casa é "só a janela 0", e ela protege engine e superfície viva — o custo
/// de memória de um segundo Flutter residente e o de uma superfície que desenha
/// o tempo todo. Esta janela não tem engine: é AppKit puro, com meia dúzia de
/// views, e só existe na tela enquanto alguma coisa está rodando. A janela 0
/// não serve porque é compartilhada — abrir o Pin a tiraria do recorte no meio
/// da reunião. Ver `docs/Ideis projeto/notch.md`.
///
/// **O Dart diz o quê; o Swift só desenha.** Os rótulos, o relógio formatado,
/// as cores e a ordem de prioridade chegam prontos pelo canal: o texto da
/// interface continua morando num lugar só, e a paleta continua sendo a dos
/// tokens.
enum NotchIslandChannel {
  private static let channelName = "notch_island"

  /// O canal da janela 0, que é quem atende os botões da ilha.
  ///
  /// **Forte**, pela mesma lição cara do `NestChannel`: um `FlutterMethodChannel`
  /// não é retido por ninguém, e uma referência fraca aqui faria tudo o que vem
  /// do Dart funcionar e tudo o que vai para ele cair no vazio.
  private static var overlayChannel: FlutterMethodChannel?

  /// Os módulos que a pessoa quer ver no notch. Mora aqui, e não no Dart da
  /// janela 0, porque quem muda é o Hub — outro engine —, e o lado nativo é o
  /// único lugar que os dois enxergam igual. É o mesmo arranjo do chacoalhar.
  private static var enabledModules: Set<String> = []

  /// Tudo o que está rodando, na ordem de prioridade que o Dart decidiu. A ilha
  /// mostra o primeiro cujo módulo está ligado no notch.
  private static var activities: [NotchActivity] = []

  private static var palette = NotchPalette()

  private static var island: NotchIslandController?

  private static var screenObserver: NSObjectProtocol?

  static func register(with messenger: FlutterBinaryMessenger, isOverlay: Bool) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    if isOverlay { overlayChannel = channel }

    if screenObserver == nil {
      // A tampa fecha, o monitor externo vira o principal, a resolução muda: o
      // recorte pode sumir ou mudar de lugar, e a ilha vai junto.
      screenObserver = NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
      ) { _ in
        island?.dismiss()
        island = nil
        refresh()
      }
    }

    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]

      switch call.method {
      case "hasNotch":
        result(NotchGeometry.current() != nil)

      case "shown":
        result(shownModule)

      case "setEnabled":
        guard let module = arguments?["module"] as? String else {
          result(nil)
          return
        }
        if arguments?["enabled"] as? Bool ?? false {
          enabledModules.insert(module)
        } else {
          enabledModules.remove(module)
        }
        refresh()
        result(nil)

      case "configure":
        palette = NotchPalette(arguments ?? [:])
        island?.apply(palette)
        result(nil)

      case "setQuiet":
        setQuiet(arguments?["quiet"] as? Bool ?? false)
        result(nil)

      case "update":
        let list = arguments?["activities"] as? [[String: Any]] ?? []
        activities = list.compactMap(NotchActivity.init)
        refresh()
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Tira a ilha do caminho do mouse (e a recolhe) enquanto um arraste que
  /// chamou a prateleira pelo notch está em curso.
  ///
  /// Guardado aqui, e não só na ilha da vez: a ilha pode ser refeita no meio
  /// do arraste (o Focus começa, a tela muda), e a nova precisa nascer fora
  /// do caminho também.
  static func setPassThrough(_ passThrough: Bool) {
    isDragging = passThrough
    island?.setPassThrough(isDragging || isQuiet)
  }

  /// A pilha do Nest está aberta embaixo do recorte: a ilha fica em cima dela,
  /// e não pode abrir por cima do cabeçalho e das pastas. Quem diz é o Dart,
  /// que sabe quando a pilha está na tela.
  static func setQuiet(_ quiet: Bool) {
    isQuiet = quiet
    island?.setPassThrough(isDragging || isQuiet)
  }

  private static var isDragging = false
  private static var isQuiet = false

  private static var isPassThrough: Bool { isDragging || isQuiet }

  /// Um botão da ilha foi apertado, ou a ilha foi clicada (`open`).
  static func report(module: String, action: String) {
    guard let channel = overlayChannel else {
      NSLog("[Notch] ação sem canal para avisar o Dart.")
      return
    }

    channel.invokeMethod("onAction", arguments: ["module": module, "action": action])
  }

  /// O módulo que a ilha está mostrando agora, ou `nil` sem ilha na tela — ou
  /// com mais de um monitor, em que a ilha não está à vista de toda barra de
  /// menus (ver o fim do `refresh`).
  ///
  /// Quem precisa saber é a barra de menus: o relógio que já está no notch não
  /// se repete ao lado do ícone. E só daqui dá para saber — quem decide são os
  /// módulos ligados no notch, que o Hub muda de outro engine, e o recorte, que
  /// some com a tampa fechada.
  private static var shownModule: String?

  /// Avisa o Dart quando a ilha passa a mostrar outro módulo, ou nenhum. Só na
  /// virada: o `update` chega dez vezes por segundo gravando.
  private static func setShown(_ module: String?) {
    guard module != shownModule else { return }
    shownModule = module
    let value: Any = module ?? NSNull()
    overlayChannel?.invokeMethod("onShown", arguments: ["module": value])
  }

  private static func refresh() {
    let visible = activities.first { enabledModules.contains($0.module) }

    guard let activity = visible, let notch = NotchGeometry.current() else {
      island?.dismiss()
      island = nil
      setShown(nil)
      return
    }

    let controller = island ?? NotchIslandController(notch: notch, palette: palette)
    if island == nil, isPassThrough { controller.setPassThrough(true) }
    island = controller
    controller.show(activity)
    // Com outro monitor ligado a ilha fica na tela do notch, mas a barra de
    // menus está em todas — e a pessoa pode estar trabalhando na outra. Ali o
    // relógio da barra é o único, e não pode sumir por causa de uma ilha que
    // ela não está vendo.
    setShown(NSScreen.screens.count == 1 ? activity.module : nil)
  }
}

// MARK: - O que o Dart manda

/// As cores da ilha, tiradas dos tokens do lado Dart.
///
/// Os valores de reserva existem só para o instante antes do `configure`
/// chegar; quem manda é a paleta.
struct NotchPalette {
  var notch = NSColor.black
  var textPrimary = NSColor.white
  var textSecondary = NSColor.lightGray
  var textTertiary = NSColor.gray
  var accent = NSColor.systemGreen
  var tide = NSColor.systemBlue
  var error = NSColor.systemRed
  var control = NSColor.darkGray

  init() {}

  init(_ map: [String: Any]) {
    func color(_ key: String, _ fallback: NSColor) -> NSColor {
      guard let value = map[key] as? Int else { return fallback }
      let argb = UInt32(truncatingIfNeeded: value)

      return NSColor(
        srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
        green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255,
        alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    }

    notch = color("notch", notch)
    textPrimary = color("textPrimary", textPrimary)
    textSecondary = color("textSecondary", textSecondary)
    textTertiary = color("textTertiary", textTertiary)
    accent = color("accent", accent)
    tide = color("tide", tide)
    error = color("error", error)
    control = color("control", control)
  }
}

/// Uma coisa rodando, do jeito que a ilha a desenha. Ver `NotchActivity` no
/// lado Dart, que é quem a escreve.
struct NotchActivity: Equatable {
  struct Action: Equatable {
    let id: String
    let label: String
  }

  enum Indicator: Equatable {
    /// O ponto de gravação, cheio ou vazado.
    case recording(paused: Bool)

    /// Quanto da fase já passou, de 0 a 1.
    case progress(Double, paused: Bool, rest: Bool)

    /// A prateleira do Nest com arquivos esperando.
    case shelf
  }

  let module: String
  let indicator: Indicator
  let title: String
  let detail: String
  let clock: String

  /// O que está entrando agora, quando é o Echo: as duas faixas, cada uma com
  /// as suas bandas. Vazio para quem não grava.
  let mic: [Double]
  let system: [Double]

  let actions: [Action]

  /// O texto ao vivo da reunião, do trecho mais antigo ao mais novo — ou
  /// `nil` quando a gravação não transcreve ao vivo, e aí a ilha não oferece
  /// o modo fixado.
  let transcript: [String]?

  /// Os rótulos do modo fixado: o botão que abre, o que recolhe e o texto de
  /// antes da primeira frase. Do Dart, como todo texto da ilha.
  let transcriptLabels: [String: String]

  /// O mouse em cima não abre a ilha: pede ao Dart o painel do módulo. É o
  /// Nest, cuja pilha aberta é desenhada pela janela 0 — a única que recebe
  /// arraste do Finder.
  let opensOnHover: Bool

  init?(_ map: [String: Any]) {
    guard let module = map["module"] as? String,
          let indicator = map["indicator"] as? String
    else { return nil }

    let paused = map["paused"] as? Bool ?? false

    switch indicator {
    case "recording":
      self.indicator = .recording(paused: paused)
    case "progress":
      self.indicator = .progress(
        map["progress"] as? Double ?? 0,
        paused: paused,
        rest: map["rest"] as? Bool ?? false)
    case "shelf":
      self.indicator = .shelf
    default:
      return nil
    }

    self.module = module
    title = map["title"] as? String ?? ""
    detail = map["detail"] as? String ?? ""
    clock = map["clock"] as? String ?? ""
    mic = (map["mic"] as? [Double]) ?? []
    system = (map["system"] as? [Double]) ?? []
    transcript = map["transcript"] as? [String]
    transcriptLabels = map["transcriptLabels"] as? [String: String] ?? [:]
    opensOnHover = map["opensOnHover"] as? Bool ?? false
    actions = ((map["actions"] as? [[String: Any]]) ?? []).compactMap { action in
      guard let id = action["id"] as? String, let label = action["label"] as? String
      else { return nil }
      return Action(id: id, label: label)
    }
  }
}

// MARK: - A janela

/// A janela da ilha. Não ativa ninguém, não vira key, não se move.
///
/// Nunca vira key de propósito: a ilha é de mouse, e uma janela que tomasse o
/// teclado no meio de uma reunião roubaria a digitação de quem está no chat
/// dela.
final class NotchIslandPanel: NSPanel {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true)

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    isMovable = false
    isFloatingPanel = true
    hidesOnDeactivate = false
    becomesKeyOnlyIfNeeded = true

    // Acima da barra de menus — que é onde o recorte está —, e acima da
    // janela 0 (`.statusBar`), para a prateleira que sai do notch nunca
    // desenhar por cima da ilha.
    level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)

    // Em todo Space, inclusive em app de tela cheia — é lá que a reunião
    // costuma estar —, sem aparecer no ciclo de janelas do ⌘`.
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  /// Deixa a janela subir até a barra de menus. O padrão do AppKit é prender
  /// o quadro abaixo dela — e o recorte está justamente lá em cima. É o mesmo
  /// motivo do `MainFlutterWindow.constrainFrameRect`, e o mais provável dos
  /// motivos de a janela do recorte de antes nunca ter aparecido.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }
}

/// Liga a janela ao que ela mostra, e decide quando ela cresce.
///
/// **A janela tem o tamanho do que está desenhado.** Recolhida, ela é a
/// pílula; aberta, é o painel. Uma janela do tamanho do painel o tempo todo,
/// transparente em volta da pílula, engoliria os cliques do topo de qualquer
/// app que estivesse embaixo — as abas do navegador, a barra de ferramentas.
/// Por isso a janela cresce *antes* de a pílula crescer, e encolhe *depois* de
/// ela voltar.
final class NotchIslandController {
  private let notch: NotchGeometry
  private let panel = NotchIslandPanel()
  private let view: NotchIslandView

  /// Os três tamanhos da ilha.
  enum Mode {
    /// A pílula em volta do recorte.
    case collapsed

    /// Aberta pelo mouse em cima; fecha quando ele sai.
    case expanded

    /// Aberta com a transcrição ao vivo, e presa: o mouse sair não fecha.
    /// Só quem fecha é o botão "Recolher" — ou a gravação acabar.
    case pinned
  }

  private(set) var mode = Mode.collapsed

  private var expandWork: DispatchWorkItem?
  private var collapseWork: DispatchWorkItem?

  /// Quanto o cursor espera em cima da ilha para ela abrir. Passar por ela a
  /// caminho de um ícone da barra de menus não pode abrir nada.
  private static let hoverIntent: TimeInterval = 0.15

  /// E quanto espera fora dela para fechar: sair por um pixel e voltar não
  /// pode fechar e reabrir.
  private static let leaveGrace: TimeInterval = 0.25

  init(notch: NotchGeometry, palette: NotchPalette) {
    self.notch = notch
    view = NotchIslandView(notchWidth: notch.rect.width, notchHeight: notch.rect.height)
    view.palette = palette
    panel.contentView = view

    view.onHover = { [weak self] inside in self?.hoverChanged(inside) }
    view.onAction = { module, action in
      NotchIslandChannel.report(module: module, action: action)
    }
    view.onToggleTranscript = { [weak self] in self?.toggleTranscript() }

    panel.setFrame(collapsedFrame, display: false)
    view.layoutCollapsed()
  }

  func apply(_ palette: NotchPalette) {
    view.palette = palette
  }

  func show(_ activity: NotchActivity) {
    view.activity = activity

    // A transcrição foi embora — a gravação parou de transcrever, ou quem
    // aparece agora é o Focus: a ilha presa não tem mais o que mostrar.
    if mode == .pinned, activity.transcript == nil { unpin() }

    guard !panel.isVisible else { return }

    panel.setFrame(collapsedFrame, display: true)
    view.layoutCollapsed()
    panel.orderFrontRegardless()
  }

  func dismiss() {
    expandWork?.cancel()
    collapseWork?.cancel()
    panel.orderOut(nil)
    // Os relógios de tela retêm as views que os pediram: sem soltá-los aqui,
    // cada reunião deixaria uma ilha inteira pendurada no run loop.
    view.invalidate()
  }

  // MARK: Geometria

  /// Quanto a pílula recolhida passa do recorte, de cada lado.
  ///
  /// Estreita de propósito: recolhida, ela cobre os ícones da barra de menus
  /// que caírem embaixo enquanto algo grava. Cabe o ponto e as barras de um
  /// lado e o relógio do outro, e mais nada.
  static let wing: CGFloat = 60

  /// A altura que a ilha ganha abaixo da barra de menus quando abre.
  static let expandedDepth: CGFloat = 78

  static let expandedWidth: CGFloat = 380

  /// Presa com a transcrição, ela alarga para a linha caber uma frase, e
  /// desce o bastante para três linhas — o que se lê de relance sem virar uma
  /// janela de leitura no topo da tela.
  static let pinnedWidth: CGFloat = 520
  static let transcriptDepth: CGFloat = 70

  private var collapsedFrame: NSRect {
    let width = notch.rect.width + Self.wing * 2 + NotchIslandView.shoulder * 2

    return NSRect(
      x: notch.rect.midX - width / 2,
      y: notch.screen.frame.maxY - notch.rect.height,
      width: width,
      height: notch.rect.height)
  }

  private var expandedFrame: NSRect {
    topCentered(
      width: max(collapsedFrame.width, Self.expandedWidth + NotchIslandView.shoulder * 2),
      height: notch.rect.height + Self.expandedDepth)
  }

  private var pinnedFrame: NSRect {
    topCentered(
      width: max(collapsedFrame.width, Self.pinnedWidth + NotchIslandView.shoulder * 2),
      height: notch.rect.height + Self.expandedDepth + Self.transcriptDepth)
  }

  private func topCentered(width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(
      x: notch.rect.midX - width / 2,
      y: notch.screen.frame.maxY - height,
      width: width,
      height: height)
  }

  private func frame(for mode: Mode) -> NSRect {
    switch mode {
    case .collapsed: return collapsedFrame
    case .expanded: return expandedFrame
    case .pinned: return pinnedFrame
    }
  }

  // MARK: Hover

  /// O cursor está sobre a ilha?
  ///
  /// `NSMouseInRect`, e não `contains`: a ilha encosta no topo da tela, e o
  /// cursor parado lá em cima tem `y == maxY` — que o `contains` deixa de fora.
  /// Com ele, a ilha não abria com o mouse colado no topo, e a aberta fechava
  /// com o cursor em cima dela.
  private static func isCursor(in frame: NSRect) -> Bool {
    NSMouseInRect(NSEvent.mouseLocation, frame, false)
  }

  /// A ilha não recebe o mouse — durante o arraste que chamou a prateleira
  /// pelo notch. Ver `NestDragMonitor`.
  private var isPassThrough = false

  /// A transcrição estava presa quando o arraste começou: ela volta quando
  /// ele acaba. Foi a pessoa que prendeu, e um arquivo levado à prateleira
  /// não é um "Recolher".
  private var wasPinned = false

  func setPassThrough(_ passThrough: Bool) {
    // Os dois motivos (o arraste e a pilha aberta) chegam por caminhos
    // separados; repetir o mesmo valor não pode apagar a lembrança de que a
    // transcrição estava presa.
    guard passThrough != isPassThrough else { return }

    isPassThrough = passThrough
    panel.ignoresMouseEvents = passThrough

    guard passThrough else {
      if wasPinned, view.activity?.transcript != nil { go(to: .pinned) }
      wasPinned = false
      return
    }

    wasPinned = mode == .pinned
    expandWork?.cancel()
    // Presa ou não: a prateleira sai logo embaixo do recorte, e a ilha aberta
    // cobriria o topo dela.
    if mode != .collapsed { go(to: .collapsed) }
  }

  private func hoverChanged(_ inside: Bool) {
    // Presa, o mouse não decide nada: é o ponto do modo.
    guard mode != .pinned else { return }

    if inside {
      collapseWork?.cancel()
      guard mode == .collapsed else { return }

      let work = DispatchWorkItem { [weak self] in self?.expand() }
      expandWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverIntent, execute: work)
    } else {
      expandWork?.cancel()
      guard mode == .expanded else { return }
      scheduleCollapse()
    }
  }

  private func scheduleCollapse() {
    collapseWork?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.collapseIfOutside() }
    collapseWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.leaveGrace, execute: work)
  }

  private func expand() {
    // Confere de novo: o `mouseExited` de uma janela que acabou de mudar de
    // tamanho não é confiável, e a posição do cursor é.
    guard mode == .collapsed, !isPassThrough, Self.isCursor(in: panel.frame) else { return }

    if let activity = view.activity, activity.opensOnHover {
      NotchIslandChannel.report(module: activity.module, action: "open")
      return
    }

    go(to: .expanded)
  }

  private func collapseIfOutside() {
    guard mode == .expanded, !Self.isCursor(in: panel.frame) else { return }
    go(to: .collapsed)
  }

  private func toggleTranscript() {
    if mode == .pinned {
      unpin()
    } else if view.activity?.transcript != nil {
      collapseWork?.cancel()
      go(to: .pinned)
    }
  }

  /// Solta a ilha presa. Ela volta a ser a aberta pelo mouse — e, se o mouse
  /// já não estiver em cima, fecha como fecharia.
  private func unpin() {
    go(to: .expanded)
    scheduleCollapse()
  }

  /// Leva a ilha de um tamanho a outro.
  ///
  /// **A janela tem o tamanho do que está desenhado**, então ela cresce
  /// *antes* de a pílula crescer e encolhe *depois* de a pílula voltar — a
  /// pílula se anima dentro de uma janela que já cabe as duas medidas.
  private func go(to target: Mode) {
    guard target != mode else { return }

    let from = panel.frame
    let to = frame(for: target)
    let grows = to.height > from.height
    mode = target

    if grows { panel.setFrame(to, display: false) }
    let container = grows ? to : from

    func local(_ rect: NSRect) -> NSRect {
      NSRect(
        x: rect.minX - container.minX,
        y: rect.minY - container.minY,
        width: rect.width,
        height: rect.height)
    }

    view.transition(to: target, from: local(from), to: local(to)) { [weak self] in
      guard let self = self, !grows, self.mode == target else { return }
      self.panel.setFrame(to, display: true)
      self.view.settle(in: target)

      // A janela acabou de encolher por baixo do cursor, e o AppKit não manda
      // `mouseExited` por isso — quem soltou a ilha presa pelo "Recolher", na
      // linha de baixo, ficaria com ela aberta até mexer o mouse para dentro e
      // para fora de novo.
      if target == .expanded { self.collapseIfOutside() }
    }
  }
}

// MARK: - O desenho

/// O conteúdo da ilha: a pílula preta, as duas asas de quando ela está
/// recolhida e o painel de quando ela abre.
final class NotchIslandView: NSView {
  var palette = NotchPalette() {
    didSet { applyPalette() }
  }

  var activity: NotchActivity? {
    didSet {
      guard activity != oldValue else { return }
      render(previous: oldValue)
    }
  }

  var onHover: ((Bool) -> Void)?
  var onAction: ((String, String) -> Void)?
  var onToggleTranscript: (() -> Void)?

  private var mode = NotchIslandController.Mode.collapsed

  private let notchWidth: CGFloat
  private let notchHeight: CGFloat

  private let pill = NSView()

  /// Os dois cantos côncavos do topo, por fora da pílula.
  ///
  /// São o que faz a ilha ler como o recorte se alongando, e não como uma
  /// peça pousada embaixo dele: o hardware também não termina em quina — a
  /// borda da tela entra no recorte por uma curva. Sem eles a pílula tem um
  /// degrau de 90° colado na barra de menus.
  private let leftShoulder = NotchShoulderView(side: .left)
  private let rightShoulder = NotchShoulderView(side: .right)

  /// O raio dos ombros, e quanto a janela é mais larga que a pílula de cada
  /// lado para cabê-los.
  static let shoulder: CGFloat = 6

  // Recolhida: o indicador numa asa, o relógio na outra.
  private let wingIndicator = NotchIndicatorView(style: .compact)
  private let wingClock = NSTextField(labelWithString: "")

  // Aberta.
  private let expandedContent = NSView()
  private let titleIndicator = NotchIndicatorView(style: .compact)
  private let titleLabel = NSTextField(labelWithString: "")
  private let detailLabel = NSTextField(labelWithString: "")
  private let clockLabel = NSTextField(labelWithString: "")
  private let meter = NotchIndicatorView(style: .wide)
  private let transcriptView = NotchTranscriptView()
  private var buttons: [NotchIslandButton] = []

  private static let padding: CGFloat = 14
  private static let buttonHeight: CGFloat = 24

  init(notchWidth: CGFloat, notchHeight: CGFloat) {
    self.notchWidth = notchWidth
    self.notchHeight = notchHeight
    super.init(frame: .zero)

    wantsLayer = true

    pill.wantsLayer = true
    pill.layer?.cornerCurve = .continuous
    // Só os cantos de baixo: os de cima encostam na borda da tela, e é isso
    // que faz a pílula ler como o recorte crescendo, e não como uma janela
    // pousada em cima dele.
    pill.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    addSubview(pill)
    addSubview(leftShoulder)
    addSubview(rightShoulder)

    for label in [wingClock, titleLabel, detailLabel, clockLabel] {
      label.lineBreakMode = .byTruncatingTail
      label.maximumNumberOfLines = 1
      label.drawsBackground = false
      label.isBezeled = false
      label.isEditable = false
      label.isSelectable = false
    }

    // Os algarismos de largura fixa: o relógio muda a cada segundo, e com a
    // largura proporcional o texto dança junto.
    wingClock.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    wingClock.alignment = .right
    clockLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    clockLabel.alignment = .right
    titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    detailLabel.font = .systemFont(ofSize: 12, weight: .regular)

    addSubview(wingIndicator)
    addSubview(wingClock)

    expandedContent.alphaValue = 0
    expandedContent.isHidden = true
    for subview in [titleIndicator, titleLabel, detailLabel, clockLabel, meter, transcriptView] {
      expandedContent.addSubview(subview)
    }
    transcriptView.alphaValue = 0
    addSubview(expandedContent)

    applyPalette()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) não é usado")
  }

  // MARK: Hover e clique

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in trackingAreas { removeTrackingArea(area) }

    // `.activeAlways`: o Evergreen nunca é o app da frente, e uma área que só
    // valesse com o app ativo não veria cursor nenhum.
    addTrackingArea(
      NSTrackingArea(
        rect: .zero,
        options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
        owner: self,
        userInfo: nil))
  }

  /// Só os botões respondem por si; o resto da ilha — título, relógio,
  /// indicador — é a ilha. Um `NSTextField` é um controle e engoliria o
  /// clique que deveria abrir o painel do módulo.
  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let hit = super.hitTest(point) else { return nil }

    var view: NSView? = hit
    while let current = view, current !== self {
      if current is NotchIslandButton { return current }
      view = current.superview
    }

    return self
  }

  func invalidate() {
    for indicator in [wingIndicator, titleIndicator, meter] {
      indicator.invalidate()
    }
  }

  override func mouseEntered(with event: NSEvent) { onHover?(true) }
  override func mouseExited(with event: NSEvent) { onHover?(false) }

  /// O primeiro clique vale: a janela nunca é key, e sem isto o clique só a
  /// ativaria e seria engolido.
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  /// Clicar na ilha fora dos botões abre o painel do módulo.
  override func mouseUp(with event: NSEvent) {
    guard let module = activity?.module else { return }
    onAction?(module, "open")
  }

  // MARK: Layout

  /// A pílula do tamanho da janela, com as asas à vista.
  func layoutCollapsed() {
    let rect = pillRect(in: bounds)
    pill.frame = rect
    pill.layer?.cornerRadius = 10
    placeShoulders(around: rect)
    layoutWings(in: rect)
    wingIndicator.alphaValue = 1
    wingClock.alphaValue = 1
    expandedContent.alphaValue = 0
    expandedContent.isHidden = true
  }

  /// A pílula dentro de um quadro de janela: o quadro menos os ombros.
  private func pillRect(in rect: NSRect) -> NSRect {
    rect.insetBy(dx: Self.shoulder, dy: 0)
  }

  private func placeShoulders(around pill: NSRect, animated: Bool = false) {
    let size = Self.shoulder
    let left = NSRect(x: pill.minX - size, y: pill.maxY - size, width: size, height: size)
    let right = NSRect(x: pill.maxX, y: pill.maxY - size, width: size, height: size)

    if animated {
      leftShoulder.animator().frame = left
      rightShoulder.animator().frame = right
    } else {
      leftShoulder.frame = left
      rightShoulder.frame = right
    }
  }

  /// O respiro da asa até a ponta da pílula. Menor que o do painel aberto: a
  /// asa é estreita, e o que ela carrega precisa caber inteiro.
  private static let wingInset: CGFloat = 12

  private func layoutWings(in rect: NSRect) {
    let wing = NotchIslandController.wing
    let midY = rect.midY

    // O respiro fica do lado de fora, onde a pílula termina; do lado de
    // dentro sobra a folga até o recorte, que nenhum pixel alcança.
    wingIndicator.frame = NSRect(
      x: rect.minX + Self.wingInset,
      y: midY - 7,
      width: wing - Self.wingInset - 8,
      height: 14)

    // O relógio pela medida dele, encostado no respiro: `12:34` e `1:02:03`
    // terminam no mesmo ponto, e nenhum dos dois é cortado.
    wingClock.sizeToFit()
    let clockWidth = min(wingClock.frame.width, wing - Self.wingInset)
    let clockHeight = wingClock.frame.height
    wingClock.frame = NSRect(
      x: rect.maxX - Self.wingInset - clockWidth,
      y: midY - clockHeight / 2,
      width: clockWidth,
      height: clockHeight)
  }

  /// Arruma o conteúdo da ilha aberta dentro de [rect] — a pílula de
  /// destino, nas coordenadas da janela.
  ///
  /// A primeira linha conta a partir do topo e a dos botões a partir de baixo,
  /// então a mesma conta serve aberta e presa: a transcrição ocupa o que
  /// sobra entre as duas.
  private func layoutContent(in rect: NSRect) {
    expandedContent.frame = rect

    let content = expandedContent.bounds
    let left = Self.padding
    let right = content.width - Self.padding
    // Coordenadas do AppKit: o zero é embaixo. A primeira linha fica logo
    // abaixo da barra de menus, a dos botões encosta no respiro de baixo.
    let rowOneMidY = content.height - notchHeight - 18
    let rowTwoY = Self.padding

    titleIndicator.frame = NSRect(x: left, y: rowOneMidY - 6, width: 12, height: 12)

    clockLabel.sizeToFit()
    let clockWidth = max(clockLabel.frame.width, 44)
    clockLabel.frame = NSRect(
      x: right - clockWidth, y: rowOneMidY - 9, width: clockWidth, height: 18)

    titleLabel.sizeToFit()
    let titleX = left + 18
    let titleWidth = min(titleLabel.frame.width, clockLabel.frame.minX - titleX - 12)
    titleLabel.frame = NSRect(x: titleX, y: rowOneMidY - 9, width: titleWidth, height: 18)

    let detailX = titleLabel.frame.maxX + 8
    detailLabel.frame = NSRect(
      x: detailX,
      y: rowOneMidY - 8,
      width: max(0, clockLabel.frame.minX - detailX - 12),
      height: 16)

    var x = right
    for button in buttons.reversed() {
      button.sizeToFit()
      let width = button.frame.width + 20
      x -= width
      button.frame = NSRect(x: x, y: rowTwoY, width: width, height: Self.buttonHeight)
      x -= 8
    }

    meter.frame = NSRect(
      x: left,
      y: rowTwoY + 3,
      width: max(0, x - left - 8),
      height: Self.buttonHeight - 6)

    let transcriptBottom = rowTwoY + Self.buttonHeight + 12
    transcriptView.frame = NSRect(
      x: left,
      y: transcriptBottom,
      width: right - left,
      height: max(0, rowOneMidY - 9 - 10 - transcriptBottom))
  }

  // MARK: Animação

  /// Qual animação é a mais recente. A que termina depois de outra ter
  /// começado não decide mais nada — sem isto, voltar com o cursor no meio do
  /// recolhimento deixava a ilha aberta e vazia: o fim do recolhimento
  /// escondia o conteúdo que a reabertura tinha acabado de mostrar.
  private var generation = 0

  /// Leva a pílula de um tamanho a outro.
  ///
  /// [from] e [to] são os quadros de janela de cada tamanho, nas coordenadas
  /// da janela de agora — que já é a maior das duas.
  ///
  /// 220 ms em `easeOutCubic`: é uma transição de painel (`motion.md`), e a
  /// mesma curva de tudo o que entra no Evergreen. Com "reduzir movimento"
  /// ligado nos Ajustes, troca sem animar.
  func transition(
    to target: NotchIslandController.Mode,
    from: NSRect,
    to: NSRect,
    completion: (() -> Void)?
  ) {
    generation += 1
    let current = generation
    let wasCollapsed = mode == .collapsed
    mode = target

    let fromPill = pillRect(in: from)
    let toPill = pillRect(in: to)
    let opens = target != .collapsed

    // O ponto de partida, sem animar: a janela pode ter acabado de crescer, e
    // a pílula precisa começar de onde estava na tela.
    pill.frame = fromPill
    placeShoulders(around: fromPill)

    if let activity = activity { updateToggle(activity) }

    if wasCollapsed && opens {
      layoutWings(in: fromPill)
      expandedContent.isHidden = false
      layoutContent(in: toPill)
    } else if opens {
      // Entre aberta e presa, o conteúdo parte de onde estava na tela: a
      // janela pode ter acabado de crescer, e o quadro antigo, em coordenadas
      // da janela nova, faria o título subir de baixo.
      layoutContent(in: fromPill)
    }
    if !opens { layoutWings(in: toPill) }
    if target == .pinned { transcriptView.isHidden = false }

    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    NSAnimationContext.runAnimationGroup({ context in
      context.duration = reduceMotion ? 0 : 0.22
      context.timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
      context.allowsImplicitAnimation = true

      pill.animator().frame = toPill
      placeShoulders(around: toPill, animated: true)
      pill.layer?.cornerRadius = opens ? 18 : 10
      wingIndicator.animator().alphaValue = opens ? 0 : 1
      wingClock.animator().alphaValue = opens ? 0 : 1
      expandedContent.animator().alphaValue = opens ? 1 : 0
      transcriptView.animator().alphaValue = target == .pinned ? 1 : 0

      // Entre aberta e presa o conteúdo acompanha a pílula, em vez de pular
      // para o lugar novo antes de ela chegar lá.
      if !wasCollapsed && opens { layoutContent(in: toPill) }
    }, completionHandler: { [weak self] in
      guard let self = self, self.generation == current else { return }
      if !opens { self.expandedContent.isHidden = true }
      if target != .pinned { self.transcriptView.isHidden = true }
      completion?()
    })
  }

  /// Acerta tudo ao tamanho da janela, depois de ela encolher.
  func settle(in target: NotchIslandController.Mode) {
    if target == .collapsed {
      layoutCollapsed()
      return
    }

    let rect = pillRect(in: bounds)
    pill.frame = rect
    placeShoulders(around: rect)
    layoutContent(in: rect)
  }

  // MARK: Conteúdo

  private func applyPalette() {
    pill.layer?.backgroundColor = palette.notch.cgColor
    leftShoulder.color = palette.notch
    rightShoulder.color = palette.notch
    wingClock.textColor = palette.textPrimary
    titleLabel.textColor = palette.textPrimary
    detailLabel.textColor = palette.textTertiary
    clockLabel.textColor = palette.textSecondary
    for indicator in [wingIndicator, titleIndicator, meter] {
      indicator.palette = palette
    }
    for button in buttons { button.apply(palette) }
  }

  private func render(previous: NotchActivity?) {
    guard let activity = activity else { return }

    wingClock.stringValue = activity.clock
    clockLabel.stringValue = activity.clock
    titleLabel.stringValue = activity.title
    detailLabel.stringValue = activity.detail

    wingIndicator.activity = activity
    titleIndicator.activity = activity
    meter.activity = activity

    // Os botões só são refeitos quando mudam de verdade — pausar troca
    // "Pausar" por "Retomar" —, e não a cada décimo de segundo do equalizador.
    if previous?.actions != activity.actions || previous?.module != activity.module {
      rebuildButtons(activity)
    }

    transcriptView.palette = palette
    transcriptView.segments = activity.transcript ?? []
    transcriptView.placeholder = activity.transcriptLabels["empty"] ?? ""

    if previous?.transcript == nil, activity.transcript != nil {
      rebuildButtons(activity)
    } else if previous?.transcript != nil, activity.transcript == nil {
      rebuildButtons(activity)
    }

    if expandedContent.isHidden {
      layoutWings(in: pill.frame)
    } else {
      layoutContent(in: expandedContent.frame)
    }

    setAccessibilityElement(true)
    setAccessibilityRole(.group)
    setAccessibilityLabel("\(activity.title), \(activity.clock)")
  }

  private func rebuildButtons(_ activity: NotchActivity) {
    for button in buttons { button.removeFromSuperview() }

    var made: [NotchIslandButton] = []

    // O da transcrição primeiro, e só quando a gravação transcreve ao vivo:
    // ele muda o tamanho da ilha, e os da direita mudam a reunião.
    if activity.transcript != nil {
      made.append(
        NotchIslandButton(label: toggleLabel(activity), palette: palette) { [weak self] in
          self?.onToggleTranscript?()
        })
    }

    made += activity.actions.map { action in
      NotchIslandButton(label: action.label, palette: palette) { [weak self] in
        self?.onAction?(activity.module, action.id)
      }
    }

    for button in made { expandedContent.addSubview(button) }
    buttons = made
  }

  private func toggleLabel(_ activity: NotchActivity) -> String {
    activity.transcriptLabels[mode == .pinned ? "hide" : "show"] ?? ""
  }

  /// Troca "Transcrição" por "Recolher" e vice-versa, sem refazer os outros.
  private func updateToggle(_ activity: NotchActivity) {
    guard activity.transcript != nil, let toggle = buttons.first else { return }
    toggle.setLabel(toggleLabel(activity))
  }
}

/// A transcrição ao vivo, presa embaixo do recorte.
///
/// O trecho mais novo embaixo, em texto principal; os de antes sobem e se
/// apagam, e o topo se dissolve em vez de cortar a letra ao meio. Os trechos
/// chegam do lado nativo já fechados (`isFinal`), então nada aqui se reescreve
/// enquanto se lê — uma frase que aparece fica como apareceu.
final class NotchTranscriptView: NSView {
  var segments: [String] = [] {
    didSet { if segments != oldValue { needsDisplay = true } }
  }

  var placeholder = "" {
    didSet { if placeholder != oldValue { needsDisplay = true } }
  }

  var palette = NotchPalette() {
    didSet { needsDisplay = true }
  }

  private let fade = CAGradientLayer()

  /// Quanto do topo se dissolve.
  private static let fadeHeight: CGFloat = 16

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor]
    // A máscara herda a virada da view: o 0 é o topo, e é o topo que se
    // dissolve. Conferido desenhando a ilha — forçar `isGeometryFlipped` aqui
    // vira a conta duas vezes e apaga a frase mais nova, embaixo.
    fade.startPoint = CGPoint(x: 0.5, y: 0)
    fade.endPoint = CGPoint(x: 0.5, y: 1)
    layer?.mask = fade
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) não é usado")
  }

  /// Virada: o texto é posto a partir do topo, e é mais fácil encostar a
  /// última linha embaixo contando de cima.
  override var isFlipped: Bool { true }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()

    // Sem a animação implícita de camada: a máscara não é de view nenhuma, e
    // mudar o quadro dela animaria 0,25 s a partir da altura 0 — o texto
    // nasceria escondido justamente ao prender.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    fade.frame = bounds
    let solid = bounds.height > 0 ? min(1, Self.fadeHeight / bounds.height) : 0
    fade.locations = [0, NSNumber(value: Double(solid))]
    CATransaction.commit()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    needsLayout = true
  }

  override func draw(_ dirtyRect: NSRect) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 2

    let font = NSFont.systemFont(ofSize: 13, weight: .regular)
    let text = NSMutableAttributedString()

    if segments.isEmpty {
      text.append(
        NSAttributedString(
          string: placeholder,
          attributes: [.font: font, .foregroundColor: palette.textTertiary]))
    }

    for (index, segment) in segments.enumerated() {
      // O trecho que acabou de chegar é o que se lê; os outros são contexto.
      let age = segments.count - 1 - index
      let color: NSColor
      switch age {
      case 0: color = palette.textPrimary
      case 1: color = palette.textSecondary
      default: color = palette.textTertiary
      }

      if index > 0 { text.append(NSAttributedString(string: " ")) }
      text.append(NSAttributedString(string: segment, attributes: [.font: font, .foregroundColor: color]))
    }

    text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))

    let width = bounds.width
    let height = ceil(
      text.boundingRect(
        with: NSSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
      ).height)

    // Encostado embaixo: o que passa da altura sai por cima, onde o degradê
    // já está apagando.
    text.draw(
      with: NSRect(x: 0, y: bounds.height - height, width: width, height: height),
      options: [.usesLineFragmentOrigin, .usesFontLeading])
  }
}

/// Um canto côncavo: o quadrado menos o quarto de círculo voltado para fora.
final class NotchShoulderView: NSView {
  enum Side { case left, right }

  let side: Side

  var color = NSColor.black {
    didSet { needsDisplay = true }
  }

  init(side: Side) {
    self.side = side
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) não é usado")
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    let r = bounds.width
    let path = NSBezierPath()

    // O círculo tem o centro no canto de baixo do lado de fora: o que sobra do
    // quadrado é a curva que sai da borda da tela e desce pela lateral da
    // pílula.
    switch side {
    case .left:
      path.move(to: NSPoint(x: 0, y: r))
      path.line(to: NSPoint(x: r, y: r))
      path.line(to: NSPoint(x: r, y: 0))
      path.appendArc(
        withCenter: NSPoint(x: 0, y: 0), radius: r, startAngle: 0, endAngle: 90, clockwise: false)
    case .right:
      path.move(to: NSPoint(x: r, y: r))
      path.line(to: NSPoint(x: 0, y: r))
      path.line(to: NSPoint(x: 0, y: 0))
      path.appendArc(
        withCenter: NSPoint(x: r, y: 0), radius: r, startAngle: 180, endAngle: 90, clockwise: true)
    }

    path.close()
    color.setFill()
    path.fill()
  }
}

/// Um botão de texto da ilha.
final class NotchIslandButton: NSButton {
  private let handler: () -> Void
  private var label: String

  init(label: String, palette: NotchPalette, handler: @escaping () -> Void) {
    self.handler = handler
    self.label = label
    self.palette = palette
    super.init(frame: .zero)

    isBordered = false
    wantsLayer = true
    layer?.cornerRadius = 6
    target = self
    action = #selector(press)
    setAccessibilityLabel(label)
    apply(palette)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) não é usado")
  }

  /// O primeiro clique vale — a ilha nunca é a janela key.
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  func setLabel(_ label: String) {
    self.label = label
    setAccessibilityLabel(label)
    apply(palette)
  }

  private var palette: NotchPalette

  func apply(_ palette: NotchPalette) {
    self.palette = palette
    layer?.backgroundColor = palette.control.cgColor
    attributedTitle = NSAttributedString(
      string: label,
      attributes: [
        .foregroundColor: palette.textPrimary,
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
      ])
  }

  @objc private func press() { handler() }
}

/// O sinal de vida de cada módulo: o ponto e o equalizador do Echo, o anel e a
/// barra de progresso do Focus.
///
/// Medida, nunca animação: as barras do Echo são as bandas que o lado nativo
/// mediu, e o anel do Focus é o tempo que passou. Nada aqui se mexe sozinho.
final class NotchIndicatorView: NSView {
  enum Style {
    /// O que cabe numa asa ou ao lado do título.
    case compact

    /// A linha de baixo do painel aberto: o equalizador inteiro, ou a barra de
    /// progresso.
    case wide
  }

  let style: Style

  var palette = NotchPalette() {
    didSet { needsDisplay = true }
  }

  var activity: NotchActivity? {
    didSet {
      retarget()
      needsDisplay = true
    }
  }

  // O equalizador interpolado.
  //
  // A medida chega dez vezes por segundo, e uma barra que pula de altura a
  // cada 100 ms parece um defeito numa tela de 120 Hz. Entre uma medida e a
  // seguinte as barras andam do que mostravam até o novo valor, em exatamente
  // um intervalo — mais curto, elas parariam esperando; mais longo, ficariam
  // atrás do som. É o mesmo contrato do `EchoSpectrum.interval` no Dart.
  private var shownMic: [Double] = []
  private var shownSystem: [Double] = []
  private var fromMic: [Double] = []
  private var fromSystem: [Double] = []
  private var targetMic: [Double] = []
  private var targetSystem: [Double] = []
  private var tweenStart: CFTimeInterval = 0
  private static let tween: CFTimeInterval = 0.1

  /// O relógio da tela, e não um `Timer`: ele bate no ritmo do monitor (120 Hz
  /// num ProMotion), e fica parado sempre que não há barra a mover.
  ///
  /// Guardado num opcional, e não preguiçoso: o link retém a view e o run loop
  /// retém o link, e só um link que se pode soltar ([invalidate]) deixa a
  /// ilha morrer quando a reunião acaba.
  private var link: CADisplayLink?

  private func startLink() {
    if link == nil {
      let created = displayLink(target: self, selector: #selector(step))
      created.add(to: .main, forMode: .common)
      link = created
    }
    link?.isPaused = false
  }

  func invalidate() {
    link?.invalidate()
    link = nil
  }

  private func retarget() {
    guard case .recording = activity?.indicator else { return }

    let mic = activity?.mic ?? []
    let system = activity?.system ?? []
    guard mic != targetMic || system != targetSystem else { return }

    fromMic = shownMic
    fromSystem = shownSystem
    targetMic = mic
    targetSystem = system
    tweenStart = CACurrentMediaTime()

    // Fora da tela não há relógio de tela que bata, e as barras ficariam
    // paradas no zero esperando por ele — é o caso da primeira medida, que
    // chega antes de a ilha aparecer.
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || window?.isVisible != true {
      shownMic = mic
      shownSystem = system
      return
    }

    startLink()
  }

  @objc private func step() {
    let t = min(1, (CACurrentMediaTime() - tweenStart) / Self.tween)

    shownMic = Self.lerp(fromMic, targetMic, t)
    shownSystem = Self.lerp(fromSystem, targetSystem, t)
    needsDisplay = true

    if t >= 1 { link?.isPaused = true }
  }

  private static func lerp(_ from: [Double], _ to: [Double], _ t: Double) -> [Double] {
    to.indices.map { index in
      let start = index < from.count ? from[index] : 0
      return start + (to[index] - start) * t
    }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil { invalidate() }
  }

  init(style: Style) {
    self.style = style
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) não é usado")
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    guard let activity = activity else { return }

    switch (activity.indicator, style) {
    case (.recording(let paused), .compact):
      drawDot(paused: paused)
      if bounds.width > 30 {
        drawBands(
          combined(shownMic, shownSystem, count: 4),
          color: palette.accent,
          in: NSRect(x: 16, y: 0, width: bounds.width - 16, height: bounds.height),
          paused: paused)
      }

    case (.recording(let paused), .wide):
      let half = (bounds.width - 12) / 2
      drawBands(
        shownMic, color: palette.accent,
        in: NSRect(x: 0, y: 0, width: half, height: bounds.height), paused: paused)
      // Azul, e não um segundo verde: são as duas faixas do painel do Echo, e
      // precisam se distinguir de relance do mesmo jeito.
      drawBands(
        shownSystem, color: palette.tide,
        in: NSRect(x: half + 12, y: 0, width: half, height: bounds.height), paused: paused)

    case (.progress(let value, let paused, let rest), .compact):
      drawRing(value, color: tone(paused: paused, rest: rest))

    case (.progress(let value, let paused, let rest), .wide):
      drawBar(value, color: tone(paused: paused, rest: rest))

    case (.shelf, _):
      drawShelf()
    }
  }

  /// Verde é "ligado e contando"; a pausa do ciclo e a sessão suspensa não
  /// são — o verde tem dois papéis no Evergreen, e nenhum dos dois é este.
  private func tone(paused: Bool, rest: Bool) -> NSColor {
    if paused { return palette.textTertiary }
    return rest ? palette.textSecondary : palette.accent
  }

  /// A bandeja da prateleira, o mesmo desenho que o Nest tem no menu e no Hub
  /// — aqui pelo símbolo do sistema, porque a ilha não tem os caminhos do
  /// `EgIcon`, e a bandeja do SF Symbols é o mesmo objeto.
  private func drawShelf() {
    let size = min(bounds.height, 14)
    let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
      .applying(.init(paletteColors: [palette.textPrimary]))

    guard let image = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)
    else { return }

    let rect = NSRect(
      x: 0,
      y: bounds.midY - image.size.height / 2,
      width: image.size.width,
      height: image.size.height)
    image.draw(in: rect)
  }

  private func drawDot(paused: Bool) {
    let size: CGFloat = 8
    let rect = NSRect(x: 0, y: bounds.midY - size / 2, width: size, height: size)

    if paused {
      let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
      path.lineWidth = 1.5
      palette.error.setStroke()
      path.stroke()
    } else {
      palette.error.setFill()
      NSBezierPath(ovalIn: rect).fill()
    }
  }

  /// As barras do jeito do painel do Echo (`EchoLevelTrack`): retângulos de
  /// cantos curtos, piso de 3 pt, e o silêncio como pista quase apagada — a
  /// faixa continua sendo uma linha, e não uma fileira de buracos. Uma
  /// cápsula com raio de meia largura vira gota nas barras largas, e a ilha
  /// passaria a falar outra língua visual que o painel.
  private func drawBands(_ bands: [Double], color: NSColor, in rect: NSRect, paused: Bool) {
    let count = max(bands.count, 1)
    let gap: CGFloat = 2
    let width = max(1.5, (rect.width - gap * CGFloat(count - 1)) / CGFloat(count))
    let floor: CGFloat = 3
    let radius = min(floor / 2, width / 2)

    for index in 0..<count {
      let level = paused || index >= bands.count ? 0 : CGFloat(min(max(bands[index], 0), 1))
      let height = floor + (rect.height - floor) * level
      let bar = NSRect(
        x: rect.minX + CGFloat(index) * (width + gap),
        y: rect.midY - height / 2,
        width: width,
        height: height)

      let base = paused ? palette.textTertiary : color
      base.withAlphaComponent(level <= 0.02 ? 0.18 : 1).setFill()
      NSBezierPath(roundedRect: bar, xRadius: radius, yRadius: radius).fill()
    }
  }

  private func drawRing(_ value: Double, color: NSColor) {
    let size = min(bounds.height, 12)
    let rect = NSRect(x: 0, y: bounds.midY - size / 2, width: size, height: size)
      .insetBy(dx: 1, dy: 1)
    let center = NSPoint(x: rect.midX, y: rect.midY)

    let track = NSBezierPath(ovalIn: rect)
    track.lineWidth = 2
    palette.control.setStroke()
    track.stroke()

    let arc = NSBezierPath()
    arc.appendArc(
      withCenter: center,
      radius: rect.width / 2,
      startAngle: 90,
      endAngle: 90 - 360 * CGFloat(min(max(value, 0), 1)),
      clockwise: true)
    arc.lineWidth = 2
    arc.lineCapStyle = .round
    color.setStroke()
    arc.stroke()
  }

  private func drawBar(_ value: Double, color: NSColor) {
    let height: CGFloat = 3
    let track = NSRect(x: 0, y: bounds.midY - height / 2, width: bounds.width, height: height)

    palette.control.setFill()
    NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5).fill()

    var done = track
    done.size.width = track.width * CGFloat(min(max(value, 0), 1))
    color.setFill()
    NSBezierPath(roundedRect: done, xRadius: 1.5, yRadius: 1.5).fill()
  }

  /// As duas faixas numa só, com menos barras: na asa não cabem vinte, e o
  /// que importa ali é "tem som entrando", não de qual lado.
  private func combined(_ mic: [Double], _ system: [Double], count: Int) -> [Double] {
    let length = max(mic.count, system.count)
    guard length > 0 else { return Array(repeating: 0, count: count) }

    return (0..<count).map { slot in
      let start = slot * length / count
      let end = max(start + 1, (slot + 1) * length / count)

      return (start..<end).map { index in
        max(index < mic.count ? mic[index] : 0, index < system.count ? system[index] : 0)
      }.max() ?? 0
    }
  }
}

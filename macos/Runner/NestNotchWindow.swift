import Cocoa

/// A janela sobre o recorte da tela.
///
/// **Não tem engine Flutter**, e é isso que mantém de pé a regra da casa de que
/// só a janela 0 desenha Flutter: aqui o custo é uma `NSWindow` com uma view que
/// pinta duas formas, não uma segunda superfície viva.
///
/// Por que o recorte, e não um atalho: a prateleira precisa ser invocada com o
/// botão do mouse já pressionado, no meio de um arraste, e apertar um atalho
/// segurando o botão é desconfortável. O recorte está sempre lá, no caminho de
/// quem já está arrastando, e não custa permissão nenhuma. Chacoalhar o arquivo
/// faz a mesma coisa e chegou depois (`NestDragWatch`); as duas portas convivem.
///
/// ## O alvo precisa se anunciar
///
/// A primeira versão não pintava um pixel, e não recebia arquivo nenhum. Três
/// coisas explicavam isso, e as três moram aqui agora:
///
/// 1. **O caminho do arraste.** Era uma `NSView` registrada como destino. Quem
///    funciona neste projeto é o **delegate da janela**, que foi o que sobreviveu
///    às três voltas de depuração do painel — ver `NestDrop`. Agora é ele
///    também aqui, e a view só pinta.
/// 2. **A janela nunca desenhava.** Uma janela não-opaca cuja superfície nunca
///    foi pintada tem chance de ser tratada como buraco pelo servidor de
///    janelas. O fundo a 1% de alfa parado resolve por um `fill`.
/// 3. **Era um alvo invisível de 200x32 pt.** Mirar nele com um arquivo na mão
///    era adivinhação, e a única forma de saber se acertou era o arquivo não
///    voltar.
///
/// **O recorte não tem pixels** — é um furo físico no painel, e pintar dentro
/// dele é pintar no escuro. Por isso o alvo aparece **abaixo** dele, na faixa da
/// barra de menus, e por isso ele é transitório: enquanto há um arquivo sendo
/// arrastado, a janela cresce um pouco para baixo e mostra a faixa; solto o
/// botão, ela encolhe de volta para o retângulo do recorte e some.
///
/// Crescer para baixo invade a área de conteúdo, onde a janela bloquearia
/// cliques. Isso é seguro exatamente porque só acontece armado — e armado quer
/// dizer "o botão esquerdo está pressionado com arquivo na mão", instante em que
/// não existe clique a bloquear.
///
/// Não existe API de recorte no macOS. O que existe é a medida da área segura
/// (`safeAreaInsets`, macOS 12+) e as duas faixas úteis ao lado dele
/// (`auxiliaryTopLeftArea`/`auxiliaryTopRightArea`); o que sobra entre elas é o
/// recorte. Abaixo do macOS 12, ou num Mac sem recorte, a janela não nasce — e a
/// linha some da tela de preferências em vez de ficar apagada.
class NestNotchWindow: NSPanel {
  private static var shared: NestNotchWindow?

  /// A preferência de quem usa. Nasce ligada; sem recorte não muda nada.
  private static var isEnabled = true

  /// Há um arquivo sendo arrastado agora. Ver `NestDragWatch`.
  private static var isArmed = false

  /// O quanto a janela cresce para baixo para caber a faixa.
  private static let armedGrowth: CGFloat = 28

  /// A medida do recorte quando a conta da tela não é confiável. Ver
  /// [notchFrame].
  private static let fallbackWidth: CGFloat = 200

  static func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    reposition()
  }

  /// Liga e desliga a faixa, conforme haja ou não arquivo sendo arrastado.
  static func setArmed(_ armed: Bool) {
    guard armed != isArmed else { return }
    isArmed = armed

    guard let window = shared, let view = window.contentView as? NestNotchView
    else { return }

    window.setFrame(frame(of: window.notchFrame), display: true)
    view.isArmed = armed
    view.isOver = false
  }

  /// Realce de "pode soltar", vindo do delegate de arraste.
  static func setOver(_ isOver: Bool) {
    (shared?.contentView as? NestNotchView)?.isOver = isOver
  }

  /// Cria, move ou destrói a janela conforme a tela do momento.
  ///
  /// Chamada também a cada mudança de configuração de tela: fechar a tampa e
  /// trabalhar num monitor externo tira o recorte de baixo da janela, e uma
  /// janela ancorada num `NSScreen` que não existe mais fica num canto qualquer
  /// recebendo arquivos que ninguém quis soltar ali.
  static func reposition() {
    guard isEnabled else {
      dismiss()
      return
    }

    guard let screen = screenWithNotch() else {
      dismiss()
      return
    }

    guard let notch = notchFrame(of: screen) else {
      // Este caminho era mudo, e mudo é como o módulo inteiro falha.
      NSLog("[Nest] tela com recorte encontrada, mas sem geometria utilizável.")
      dismiss()
      return
    }

    if let window = shared {
      window.notchFrame = notch
      window.setFrame(frame(of: notch), display: true)
      window.orderFrontRegardless()
      return
    }

    let window = NestNotchWindow(notch: notch)
    window.orderFrontRegardless()
    shared = window

    // O vigia do arraste segue a existência da janela, e não a preferência:
    // num Mac sem recorte não há faixa para armar, e o relógio seria trabalho
    // para não acender nada.
    NestDragWatch.setNotchEnabled(true)
  }

  private static func dismiss() {
    shared?.orderOut(nil)
    shared = nil
    NestDragWatch.setNotchEnabled(false)
  }

  /// O quadro da janela: o recorte parado, o recorte mais a faixa armado.
  private static func frame(of notch: NSRect) -> NSRect {
    guard isArmed else { return notch }

    return NSRect(
      x: notch.minX,
      y: notch.minY - armedGrowth,
      width: notch.width,
      height: notch.height + armedGrowth
    )
  }

  /// A tela que tem recorte, se alguma tiver.
  static func screenWithNotch() -> NSScreen? {
    guard #available(macOS 12.0, *) else { return nil }

    return NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
  }

  /// O retângulo do recorte, em coordenadas de tela.
  ///
  /// Com rede embaixo: se `auxiliaryTopLeftArea` ou `auxiliaryTopRightArea` vier
  /// nulo, as larguras viram zero e a conta devolveria **a barra de menus
  /// inteira** — um alvo de arraste invisível cobrindo tudo, com os cliques da
  /// barra de menus bloqueados junto. Largura implausível cai para a medida real
  /// do recorte dos MacBooks que o têm.
  private static func notchFrame(of screen: NSScreen) -> NSRect? {
    guard #available(macOS 12.0, *) else { return nil }

    let height = screen.safeAreaInsets.top
    guard height > 0 else { return nil }

    let left = screen.auxiliaryTopLeftArea?.width ?? 0
    let right = screen.auxiliaryTopRightArea?.width ?? 0
    let measured = screen.frame.width - left - right

    let isPlausible = measured > 0 && measured < screen.frame.width * 0.4
    let width = isPlausible ? measured : fallbackWidth
    let x = isPlausible
      ? screen.frame.minX + left
      : screen.frame.midX - width / 2

    return NSRect(
      x: x,
      y: screen.frame.maxY - height,
      width: width,
      height: height
    )
  }

  /// O retângulo do recorte, sem a faixa. É dele que os dois quadros saem.
  private var notchFrame: NSRect

  /// O delegate de arraste, retido aqui porque `window.delegate` é fraca.
  private var dropDelegate: NestWindowDropDelegate?

  private init(notch: NSRect) {
    notchFrame = notch

    super.init(
      contentRect: Self.frame(of: notch),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = false
    isFloatingPanel = true
    hidesOnDeactivate = false

    // Acima da barra de menus: o recorte fica dentro dela, e no nível dela a
    // janela ficaria por baixo justamente na faixa que precisa receber o
    // arquivo.
    level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

    // `.stationary` para a janela não ser arrastada junto na animação de troca
    // de Space: ela é parte da tela, não do Space.
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

    contentView = NestNotchView(frame: NSRect(origin: .zero, size: frame.size))

    // Quem recebe o arraste é o **delegate**, e não a view: `NSWindow` não
    // implementa `NSDraggingDestination`, e o caminho do delegate é o único que
    // este projeto já viu funcionar. Ver `NestDrop`.
    registerForDraggedTypes([.fileURL])

    let proxy = NestWindowDropDelegate(alwaysAccepts: true, next: nil) { isOver in
      NestNotchWindow.setOver(isOver)
    }

    dropDelegate = proxy
    delegate = proxy
  }

  /// Nunca recebe o teclado: não há nada aqui para digitar, e virar key faria o
  /// recorte roubar o cursor de quem estava escrevendo em outro aplicativo.
  /// Receber arquivo não depende disso — destino de arraste e foco de teclado
  /// são coisas separadas no AppKit.
  override var canBecomeKey: Bool { false }
}

/// O que a janela do recorte pinta.
///
/// Parado, um retângulo a 1% de alfa: invisível ao olho, e superfície desenhada
/// o bastante para o servidor de janelas não tratar a janela como buraco.
///
/// Armado, a faixa embaixo do recorte — que é onde há pixels de verdade. Sem cor
/// de marca de propósito: o recorte é hardware, não interface, e branco com alfa
/// é o que faz a faixa parecer o próprio recorte crescendo em vez de um elemento
/// do aplicativo pousado ali.
class NestNotchView: NSView {
  var isArmed = false {
    didSet { if isArmed != oldValue { needsDisplay = true } }
  }

  var isOver = false {
    didSet { if isOver != oldValue { needsDisplay = true } }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) não é usado")
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.withAlphaComponent(0.01).setFill()
    bounds.fill()

    guard isArmed else { return }

    // A faixa mora na metade de baixo da janela: a de cima é o recorte, onde
    // não há pixel para acender.
    let band = NSRect(
      x: bounds.minX + 6,
      y: bounds.minY + 4,
      width: bounds.width - 12,
      height: max(bounds.height - 40, 12)
    )

    let shape = NSBezierPath(roundedRect: band, xRadius: 7, yRadius: 7)

    NSColor.white.withAlphaComponent(isOver ? 0.22 : 0.10).setFill()
    shape.fill()

    NSColor.white.withAlphaComponent(isOver ? 0.55 : 0.22).setStroke()
    shape.lineWidth = 1
    shape.stroke()
  }
}

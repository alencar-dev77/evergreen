import Cocoa

/// Os dois gestos que chamam a prateleira no meio de um arraste: chacoalhar o
/// arquivo, e levá-lo até o notch.
///
/// Os dois moram juntos porque perguntam as mesmas coisas ao mesmo relógio —
/// o botão está apertado? onde está o cursor? tem arquivo na mão? — e dois
/// relógios de 60 Hz rodando a cada clique seria o dobro do custo para a mesma
/// resposta.
///
/// **Consulta, não evento.** Durante uma sessão de arraste do sistema o AppKit
/// não entrega os movimentos do mouse a monitor nenhum — foi por isso que o
/// `NestChannel.followCursor` virou um relógio. `NSEvent.mouseLocation` e
/// `NSEvent.pressedMouseButtons` são propriedades que se perguntam, respondem
/// certo com o botão apertado e não custam permissão. O monitor global aqui só
/// precisa acertar o instante em que o botão **desce**, que acontece antes de a
/// sessão de arraste começar — e monitor global de mouse, diferente do de
/// teclado, não pede Acessibilidade.
///
/// Com o botão solto não há relógio rodando: o custo em repouso é um bloco
/// parado esperando um clique.
///
/// Só o monitor global, sem o local: arquivo arrastado vem sempre de outro
/// aplicativo (Finder, Mail, navegador), e o único arraste que nasce dentro do
/// Evergreen é o da própria prateleira — que já está na tela, e onde chacoalhar
/// não deve fazer nada.
enum NestDragMonitor {
  /// As preferências de quem usa. Ver `NestSettings.useShake` e
  /// `NotchSettings.nest`.
  private static var isShakeEnabled = false
  private static var isNotchEnabled = false

  private static var downMonitor: Any?
  private static var sampler: Timer?

  /// A área de transferência do arraste, guardada porque o vigia a consulta a
  /// cada quadro e pedi-la pelo nome sessenta vezes por segundo é trabalho para
  /// não descobrir nada.
  private static let dragPasteboard = NSPasteboard(name: .drag)

  // MARK: - O estado de um aperto de botão

  /// O `changeCount` da área de transferência de arraste quando o botão desceu.
  ///
  /// É metade do filtro que separa "arrastando arquivo" de "chacoalhando uma
  /// janela pela barra de título". A outra metade é o tipo do conteúdo: o tipo
  /// sozinho sobra de um arraste anterior, e a mudança sozinha não diz que é
  /// arquivo. Ver [hasFilesInHand].
  private static var dragCountAtDown = 0

  /// A resposta de "tem arquivo na mão?", já dada neste aperto de botão.
  ///
  /// Guardada porque ela não muda no meio de um arraste, e a pergunta só é feita
  /// quando um gesto já foi reconhecido — o caminho caro não roda a cada
  /// quadro.
  private static var hasFiles = false

  /// O `changeCount` em que a resposta foi "não" — arraste de texto, de
  /// imagem. Vale só enquanto a área de transferência não mudar: quem arrasta
  /// escreve nela em dois passos (limpa, depois põe os itens), e um "não"
  /// lido entre os dois, guardado de vez, mataria o gesto do arraste inteiro.
  private static var noFilesAtCount: Int?

  private static var lastPoint: NSPoint?

  /// A perna atual: a soma dos movimentos que ainda seguem na mesma direção.
  private static var leg = CGVector.zero

  /// Os instantes em que a direção se inverteu, dentro da janela de tempo.
  private static var reversals: [TimeInterval] = []

  /// Já chamou a prateleira neste aperto de botão — por qualquer um dos dois
  /// gestos. Um chacoalhar não pode virar três aberturas, e chacoalhar em cima
  /// do notch não pode virar duas.
  private static var hasFired = false

  /// Quem chamou, quando foi o notch: é a ele que o "soltou" é avisado.
  private static var firedByNotch = false

  /// O recorte da tela onde o botão desceu, medido uma vez por aperto: a
  /// geometria da tela não muda no meio de um arraste, e perguntá-la a cada
  /// quadro seria trabalho para a mesma resposta. `nil` em tela sem recorte —
  /// e aí o gesto simplesmente não existe.
  private static var notchZone: NSRect?

  /// Desde quando o cursor está parado dentro do recorte, com arquivo na mão,
  /// e onde ele parou.
  private static var notchSince: TimeInterval?
  private static var notchAnchor: NSPoint?

  /// A borda de cima da tela do recorte é parede — não há outra tela
  /// encostada acima dele. Ver [notchDwell].
  private static var notchEdgeIsWall = false

  // MARK: - Os números do chacoalhar

  /// O quanto a mão precisa andar numa direção para a volta contar como
  /// inversão. Abaixo disso é tremor de quem está mirando o destino.
  private static let minimumLeg: CGFloat = 45

  /// Movimento menor que isto entre duas amostras não muda nada — nem soma na
  /// perna, nem conta como volta.
  private static let minimumStep: CGFloat = 1

  /// Em quanto tempo as inversões precisam acontecer para serem um chacoalhar,
  /// e não três correções de rota.
  private static let timeWindow: TimeInterval = 0.6

  private static let neededReversals = 3

  // MARK: - Os números do notch

  /// Quanto o arquivo precisa ficar na zona do recorte para a prateleira sair
  /// dele.
  ///
  /// É espera de cursor **parado** (ver [notchStill]), e não de tempo dentro
  /// da faixa: a faixa abaixo da barra de menus é a das abas de um navegador
  /// maximizado, e deslizar o arquivo por elas passaria de qualquer espera.
  ///
  /// **Encostar no topo da tela não espera nada — quando o topo é parede**
  /// (ver [edgeIsWall]). Um arraste que encosta na
  /// borda de cima abre o Mission Control — o macOS ganhava a corrida dos
  /// 200 ms da primeira versão, e a prateleira nunca saía. Na borda, dentro da
  /// largura do recorte, não há menu nem destino nenhum a confundir: é o furo
  /// da câmera, e chegar até ele já é a intenção inteira.
  private static let notchDwell: TimeInterval = 0.15

  /// Quanto abaixo da barra de menus a zona ainda vale.
  ///
  /// Quem mira o recorte chega por baixo dele, e a prateleira sai antes de o
  /// cursor alcançar a borda — e com ela o Mission Control. É também onde a
  /// prateleira aparece, então o arquivo já chega em cima dela.
  private static let notchApproach: CGFloat = 48

  /// A folga de cada lado do recorte. O cursor não tem como entrar *no* furo —
  /// ele para na borda da tela —, e mirar a largura exata de um objeto que não
  /// tem pixel é pedir precisão que ninguém tem com um arquivo na mão.
  ///
  /// A mesma largura das asas da ilha: o alvo é tudo o que se vê preto em
  /// volta do recorte quando algo está rodando, e não só o furo.
  private static let notchSlack: CGFloat = 60

  // MARK: - Ligar e desligar

  static func setShakeEnabled(_ enabled: Bool) {
    isShakeEnabled = enabled
    reconcile()
  }

  static func setNotchEnabled(_ enabled: Bool) {
    isNotchEnabled = enabled
    reconcile()
  }

  /// O monitor existe enquanto pelo menos um gesto quer ouvir — e o notch só
  /// quer ouvir em tela que tem um. Em Mac sem recorte, quem desligou o
  /// chacoalhar não paga um relógio a cada clique por uma porta que não existe.
  private static func reconcile() {
    observeScreens()

    if isShakeEnabled || (isNotchEnabled && NotchGeometry.current() != nil) {
      install()
    } else {
      uninstall()
    }
  }

  private static var screenObserver: NSObjectProtocol?

  /// A tampa que abre traz o recorte de volta, e a que fecha o leva.
  private static func observeScreens() {
    guard screenObserver == nil else { return }

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { _ in reconcile() }
  }

  private static func install() {
    guard downMonitor == nil else { return }

    downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
      begin()
    }
  }

  private static func uninstall() {
    if let monitor = downMonitor { NSEvent.removeMonitor(monitor) }
    downMonitor = nil
    stop()
  }

  // MARK: - A amostragem

  private static func begin() {
    stop()

    dragCountAtDown = dragPasteboard.changeCount
    let notch = isNotchEnabled ? NotchGeometry.current() : nil
    notchZone = zone(around: notch)
    notchEdgeIsWall = notch.map(edgeIsWall) ?? false

    sampler = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
      sample()
    }
  }

  private static func stop() {
    let endedNotchGesture = firedByNotch

    sampler?.invalidate()
    sampler = nil
    lastPoint = nil
    leg = .zero
    reversals = []
    hasFired = false
    firedByNotch = false
    hasFiles = false
    noFilesAtCount = nil
    notchZone = nil
    notchSince = nil
    notchAnchor = nil

    // A prateleira que saiu do notch precisa saber que o arraste acabou: solto
    // em lugar nenhum, com ela vazia, ela volta para onde veio.
    if endedNotchGesture {
      NotchIslandChannel.setPassThrough(false)
      NestChannel.reportNotchDragEnded()
    }
  }

  private static func sample() {
    // A saída é por consulta, e não pelo `.leftMouseUp`: dentro de uma sessão
    // de arraste aquele evento não chega ao monitor, e o relógio ficaria
    // rodando para sempre depois do primeiro arquivo solto.
    guard NSEvent.pressedMouseButtons & 1 != 0 else {
      stop()
      return
    }

    guard !hasFired else { return }

    let point = NSEvent.mouseLocation

    if isNotchEnabled { sampleNotch(at: point) }
    if isShakeEnabled, !hasFired { sampleShake(at: point) }
  }

  // MARK: - O notch

  private static func sampleNotch(at point: NSPoint) {
    // `NSMouseInRect`, e não `contains`: o cursor encostado no topo da tela
    // tem `y == maxY`, e o `contains` do `NSRect` deixa a borda de cima de
    // fora — justamente onde o arquivo para quando a mão o empurra até o fim.
    guard let zone = notchZone, NSMouseInRect(point, zone, false) else {
      notchSince = nil
      return
    }

    // Nada conta antes de haver arquivo na mão — nem o relógio da espera.
    // Começado antes, ele já teria vencido quando o arraste nascesse, e o
    // ícone de documento de uma janela maximizada, que cai nesta faixa,
    // chamaria a prateleira no primeiro quadro do arraste.
    guard hasFilesInHand() else {
      notchSince = nil
      return
    }

    // Na borda de cima, sem espera: ver [notchDwell].
    if notchEdgeIsWall, point.y >= zone.maxY - 1 {
      fireNotch()
      return
    }

    let now = Date.timeIntervalSinceReferenceDate

    // A espera é de cursor **parado**, não de tempo dentro da faixa: deslizar
    // o arquivo pelas abas do navegador, logo abaixo da barra de menus, passa
    // de 150 ms na faixa sem querer prateleira nenhuma. Andou mais que a
    // tolerância, o relógio recomeça de onde ele está agora.
    if let anchor = notchAnchor, hypot(point.x - anchor.x, point.y - anchor.y) > notchStill {
      notchSince = nil
    }

    guard let since = notchSince else {
      notchSince = now
      notchAnchor = point
      return
    }

    guard now - since >= notchDwell else { return }
    fireNotch()
  }

  /// O quanto a mão pode tremer e ainda contar como parada.
  private static let notchStill: CGFloat = 6

  /// Há outra tela encostada acima do recorte? Com um monitor posto em cima do
  /// MacBook, a borda de cima é passagem, e não parede: o cursor a atravessa a
  /// caminho do outro monitor, e não há Mission Control para correr dele.
  private static func edgeIsWall(_ notch: NotchGeometry) -> Bool {
    let top = notch.screen.frame.maxY
    let span = notch.rect.insetBy(dx: -notchSlack, dy: 0)

    return !NSScreen.screens.contains { screen in
      screen !== notch.screen
        && abs(screen.frame.minY - top) < 1
        && screen.frame.maxX > span.minX
        && screen.frame.minX < span.maxX
    }
  }

  private static func fireNotch() {
    hasFired = true
    firedByNotch = true
    // A ilha sai do caminho enquanto este arraste durar: ela fica acima da
    // janela 0, e não é destino de arquivo — abrir com o cursor em cima dela
    // cobriria o topo da prateleira que acabou de sair do notch.
    NotchIslandChannel.setPassThrough(true)
    NestChannel.reportNotch()
  }

  /// A faixa que conta como "no recorte": a largura dele mais a folga, a
  /// altura inteira da barra de menus e mais [notchApproach] abaixo dela.
  private static func zone(around notch: NotchGeometry?) -> NSRect? {
    guard let notch = notch else { return nil }

    var zone = notch.rect.insetBy(dx: -notchSlack, dy: 0)
    zone.origin.y -= notchApproach
    zone.size.height += notchApproach

    return zone
  }

  // MARK: - O chacoalhar

  private static func sampleShake(at point: NSPoint) {
    guard let last = lastPoint else {
      lastPoint = point
      return
    }

    let step = CGVector(dx: point.x - last.x, dy: point.y - last.y)
    guard length(step) >= minimumStep else { return }

    lastPoint = point

    if leg == .zero {
      leg = step
      return
    }

    // Sem eixo privilegiado: o chacoalhar de verdade é tão diagonal quanto
    // horizontal, então quem decide se a mão voltou é o produto escalar com a
    // perna, não o sinal de `dx`.
    if leg.dx * step.dx + leg.dy * step.dy >= 0 {
      leg = CGVector(dx: leg.dx + step.dx, dy: leg.dy + step.dy)
      return
    }

    if length(leg) >= minimumLeg { registerReversal() }
    leg = step
  }

  /// Tem arquivo na mão? Pergunta uma vez por aperto de botão.
  ///
  /// As duas condições juntas, e nunca uma só: a área de transferência de
  /// arraste guarda o conteúdo do último arraste depois que ele termina, então
  /// o tipo sozinho diria "sim" para quem está chacoalhando o mouse à toa cinco
  /// minutos depois de mover um arquivo.
  ///
  /// A comparação de `changeCount` é a barata, e vem primeiro de propósito.
  private static func hasFilesInHand() -> Bool {
    if hasFiles { return true }

    let count = dragPasteboard.changeCount
    guard count != dragCountAtDown, count != noFilesAtCount else { return false }

    hasFiles = dragPasteboard.canReadObject(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    )
    if !hasFiles { noFilesAtCount = count }

    return hasFiles
  }

  private static func registerReversal() {
    let now = Date.timeIntervalSinceReferenceDate

    reversals.append(now)
    reversals.removeAll { now - $0 > timeWindow }

    guard reversals.count >= neededReversals, hasFilesInHand() else { return }

    hasFired = true
    NestChannel.reportShake()
  }

  private static func length(_ vector: CGVector) -> CGFloat {
    (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
  }
}

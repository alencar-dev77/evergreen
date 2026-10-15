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

  /// Desde quando o cursor está parado dentro do recorte, com arquivo na mão.
  private static var notchSince: TimeInterval?

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

  /// Quanto o arquivo precisa ficar no recorte para a prateleira sair dele.
  ///
  /// É o que separa quem levou o arquivo até ali de quem só passou a caminho
  /// da barra de menus: o caminho até um menu atravessa o recorte em poucos
  /// quadros, e quem quer a prateleira para em cima dele.
  private static let notchDwell: TimeInterval = 0.2

  /// A folga de cada lado do recorte. O cursor não tem como entrar *no* furo —
  /// ele para na borda da tela —, e mirar a largura exata de um objeto que não
  /// tem pixel é pedir precisão que ninguém tem com um arquivo na mão.
  private static let notchSlack: CGFloat = 16

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
    notchZone = isNotchEnabled ? zone(around: NotchGeometry.current()) : nil

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
    notchZone = nil
    notchSince = nil

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

    let now = Date.timeIntervalSinceReferenceDate

    guard let since = notchSince else {
      notchSince = now
      return
    }

    guard now - since >= notchDwell, hasFilesInHand() else { return }

    hasFired = true
    firedByNotch = true
    // A ilha sai do caminho enquanto este arraste durar: ela fica acima da
    // janela 0, e não é destino de arquivo — abrir com o cursor em cima dela
    // cobriria o topo da prateleira que acabou de sair do notch.
    NotchIslandChannel.setPassThrough(true)
    NestChannel.reportNotch()
  }

  /// A faixa que conta como "dentro do recorte": a largura dele mais a folga, e
  /// a altura inteira da barra de menus.
  ///
  /// A altura inteira, e não só a borda: o cursor encosta no topo da tela, mas
  /// quem arrasta um arquivo para cima raramente o leva até o último pixel.
  private static func zone(around notch: NotchGeometry?) -> NSRect? {
    guard let notch = notch else { return nil }

    return notch.rect.insetBy(dx: -notchSlack, dy: 0)
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

    guard dragPasteboard.changeCount != dragCountAtDown else { return false }

    hasFiles = dragPasteboard.canReadObject(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    )

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

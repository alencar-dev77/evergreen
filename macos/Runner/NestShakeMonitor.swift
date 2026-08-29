import Cocoa

/// Chacoalhar o arquivo no meio do arraste para chamar a prateleira.
///
/// É o gesto que quem vem do Dropover tenta primeiro, e ele foi descartado na
/// primeira versão do Nest por uma razão que estava errada: "exigiria monitorar
/// eventos globais, mais uma permissão". Não exige nenhuma das duas coisas.
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
enum NestShakeMonitor {
  /// A preferência de quem usa. Ver `NestSettings.useShake`.
  private static var isEnabled = false

  private static var downMonitor: Any?
  private static var sampler: Timer?

  // MARK: - O estado de um aperto de botão

  /// O `changeCount` da área de transferência de arraste quando o botão desceu.
  ///
  /// É metade do filtro que separa "arrastando arquivo" de "chacoalhando uma
  /// janela pela barra de título". A outra metade é o tipo do conteúdo: o tipo
  /// sozinho sobra de um arraste anterior, e a mudança sozinha não diz que é
  /// arquivo. Ver [isDraggingFiles].
  private static var dragCountAtDown = 0

  private static var lastPoint: NSPoint?

  /// A perna atual: a soma dos movimentos que ainda seguem na mesma direção.
  private static var leg = CGVector.zero

  /// Os instantes em que a direção se inverteu, dentro da janela de tempo.
  private static var reversals: [TimeInterval] = []

  /// Já chamou a prateleira neste aperto de botão. Um chacoalhar não pode virar
  /// três aberturas.
  private static var hasFired = false

  // MARK: - Os números do gesto

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

  // MARK: - Ligar e desligar

  static func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled else { return }
    isEnabled = enabled

    if enabled {
      install()
    } else {
      uninstall()
    }
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

    dragCountAtDown = NSPasteboard(name: .drag).changeCount

    sampler = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
      sample()
    }
  }

  private static func stop() {
    sampler?.invalidate()
    sampler = nil
    lastPoint = nil
    leg = .zero
    reversals = []
    hasFired = false
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

  private static func registerReversal() {
    let now = Date.timeIntervalSinceReferenceDate

    reversals.append(now)
    reversals.removeAll { now - $0 > timeWindow }

    guard reversals.count >= neededReversals, isDraggingFiles() else { return }

    hasFired = true
    NestChannel.reportShake()
  }

  /// Tem arquivo na mão agora?
  ///
  /// As duas condições juntas, e nunca uma só: a área de transferência de
  /// arraste guarda o conteúdo do último arraste depois que ele termina, então
  /// o tipo sozinho diria "sim" para quem está chacoalhando o mouse à toa cinco
  /// minutos depois de mover um arquivo.
  private static func isDraggingFiles() -> Bool {
    let pasteboard = NSPasteboard(name: .drag)
    guard pasteboard.changeCount != dragCountAtDown else { return false }

    return pasteboard.canReadObject(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    )
  }

  private static func length(_ vector: CGVector) -> CGFloat {
    (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
  }
}

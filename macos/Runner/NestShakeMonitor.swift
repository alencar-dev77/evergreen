import Cocoa

/// Chacoalhar o arquivo no meio do arraste para chamar a prateleira.
///
/// É o gesto que quem vem do Dropover tenta primeiro, e ele foi descartado na
/// primeira versão do Nest por uma razão que estava errada.
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
  /// quando o chacoalhar já foi reconhecido — o caminho caro não roda a cada
  /// quadro.
  private static var hasFiles = false

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

    dragCountAtDown = dragPasteboard.changeCount

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
    hasFiles = false
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

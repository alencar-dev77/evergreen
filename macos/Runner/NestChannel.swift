import Cocoa
import FlutterMacOS
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// O que o Nest não consegue fazer em Flutter puro.
///
/// Quatro coisas, e nenhuma tem equivalente em Dart:
///
/// - **Receber um arraste do Finder.** Quem recebe é o delegate de uma
///   `NSWindow` do AppKit; o Flutter não expõe a sessão de arraste do sistema.
/// - **Gerar a miniatura de um arquivo qualquer.** `QLThumbnailGenerator` é o
///   mesmo mecanismo que desenha as prévias do Finder, e cobre de graça PDF,
///   vídeo, Keynote, código com realce e tudo o mais que o sistema saiba abrir.
/// - **Abrir o seletor de pasta.** `NSOpenPanel`.
/// - **Mandar para o Lixo com direito a desfazer.** `NSWorkspace.recycle` —
///   `File.delete` do Dart apaga de verdade, e não volta.
///
/// A janela 0 é compartilhada pelos seis painéis, então o destino de arraste só
/// aceita quando o painel do Nest está à vista: [setDropEnabled] é ligado e
/// desligado pela própria tela. Soltar um arquivo em cima do Focus não deve
/// significar nada.
class NestChannel: NSObject {
  static let channelName = "nest"

  /// O canal do engine da janela 0 — o único que recebe os avisos de arraste.
  ///
  /// Os outros engines (hoje o Hub) registram o canal para poder *chamar*
  /// métodos — escolher pasta, ligar o chacoalhar —, mas nunca são
  /// notificados: quem guarda a prateleira é a janela 0, e um Hub aberto no meio
  /// de um arraste não pode virar o dono do evento.
  ///
  /// **Forte, e essa é a linha inteira do bug mais caro deste módulo.** Um
  /// `FlutterMethodChannel` não é retido por ninguém: o `binaryMessenger` guarda
  /// o *bloco* que atende as chamadas vindas do Dart, não o objeto. Com uma
  /// referência fraca aqui, o canal era desalocado assim que [register]
  /// terminava — e aí tudo o que vem do Dart continuava funcionando (o bloco
  /// está vivo), enquanto tudo o que vai **para** o Dart caía no vazio: o
  /// arquivo era aceito pelo AppKit, `invokeMethod` era chamado num `nil`, e a
  /// prateleira nunca via nada chegar. Sem erro, sem aviso, com o arraste
  /// respondendo `.copy` normalmente.
  ///
  /// O `PasteboardWatcherChannel` tem o mesmo `weak` e escapa por acidente: o
  /// bloco dele menciona `channel`, então a closure o retém.
  private static var overlayChannel: FlutterMethodChannel?

  /// A janela 0 aceita arquivos agora.
  private(set) static var isDropEnabled = false

  /// A janela 0, para ligar e desligar a passagem de clique. Ver
  /// [setInteractiveRect].
  private static weak var overlayWindow: NSWindow?

  /// O retângulo do painel dentro da janela 0, em coordenadas da janela.
  ///
  /// Enquanto ele existe, a janela deixa passar todo clique que cair **fora**
  /// dele. Ver [followCursor].
  private static var interactiveRect: NSRect?

  /// O relógio que segue o cursor enquanto o painel do Nest está na tela.
  private static var cursorTimer: Timer?

  /// O último clique ou arrasto recebido pela janela 0.
  ///
  /// `beginDraggingSession` exige o `NSEvent` que originou o gesto — ele é quem
  /// diz de onde o arraste sai. O Flutter não o entrega ao Dart, então a janela
  /// guarda o último por conta própria.
  private static var lastMouseEvent: NSEvent?
  private static var mouseMonitor: Any?

  /// A origem do arraste em curso. Retida porque `beginDraggingSession` não
  /// retém a fonte.
  private static var dragSource: NestDragSource?

  /// Há um arraste **saindo** da prateleira agora.
  private static var isDraggingOut = false

  /// Quem cumpre as promessas do arraste que move. Um só, sem estado — o
  /// caminho de cada arquivo vai no `userInfo` da promessa —, e estático
  /// porque a `NSFilePromiseProvider` guarda o delegate como referência fraca
  /// e o destino pode pedir o arquivo depois de a sessão terminar.
  private static let promiseMover = NestPromiseMover()

  static func register(with messenger: FlutterBinaryMessenger, isOverlay: Bool) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    if isOverlay { overlayChannel = channel }

    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]

      switch call.method {
      case "setShakeEnabled":
        NestDragMonitor.setShakeEnabled(arguments?["enabled"] as? Bool ?? false)
        result(nil)

      case "setNotchEnabled":
        NestDragMonitor.setNotchEnabled(arguments?["enabled"] as? Bool ?? false)
        result(nil)

      case "setDropEnabled":
        isDropEnabled = arguments?["enabled"] as? Bool ?? false
        if isDropEnabled { installDropDelegate() } else { setInteractiveRect(nil) }
        result(nil)

      case "setInteractiveRect":
        setInteractiveRect(rect(from: arguments))
        result(nil)

      case "beginDrag":
        beginDrag(
          paths: arguments?["paths"] as? [String] ?? [],
          move: arguments?["move"] as? Bool ?? false,
          result: result
        )

      case "thumbnail":
        guard let path = arguments?["path"] as? String else {
          result(FlutterError(code: "bad_arguments", message: "path é obrigatório", details: nil))
          return
        }
        requestThumbnail(path: path, size: arguments?["size"] as? Double ?? 96)
        result(nil)

      case "chooseFolder":
        result(chooseFolder())

      case "revealInFinder":
        if let path = arguments?["path"] as? String {
          NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
        result(nil)

      case "moveToTrash":
        moveToTrash(path: arguments?["path"] as? String, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// O delegate de arraste da janela 0, retido aqui porque `window.delegate` é
  /// uma referência fraca.
  private static var overlayDropDelegate: NestWindowDropDelegate?

  static func adopt(_ window: NSWindow) {
    overlayWindow = window
    window.registerForDraggedTypes([.fileURL])
    installDropDelegate()

    mouseMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged]
    ) { event in
      if event.window === overlayWindow { lastMouseEvent = event }
      return event
    }
  }

  // MARK: - Arrastar para fora

  /// Começa a arrastar a prateleira inteira para fora do Evergreen.
  ///
  /// Quem faz a cópia ou a movimentação é o **destino** — o Finder, o campo de
  /// anexo do Mail —, não nós: o que sai daqui é uma lista de `file URL` e a
  /// operação declarada. Por isso este caminho não tem desfazer: o Evergreen não
  /// fica sabendo para onde os arquivos foram.
  ///
  /// A operação é a que o painel está mostrando (a preferência, invertida pelo
  /// `⌥`), e não a do sistema: dentro do módulo, "copiar ou mover" tem uma
  /// resposta só, e ela está escrita na tela em cima da lista.
  ///
  /// **Mover sai como promessa de arquivo, e quem move somos nós.** Declarar
  /// `.move` com um `file URL` deixava a decisão com o destino, e o destino lê
  /// as modificadoras sozinho: no caminho "padrão copiar, `⌥` para mover", o
  /// Finder via o `⌥` ainda apertado, queria `.copy`, não achava `.copy` na
  /// máscara e mostrava o sinal de proibido (#67). O `ignoreModifierKeys` do
  /// nosso lado não alcança o que o destino lê. Com a promessa, o destino só
  /// diz **para onde**, e o `⌥` deixa de ter o que contrariar. O preço: quem
  /// não aceita promessa (campo de upload de navegador) não recebe arquivo
  /// movido — e mover para dentro de um upload nunca fez sentido.
  private static func beginDrag(
    paths: [String],
    move: Bool,
    result: @escaping FlutterResult
  ) {
    guard !paths.isEmpty,
          let window = overlayWindow,
          let view = window.contentView,
          let event = lastMouseEvent ?? NSApp.currentEvent
    else {
      result(false)
      return
    }

    let origin = view.convert(event.locationInWindow, from: nil)

    let items = paths.enumerated().map { index, path -> NSDraggingItem in
      let writer: NSPasteboardWriting = move
        ? promise(for: path)
        : URL(fileURLWithPath: path) as NSURL
      let item = NSDraggingItem(pasteboardWriter: writer)
      let step = CGFloat(index) * 4

      // Um monte de ícones ligeiramente deslocados: é como o Finder mostra
      // vários arquivos saindo juntos, e diz sem texto quantos são.
      item.setDraggingFrame(
        NSRect(x: origin.x - 16 + step, y: origin.y - 16 - step, width: 32, height: 32),
        contents: NSWorkspace.shared.icon(forFile: path)
      )

      return item
    }

    let source = NestDragSource(move: move)
    dragSource = source
    isDraggingOut = true

    // A janela **não** é tirada do caminho: fora do painel o relógio do cursor
    // já a faz sumir para o mouse, e é isso que deixa o arquivo chegar ao
    // Finder. Sobre o painel ela continua interceptando — e recusa o próprio
    // arraste (ver `NestDrop`), que é o que faz soltar em cima da prateleira
    // significar "desisti" em vez de largar o arquivo na janela que estava
    // atrás dela.
    view.beginDraggingSession(with: items, event: event, source: source)
    result(true)
  }

  /// A promessa de um arquivo da prateleira. O tipo é o do próprio arquivo, que
  /// é o que o destino usa para decidir se aceita.
  private static func promise(for path: String) -> NSFilePromiseProvider {
    let url = URL(fileURLWithPath: path)
    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    let type = isDirectory
      ? UTType.folder
      : UTType(filenameExtension: url.pathExtension) ?? .data

    let provider = NSFilePromiseProvider(fileType: type.identifier, delegate: promiseMover)
    provider.userInfo = path
    return provider
  }

  /// O arraste terminou — no Finder, na lixeira ou em lugar nenhum.
  ///
  /// Num arraste de promessa o destino responde `.copy` — do ponto de vista
  /// dele, recebeu um arquivo novo —, mas quem o escreveu fomos nós, movendo.
  /// Por isso [promised] traduz a resposta de volta para "mover".
  static func dragOutEnded(_ operation: NSDragOperation, promised: Bool) {
    isDraggingOut = false
    dragSource = nil

    // Com o painel ainda na tela é o relógio do cursor que retoma o comando.
    // Sem ele — o painel fechou no meio do arraste —, a janela ficaria
    // atravessável para sempre, e nenhum outro painel receberia clique.
    if interactiveRect == nil { overlayWindow?.ignoresMouseEvents = false }

    let name: String
    if promised && !operation.isEmpty {
      name = "move"
    } else if operation.contains(.move) {
      name = "move"
    } else if operation.contains(.copy) {
      name = "copy"
    } else {
      name = "none"
    }

    DispatchQueue.main.async {
      overlayChannel?.invokeMethod("onDragOutEnded", arguments: ["operation": name])
    }
  }

  /// Põe o delegate de arraste na frente do que estiver lá.
  ///
  /// Chamado de novo a cada abertura do painel do Nest, e não só na montagem:
  /// se o `window_manager` reescrever o delegate da janela em algum momento, o
  /// arraste voltaria a não funcionar em silêncio — e este é o tipo de falha que
  /// só aparece com um arquivo na mão.
  private static func installDropDelegate() {
    guard let window = overlayWindow else { return }

    if let installed = window.delegate as? NestWindowDropDelegate {
      overlayDropDelegate = installed
      return
    }

    let proxy = NestWindowDropDelegate(next: window.delegate as? NSObject)

    overlayDropDelegate = proxy
    window.delegate = proxy
  }

  /// Diz onde o painel está desenhado dentro da janela 0 — ou `nil` quando o
  /// painel do Nest sai de cena.
  ///
  /// Existe por causa de um problema que só o Nest tem. A janela 0 é bem maior
  /// que qualquer painel (ela cabe o maior deles mais a sombra), e o resto dela
  /// é transparente **mas ainda captura clique** — é o que faz "clicar fora
  /// fecha" funcionar nos outros painéis. No Nest isso é fatal: a prateleira
  /// existe para ir buscar arquivos em outro aplicativo, e com ela aberta não se
  /// conseguia nem clicar numa janela do Finder atrás.
  ///
  /// Então, enquanto o painel do Nest está na tela, a janela passa a deixar o
  /// clique atravessar em toda a área fora do painel.
  private static func setInteractiveRect(_ rect: NSRect?) {
    interactiveRect = rect

    guard rect != nil else {
      cursorTimer?.invalidate()
      cursorTimer = nil
      overlayWindow?.ignoresMouseEvents = false
      return
    }

    followCursor()
  }

  /// Liga e desliga a passagem de clique conforme o cursor entra e sai do
  /// painel.
  ///
  /// Um relógio, e não `NSEvent.addGlobalMonitorForEvents`: durante uma sessão
  /// de arraste do sistema — que é exatamente quando isto precisa funcionar — o
  /// monitor global não recebe os movimentos, e a janela ficaria atravessável
  /// justamente na hora de soltar o arquivo nela. `NSEvent.mouseLocation` é uma
  /// consulta, não um evento: responde certo durante o arraste, e não custa
  /// permissão nenhuma.
  private static func followCursor() {
    guard cursorTimer == nil else { return }

    cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
      guard let window = overlayWindow, let rect = interactiveRect else { return }

      let panel = window.convertToScreen(rect)
      window.ignoresMouseEvents = !panel.contains(NSEvent.mouseLocation)
    }
  }

  /// Converte o retângulo que o Flutter mede — origem no canto superior
  /// esquerdo — para o do AppKit, com a origem embaixo.
  private static func rect(from arguments: [String: Any]?) -> NSRect? {
    guard let arguments = arguments,
          let x = arguments["x"] as? Double,
          let y = arguments["y"] as? Double,
          let width = arguments["width"] as? Double,
          let height = arguments["height"] as? Double,
          let contentHeight = overlayWindow?.contentView?.bounds.height
    else { return nil }

    return NSRect(x: x, y: contentHeight - y - height, width: width, height: height)
  }

  // MARK: - Avisos para o Dart

  static func report(paths: [String]) {
    guard !paths.isEmpty else { return }

    DispatchQueue.main.async {
      guard let channel = overlayChannel else {
        // O caminho que custou três voltas de depuração: sem canal, o arquivo
        // é aceito pelo AppKit e o aviso morre aqui, sem erro nenhum. Se isto
        // acontecer de novo, que apareça no Console.
        NSLog("[Nest] arquivo solto sem canal para avisar o Dart.")
        return
      }

      channel.invokeMethod("onDropped", arguments: ["paths": paths])
    }
  }

  /// Alguém chacoalhou um arquivo. Ver `NestDragMonitor`.
  ///
  /// Com o `NSLog` de guarda pelo mesmo motivo do [report(paths:)]: sem canal, o
  /// gesto morre aqui sem erro nenhum, e a falha deste módulo é sempre
  /// silenciosa.
  static func reportShake() {
    DispatchQueue.main.async {
      guard let channel = overlayChannel else {
        NSLog("[Nest] chacoalhar sem canal para avisar o Dart.")
        return
      }

      channel.invokeMethod("onShake", arguments: nil)
    }
  }

  /// Alguém parou com um arquivo no notch. Ver `NestDragMonitor`.
  static func reportNotch() {
    DispatchQueue.main.async {
      guard let channel = overlayChannel else {
        NSLog("[Nest] notch sem canal para avisar o Dart.")
        return
      }

      channel.invokeMethod("onNotch", arguments: nil)
    }
  }

  /// O arraste que chamou a prateleira pelo notch terminou — com o arquivo
  /// solto nela ou em qualquer outro lugar. Quem decide se ela fica é o Dart,
  /// que sabe se alguma coisa chegou.
  static func reportNotchDragEnded() {
    DispatchQueue.main.async {
      overlayChannel?.invokeMethod("onNotchDragEnded", arguments: nil)
    }
  }

  static func report(isOver: Bool) {
    DispatchQueue.main.async {
      overlayChannel?.invokeMethod("onDragOver", arguments: ["isOver": isOver])
    }
  }

  // MARK: - Miniaturas

  /// Pede a prévia ao QuickLook e devolve **cada degrau** que ele produzir.
  ///
  /// `generateRepresentations` (plural), e não `generateBestRepresentation`: o
  /// plural chama o bloco assim que tem o ícone do tipo, de novo com uma prévia
  /// grosseira e por último com a boa. É o que faz um PDF de duzentas páginas
  /// aparecer na hora em vez de deixar um buraco na lista por dois segundos.
  private static func requestThumbnail(path: String, size: Double) {
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    let request = QLThumbnailGenerator.Request(
      fileAt: URL(fileURLWithPath: path),
      size: CGSize(width: size, height: size),
      scale: scale,
      representationTypes: .all
    )

    QLThumbnailGenerator.shared.generateRepresentations(for: request) { representation, _, _ in
      guard let representation = representation,
            let data = png(from: representation.cgImage)
      else { return }

      DispatchQueue.main.async {
        overlayChannel?.invokeMethod(
          "onThumbnail",
          arguments: ["path": path, "bytes": FlutterStandardTypedData(bytes: data)]
        )
      }
    }
  }

  private static func png(from image: CGImage) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  }

  // MARK: - Pasta e Lixo

  /// Abre o seletor de pasta do sistema.
  ///
  /// O `activate` antes é obrigatório: o Evergreen é um agente de barra de
  /// menus, e um painel modal de um aplicativo que não está na frente nasce
  /// atrás da janela em que a pessoa estava.
  private static func chooseFolder() -> String? {
    NSApp.activate(ignoringOtherApps: true)

    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Escolher"
    panel.message = "Escolha uma pasta de destino para a prateleira."

    guard panel.runModal() == .OK else { return nil }

    return panel.url?.path
  }

  private static func moveToTrash(path: String?, result: @escaping FlutterResult) {
    guard let path = path else {
      result(false)
      return
    }

    NSWorkspace.shared.recycle([URL(fileURLWithPath: path)]) { _, error in
      DispatchQueue.main.async { result(error == nil) }
    }
  }
}

/// O arraste, do lado do AppKit.
///
/// Achar quem recebe um arquivo solto custou duas tentativas erradas, e as duas
/// falhavam **em silêncio** — o arquivo caía, nada acontecia, nenhum erro:
///
/// 1. Uma `NSView` transparente por cima do Flutter, com `hitTest` devolvendo
///    `nil` para não roubar os cliques do painel. O AppKit procura o destino de
///    um arraste pelo mesmo `hitTest` do mouse: view invisível ao clique é
///    invisível ao arraste. E devolver a view engoliria os cliques do painel —
///    não há posição na hierarquia que resolva os dois.
/// 2. A própria janela, com os métodos do `NSDraggingDestination` escritos nela.
///    `NSWindow` não implementa esse protocolo: o `NSWindow.h` declara só o
///    `registerForDraggedTypes:`, e quem recebe as mensagens é o **delegate**
///    da janela.
///
/// Então é o delegate. A janela 0 já tem o do `window_manager` — que é quem
/// avisa o Flutter sobre foco e fechamento —, e por isso o
/// [NestWindowDropDelegate] se põe na frente dele e repassa todo o resto.
enum NestDrop {
  /// A janela 0 só aceita com o painel do Nest à vista, porque ela é
  /// compartilhada pelos sete módulos.
  static func entered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard accepts(sender), !paths(in: sender).isEmpty else { return [] }

    NestChannel.report(isOver: true)
    return .copy
  }

  static func exited() {
    NestChannel.report(isOver: false)
  }

  static func perform(_ sender: NSDraggingInfo) -> Bool {
    NestChannel.report(isOver: false)

    let paths = self.paths(in: sender)
    guard accepts(sender), !paths.isEmpty else { return false }

    NestChannel.report(paths: paths)
    return true
  }

  private static func accepts(_ sender: NSDraggingInfo) -> Bool {
    // Um arraste que saiu da própria prateleira não volta para ela: soltar em
    // cima do painel é o gesto de desistir, e os arquivos ficam onde estão.
    // Recusar aqui é também o que impede o arquivo de atravessar o painel e
    // cair na janela que estava atrás dele.
    if sender.draggingSource is NestDragSource { return false }

    return NestChannel.isDropEnabled
  }

  private static func paths(in sender: NSDraggingInfo) -> [String] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    let urls = sender.draggingPasteboard.readObjects(
      forClasses: [NSURL.self],
      options: options
    ) as? [URL]

    return urls?.map(\.path) ?? []
  }
}

/// O delegate que recebe o arraste sem tirar o lugar de quem já estava ali.
///
/// A janela 0 tem um delegate do `window_manager`, e é ele que faz o Flutter
/// saber que a janela ganhou ou perdeu o foco — sem isso o painel não fecha, não
/// anima a entrada e não recupera o teclado. Este objeto entra na frente dele e
/// devolve tudo o que não for arraste, pelo encaminhamento do ObjC.
class NestWindowDropDelegate: NSObject, NSWindowDelegate, NSDraggingDestination {
  /// O delegate anterior. Fraco: quem o retém é quem o criou.
  weak var next: NSObject?

  init(next: NSObject?) {
    self.next = next
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    NestDrop.entered(sender)
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    NestDrop.exited()
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    NestDrop.perform(sender)
  }

  // O resto do protocolo de janela continua sendo do delegate anterior. As duas
  // metades são necessárias: `responds(to:)` para o AppKit perguntar antes de
  // enviar, e `forwardingTarget` para o envio em si.
  override func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || (next?.responds(to: selector) ?? false)
  }

  override func forwardingTarget(for selector: Selector!) -> Any? {
    next?.responds(to: selector) == true ? next : nil
  }
}

/// A origem de um arraste que sai da prateleira.
///
/// Declara uma operação só, e não `[.copy, .move]`: com as duas, quem decide
/// passa a ser a modificadora do sistema, e o rótulo em cima da lista
/// ("COPIAR PARA") deixaria de valer para metade dos caminhos do módulo.
///
/// A operação é **sempre `.copy`**, nos dois modos. Copiar é um `file URL` que
/// o destino copia; mover é uma promessa que o destino aceita como cópia e nós
/// cumprimos movendo (ver `NestChannel.beginDrag`). É também o que o `⌥` do
/// sistema pede, então segurá-lo nunca mais faz o arraste nascer proibido.
///
/// Declarar uma só não bastava, e é daí que vinha o arraste que nascia
/// proibido. Ver [ignoreModifierKeys(for:)].
class NestDragSource: NSObject, NSDraggingSource {
  private let move: Bool

  init(move: Bool) {
    self.move = move
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  /// A máscara declarada acima não é a última palavra: antes de consultar
  /// destino nenhum, o AppKit a cruza com o que a modificadora segurada pede —
  /// `⌥` pede `.copy`, `⌘` pede `.move`. Com a máscara sempre em `.copy`, o
  /// `⌘` segurado a esvaziaria e o arraste nasceria proibido; ignorar as
  /// modificadoras é o que mantém a decisão no painel, tomada antes de esta
  /// sessão começar.
  ///
  /// Isto vale só do nosso lado. O destino lê as modificadoras por conta
  /// própria, e foi por isso que mover deixou de ser `.move` declarado e virou
  /// promessa — ver `NestChannel.beginDrag`.
  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }

  func draggingSession(
    _ session: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation: NSDragOperation
  ) {
    NestChannel.dragOutEnded(operation, promised: move)
  }
}

/// Cumpre a promessa de um arraste que move: o destino diz onde quer o arquivo,
/// e ele é **movido** para lá.
///
/// `FileManager.moveItem` atravessa volumes sozinho (copia e apaga a origem),
/// que é o caso que o `rename` do Dart precisa tratar à mão. Em colisão, o nome
/// livre segue a regra do Finder — e do resto do Nest: `contrato 2.pdf`.
class NestPromiseMover: NSObject, NSFilePromiseProviderDelegate {
  /// Fora da thread principal: mover entre volumes é copiar, e um vídeo grande
  /// congelaria o painel inteiro.
  private let queue: OperationQueue = {
    let queue = OperationQueue()
    queue.qualityOfService = .userInitiated
    return queue
  }()

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider,
    fileNameForType fileType: String
  ) -> String {
    URL(fileURLWithPath: filePromiseProvider.userInfo as? String ?? "").lastPathComponent
  }

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider,
    writePromiseTo url: URL,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard let path = filePromiseProvider.userInfo as? String else {
      completionHandler(CocoaError(.fileNoSuchFile))
      return
    }

    do {
      try FileManager.default.moveItem(
        at: URL(fileURLWithPath: path),
        to: Self.freeURL(for: url)
      )
      completionHandler(nil)
    } catch {
      NSLog("[Nest] não deu para mover \(path): \(error.localizedDescription)")
      completionHandler(error)
    }
  }

  func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
    queue
  }

  private static func freeURL(for url: URL) -> URL {
    let manager = FileManager.default
    guard manager.fileExists(atPath: url.path) else { return url }

    let folder = url.deletingLastPathComponent()
    let ext = url.pathExtension
    let stem = url.deletingPathExtension().lastPathComponent

    for index in 2..<1000 {
      let name = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
      let candidate = folder.appendingPathComponent(name)
      if !manager.fileExists(atPath: candidate.path) { return candidate }
    }

    return url
  }
}

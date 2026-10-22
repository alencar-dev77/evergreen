import Cocoa
import FlutterMacOS
import Sparkle

/// A atualização do Evergreen, pelo Sparkle.
///
/// Nativo porque o Sparkle é Swift/AppKit, e entra pelo SPM direto no `Runner`
/// (como o FluidAudio) — o `auto_updater` do pub.dev só traz `.podspec`, e
/// aceitar o CocoaPods de volta por ele custaria mais que este arquivo.
///
/// **Um atualizador por processo**, e não um por engine como o player do Echo:
/// ele agenda a procura diária e precisa existir com todas as janelas
/// fechadas. Nasce com a janela 0 ([start]); o canal existe nos dois engines,
/// porque quem mostra a tela de atualização é o Hub, mas os dois falam com a
/// mesma instância. Avisar, só a janela 0 é avisada (`onState`) — é ela que
/// põe a atualização no menu da barra, e é o único engine que nunca morre. O
/// Hub pergunta (`state`) enquanto a tela dele está aberta.
///
/// **A interface é do Evergreen, não do Sparkle** ([UpdateDriver]). A janela
/// padrão dele, num app de barra de menus, traria o app para a frente no meio
/// do que a pessoa estiver fazendo. Aqui o Sparkle procura, baixa e instala; a
/// versão nova vira um item no menu da barra e uma bolinha no Hub, e a tela
/// com as novidades e o botão de atualizar é desenhada em Flutter.
///
/// Onde mora a preferência: no próprio Sparkle
/// (`automaticallyChecksForUpdates`, nos `UserDefaults` do app). Uma cópia no
/// `AppSettings` seria uma segunda fonte para a pergunta que decide se algo sai
/// do app. Desligada, o Sparkle não agenda nada e nenhuma requisição sai.
///
/// **Build de desenvolvimento não atualiza** (`#if DEBUG`): o atualizador nem
/// começa, e a tela diz que esta cópia não se atualiza. Uma build do
/// `flutter run` consultando o feed acharia sempre uma versão "mais nova".
enum UpdaterChannel {
  static let channelName = "updater"

  /// A chave, no domínio do `shared_preferences`, que pede ao app que acabou de
  /// ser instalado para abrir o Hub — e com ele a abertura animada da build
  /// nova. Quem a lê e apaga é o `EvergreenBootstrap`.
  static let openHubAfterUpdateKey = "flutter.app.open_hub_after_update"

  private static let driver = UpdateDriver()

  /// O atualizador do Sparkle, criado na primeira vez que alguém pede.
  ///
  /// `nil` numa build de desenvolvimento, ou se o Sparkle não conseguiu
  /// começar (um `Info.plist` sem feed, por exemplo).
  private static let updater: SPUUpdater? = {
    #if DEBUG
      return nil
    #else
      let updater = SPUUpdater(
        hostBundle: Bundle.main,
        applicationBundle: Bundle.main,
        userDriver: driver,
        delegate: nil
      )
      do {
        try updater.start()
        return updater
      } catch {
        NSLog("Evergreen: o atualizador não começou: %@", error.localizedDescription)
        return nil
      }
    #endif
  }()

  /// O canal da janela 0, a única avisada quando algo muda.
  private static var overlayChannel: FlutterMethodChannel?

  /// Liga o atualizador junto com o app, para a procura agendada rodar mesmo
  /// que o Hub nunca seja aberto.
  static func start() {
    _ = updater
  }

  static func register(with messenger: FlutterBinaryMessenger, isOverlay: Bool) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    if isOverlay { overlayChannel = channel }

    channel.setMethodCallHandler { call, result in
      guard let updater = updater else {
        result(["available": false])
        return
      }

      switch call.method {
      case "state":
        result(state(of: updater))

      case "setAutomaticChecks":
        updater.automaticallyChecksForUpdates = call.arguments as? Bool ?? true
        result(state(of: updater))

      case "checkNow":
        // A fase muda antes: o Sparkle só avisa que começou a procurar depois
        // de conferir se há instalação pendente, e até lá a tela ficaria com
        // o botão apagado e sem dizer nada.
        if updater.canCheckForUpdates {
          driver.beginCheck()
          updater.checkForUpdates()
        }
        result(state(of: updater))

      case "install":
        driver.install()
        result(state(of: updater))

      case "proceedInstall":
        // A janela 0 terminou a limpeza do "Encerrar" — ver
        // `UpdateDriver.showReady`.
        driver.finishInstall()
        result(nil)

      case "waitForMeeting":
        driver.waitForMeeting()
        result(state(of: updater))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Avisa a janela 0 de que algo mudou. Sempre no fio principal: o Sparkle
  /// chama o driver nele, mas o canal exige.
  fileprivate static func notify() {
    guard let updater = updater, let channel = overlayChannel else { return }
    let snapshot = state(of: updater)
    DispatchQueue.main.async {
      channel.invokeMethod("onState", arguments: snapshot)
    }
  }

  /// Pede à janela 0 que se prepare para fechar. Devolve `false` sem janela 0
  /// para pedir — aí não há o que esperar.
  fileprivate static func askToPrepareInstall() -> Bool {
    guard let channel = overlayChannel else { return false }
    DispatchQueue.main.async {
      channel.invokeMethod("prepareToInstall", arguments: nil)
    }
    return true
  }

  private static func state(of updater: SPUUpdater) -> [String: Any] {
    var state: [String: Any] = [
      "available": true,
      "automaticChecks": updater.automaticallyChecksForUpdates,
      "canCheck": updater.canCheckForUpdates,
    ]
    if let last = updater.lastUpdateCheckDate {
      state["lastCheckMs"] = Int(last.timeIntervalSince1970 * 1000)
    }
    for (key, value) in driver.snapshot() { state[key] = value }
    return state
  }
}

/// O que o Sparkle mostraria numa janela, guardado para o Evergreen desenhar.
///
/// Cada método do `SPUUserDriver` é um passo do ciclo: procurando, achou,
/// baixando, preparando, instalando. O driver anota a fase e, quando o Sparkle
/// pede uma resposta ("instalo?"), guarda a resposta para quando a pessoa
/// apertar o botão — a tela é que decide, não uma janela solta.
final class UpdateDriver: NSObject, SPUUserDriver {
  private enum Phase: String {
    case idle, checking, available, downloading, extracting, waiting, installing
    case upToDate, error
  }

  private var phase = Phase.idle
  private var version: String?
  private var notesHtml: String?
  private var progress: Double?
  private var expectedLength: UInt64 = 0
  private var receivedLength: UInt64 = 0

  /// Quando a última procura terminou ("em dia" ou "não deu"). A tela só
  /// mostra esse resultado enquanto ele for o da procura mais recente.
  private var resultAt: Date?

  /// A resposta que o Sparkle espera para a versão achada. Guardada até o
  /// "Atualizar e reiniciar" — sem ela, a versão continua anunciada.
  ///
  /// "Agora não" não responde, de propósito: a versão continua anunciada (a
  /// bolinha fica). O preço é o Sparkle não procurar de novo nesta sessão —
  /// uma versão publicada depois aparece no próximo arranque.
  private var foundReply: ((SPUUserUpdateChoice) -> Void)?

  /// A resposta ao "pronto para instalar e reabrir", guardada enquanto a
  /// janela 0 faz a limpeza do "Encerrar". Ver [showReady].
  private var readyReply: ((SPUUserUpdateChoice) -> Void)?

  /// Se a janela 0 não responder (travada, ocupada), a instalação segue
  /// sozinha depois disto — melhor perder a limpeza que nunca atualizar.
  private var readyTimeout: DispatchWorkItem?
  private static let prepareTimeout: TimeInterval = 10

  func snapshot() -> [String: Any] {
    var snapshot: [String: Any] = ["phase": phase.rawValue]
    if let resultAt = resultAt {
      snapshot["resultMs"] = Int(resultAt.timeIntervalSince1970 * 1000)
    }
    if let version = version { snapshot["version"] = version }
    if let notesHtml = notesHtml { snapshot["notesHtml"] = notesHtml }
    if let progress = progress { snapshot["progress"] = progress }
    return snapshot
  }

  func beginCheck() {
    move(to: .checking)
  }

  /// A janela 0 avisou que há uma reunião do Echo em curso: a instalação
  /// espera, sem prazo, até ela terminar e a janela 0 mandar seguir.
  func waitForMeeting() {
    readyTimeout?.cancel()
    readyTimeout = nil
    move(to: .waiting)
  }

  /// Fecha, instala e reabre. A chave faz o app novo abrir o Hub, e com ele a
  /// abertura animada da build nova — gravada só aqui, a um passo de fechar,
  /// para uma instalação que falhe antes não abrir o Hub no arranque seguinte.
  func finishInstall() {
    readyTimeout?.cancel()
    readyTimeout = nil
    guard let reply = readyReply else { return }
    readyReply = nil
    UserDefaults.standard.set(true, forKey: UpdaterChannel.openHubAfterUpdateKey)
    move(to: .installing)
    reply(.install)
  }

  /// O "Atualizar e reiniciar" da tela.
  func install() {
    guard let reply = foundReply else { return }
    foundReply = nil
    move(to: .downloading, progress: 0)
    reply(.install)
  }

  private func move(to next: Phase, progress: Double? = nil) {
    // Um aviso por ponto percentual, e não por pedaço baixado: um `.dmg` de
    // dezenas de MB chega em milhares de pedaços, e cada aviso leva as notas
    // inteiras para a janela 0.
    let percent = progress.map { Int($0 * 100) }
    let unchanged = next == phase && percent == self.progress.map { Int($0 * 100) }
    phase = next
    self.progress = progress
    if !unchanged { UpdaterChannel.notify() }
  }

  // MARK: - SPUUserDriver

  func show(
    _ request: SPUUpdatePermissionRequest,
    reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    // Não deveria acontecer: o `Info.plist` já responde
    // (`SUEnableAutomaticChecks`). Se acontecer, a resposta é a mesma, e sem
    // perfil do sistema.
    reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    move(to: .checking)
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    // Um aviso só informativo não tem o que instalar — e o Evergreen nunca
    // publica um. Dispensado, para o Sparkle não ficar esperando.
    if appcastItem.isInformationOnlyUpdate {
      reply(.dismiss)
      move(to: .idle)
      return
    }

    // Uma procura nova que acha a mesma versão substitui a resposta antiga:
    // a anterior é dispensada, senão o Sparkle ficaria com duas pendentes.
    foundReply?(.dismiss)
    foundReply = reply
    version = appcastItem.displayVersionString
    notesHtml = appcastItem.itemDescription
    move(to: .available)
  }

  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
    // As notas vêm dentro do appcast (`itemDescription`), nunca por link.
  }

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

  func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
    resultAt = Date()
    move(to: .upToDate)
    acknowledgement()
  }

  func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
    // Só a fase: a mensagem do Sparkle pode trazer caminho de disco, e o
    // registro do app não leva isso (ver `AppLog.describe`).
    foundReply = nil
    readyReply = nil
    readyTimeout?.cancel()
    readyTimeout = nil
    resultAt = Date()
    move(to: .error)
    acknowledgement()
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    expectedLength = 0
    receivedLength = 0
    move(to: .downloading, progress: 0)
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    expectedLength = expectedContentLength
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    receivedLength += length
    guard expectedLength > 0 else { return }
    move(to: .downloading, progress: min(1, Double(receivedLength) / Double(expectedLength)))
  }

  func showDownloadDidStartExtractingUpdate() {
    move(to: .extracting, progress: 0)
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    move(to: .extracting, progress: progress)
  }

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    // A pessoa já disse sim na tela; perguntar de novo seria o diálogo que
    // este driver existe para não mostrar. Mas fechar agora seria fechar sem
    // o "Encerrar": a trava do Awake não viraria linha para o Track, e uma
    // reunião do Echo seria cortada. Então a janela 0 é avisada, faz a mesma
    // limpeza, e manda seguir (`proceedInstall`) — ou pede para esperar a
    // reunião (`waitForMeeting`).
    readyReply = reply
    move(to: .installing)
    guard UpdaterChannel.askToPrepareInstall() else {
      finishInstall()
      return
    }
    let timeout = DispatchWorkItem { [weak self] in self?.finishInstall() }
    readyTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.prepareTimeout, execute: timeout)
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    move(to: .installing)
  }

  func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
    acknowledgement()
  }

  func showUpdateInFocus() {
    UpdaterChannel.notify()
  }

  func dismissUpdateInstallation() {
    // Fim de um ciclo: o resultado de uma procura ("está em dia", "não deu")
    // fica para a tela mostrar; uma versão achada e ainda não respondida
    // continua anunciada.
    if foundReply == nil, phase != .upToDate, phase != .error {
      version = nil
      notesHtml = nil
      move(to: .idle)
    }
  }
}

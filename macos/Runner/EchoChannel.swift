import AVFoundation
import Accelerate
import CoreGraphics
import FlutterMacOS
import Foundation
import FoundationModels
import ScreenCaptureKit
import Security
import Speech

/// Canal nativo do Echo: grava a reunião, transcreve e resume — tudo local.
///
/// Nada aqui tem equivalente em Flutter puro, e por três motivos diferentes:
/// capturar o áudio que sai do computador é `ScreenCaptureKit`, transcrever é o
/// modelo de fala do sistema (`SpeechAnalyzer`, macOS 26) e resumir é o modelo
/// do Apple Intelligence (`FoundationModels`). O Dart manda começar, parar e
/// pedir; a decisão de *como* é toda deste lado.
///
/// O porquê de cada escolha está em `docs/Ideis projeto/echo-transcricao.md`.
enum EchoChannel {
  private static let channelName = "echo"

  /// Criado só quando o sistema aguenta.
  ///
  /// O Echo inteiro exige macOS 26 — é de lá que vêm o `SpeechAnalyzer` e o
  /// modelo do Apple Intelligence. Guardar o gravador como `Any?` é o preço de
  /// o resto do Evergreen continuar rodando no macOS 12.
  private static var storedRecorder: Any?

  @available(macOS 26.0, *)
  private static var recorder: EchoRecorder {
    if let existing = storedRecorder as? EchoRecorder { return existing }
    let created = EchoRecorder()
    storedRecorder = created
    return created
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any] ?? [:]

      // Abaixo do macOS 26 não existe nem transcritor nem modelo de resumo. A
      // UI pergunta `capabilities` antes de oferecer qualquer coisa; as demais
      // chamadas respondem erro em vez de fingir que funcionaram.
      guard #available(macOS 26.0, *) else {
        if call.method == "capabilities" {
          result([
            "microphone": "denied",
            "screenRecording": "denied",
            "summaries": "unsupportedOS",
          ])
        } else {
          result(FlutterError(
            code: "unsupported_os",
            message: "O Echo precisa do macOS 26 ou superior.",
            details: nil))
        }
        return
      }

      switch call.method {
      case "capabilities":
        result(capabilities())

      case "requestMicrophone":
        requestMicrophone(result: result)

      case "requestScreenRecording":
        requestScreenRecording(result: result)

      case "startRecording":
        // O aviso do ao vivo volta por este mesmo `channel`, que é o do engine
        // que pediu a gravação — a janela flutuante. Os dois engines registram
        // o seu, e cada um só recebe o que ele mesmo começou.
        let live = arguments["liveTranscription"] as? Bool ?? false
        let locale = arguments["locale"] as? String ?? "pt-BR"
        let vocabulary = arguments["vocabulary"] as? [String] ?? []
        Task {
          await recorder.start(
            liveTranscription: live, locale: locale, vocabulary: vocabulary,
            channel: channel, result: result)
        }

      // Numa `Task`, como as demais: o gravador é um `actor`, e chamá-lo da
      // thread do canal é falar com o estado dele de fora do isolamento.
      case "pauseRecording":
        Task { await recorder.pause(result: result) }

      case "resumeRecording":
        Task { await recorder.resume(result: result) }

      case "stopRecording":
        Task { await recorder.stop(result: result) }

      case "cancelRecording":
        Task { await recorder.cancel(result: result) }

      case "transcribe":
        let micPath = arguments["micPath"] as? String
        let systemPath = arguments["systemPath"] as? String
        let locale = arguments["locale"] as? String ?? "pt-BR"
        let vocabulary = arguments["vocabulary"] as? [String] ?? []
        Task {
          await EchoTranscriber.transcribe(
            micPath: micPath, systemPath: systemPath, locale: locale,
            vocabulary: vocabulary, result: result)
        }

      case "summarize":
        let text = arguments["text"] as? String ?? ""
        let instructions = arguments["instructions"] as? String
        Task { await EchoSummarizer.summarize(text: text, instructions: instructions, result: result) }

      case "summaryContextSize":
        result(EchoSummarizer.contextSize)

      case "installLocale":
        let locale = arguments["locale"] as? String ?? "pt-BR"
        Task { await EchoTranscriber.installLocale(locale, result: result) }

      case "resolveLocales":
        let locales = arguments["locales"] as? [String] ?? []
        Task { result(await EchoSpeech.resolveLocales(locales)) }

      case "deleteAudio":
        let paths = arguments["paths"] as? [String] ?? []
        for path in paths { try? FileManager.default.removeItem(atPath: path) }
        result(nil)

      case "cleanOrphanAudio":
        cleanOrphanAudio()
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Em que build já pedimos a gravação de tela.
  ///
  /// O macOS não tem "ainda não perguntei" para essa permissão:
  /// `CGPreflightScreenCaptureAccess` responde `false` tanto para "nunca pedi"
  /// quanto para "o usuário negou", e `CGRequestScreenCaptureAccess` só abre o
  /// diálogo enquanto o sistema não tiver uma decisão registrada. Sem guardar
  /// isso, não há como saber se a saída é pedir ou mandar a pessoa para os
  /// Ajustes.
  ///
  /// Guardado **por build**, e não como um sim ou não para sempre: instalar uma
  /// versão nova troca o binário, e a Gravação de Tela é a permissão que o
  /// macOS reconfere quando o app deixa de ser o mesmo. Com o "já pedi" eterno
  /// que estava aqui, toda instalação levava a pessoa aos Ajustes — onde a
  /// chave do Evergreen aparece **ligada** — em vez de deixar o sistema
  /// perguntar de novo. Era esse o "buildei e o Echo parou de capturar".
  private static let screenAskedBuildKey = "evergreen.echo.screenRecordingAskedBuild"

  /// A chave anterior, que valia para sempre. Só existe para ser apagada.
  private static let legacyScreenAskedKey = "evergreen.echo.screenRecordingAsked"

  /// A identidade do código que está rodando: o `cdhash` da assinatura.
  ///
  /// Muda a cada build, e é exatamente o que o macOS compara para decidir que o
  /// app instalado não é mais aquele que recebeu a permissão. Vazia quando não
  /// dá para ler — e aí o "já pedi" volta a valer para sempre, que é o
  /// comportamento antigo, não um caminho pior.
  private static func codeIdentity() -> String {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return "" }

    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
      let staticCode
    else { return "" }

    var information: CFDictionary?
    // Flags vazias: o `cdhash` (`kSecCodeInfoUnique`) já vem no conjunto básico
    // de informações, sem precisar pedir certificado nem entitlements.
    guard
      SecCodeCopySigningInformation(staticCode, [], &information) == errSecSuccess,
      let dictionary = information as? [String: Any],
      let hash = dictionary[kSecCodeInfoUnique as String] as? Data
    else { return "" }

    return hash.map { String(format: "%02x", $0) }.joined()
  }

  /// Se esta build já pediu a gravação de tela.
  private static func hasAskedScreenRecording() -> Bool {
    UserDefaults.standard.string(forKey: screenAskedBuildKey) == codeIdentity()
  }

  private static func rememberAskedScreenRecording() {
    let defaults = UserDefaults.standard
    defaults.set(codeIdentity(), forKey: screenAskedBuildKey)
    defaults.removeObject(forKey: legacyScreenAskedKey)
  }

  /// O que esta máquina consegue fazer, para a UI não oferecer o impossível.
  @available(macOS 26.0, *)
  private static func capabilities() -> [String: Any] {
    let microphone: String
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: microphone = "granted"
    case .notDetermined: microphone = "notDetermined"
    default: microphone = "denied"
    }

    let screenGranted = CGPreflightScreenCaptureAccess()
    let screenRecording = screenGranted
      ? "granted"
      : (hasAskedScreenRecording() ? "denied" : "notDetermined")

    var summaries = "unavailable"
    switch SystemLanguageModel.default.availability {
    case .available:
      summaries = "available"
    case .unavailable(let reason):
      switch reason {
      case .deviceNotEligible: summaries = "deviceNotEligible"
      case .appleIntelligenceNotEnabled: summaries = "appleIntelligenceNotEnabled"
      case .modelNotReady: summaries = "modelNotReady"
      @unknown default: summaries = "unavailable"
      }
    }

    return [
      "microphone": microphone,
      "screenRecording": screenRecording,
      "summaries": summaries,
    ]
  }

  /// Pede o microfone — ou leva aos Ajustes quando não há mais o que pedir.
  ///
  /// `requestAccess` só abre diálogo enquanto o estado é "ainda não perguntei".
  /// Depois de um "não", ele retorna `false` na hora, calado. Era daí que vinha
  /// o botão que não fazia nada: o app pedia, o sistema respondia
  /// instantaneamente que não, e não havia mais nada na tela.
  @available(macOS 26.0, *)
  private static func requestMicrophone(result: @escaping FlutterResult) {
    guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
      openSettings(pane: "Privacy_Microphone")
      result(capabilities())
      return
    }

    AVCaptureDevice.requestAccess(for: .audio) { _ in
      // Fora da thread de UI o diálogo do sistema não aparece.
      DispatchQueue.main.async { result(capabilities()) }
    }
  }

  /// Pede a gravação de tela — a permissão que dá acesso ao áudio da reunião.
  ///
  /// Duas diferenças cruéis em relação ao microfone, e as duas parecem bug:
  ///
  /// 1. `CGRequestScreenCaptureAccess` só abre o diálogo enquanto o sistema não
  ///    tem uma decisão registrada para esta build. Depois disso ele responde
  ///    `false` sem mostrar nada — por isso guardamos que já pedimos (ver
  ///    [screenAskedBuildKey]) e mandamos a pessoa para os Ajustes.
  /// 2. Conceder **não vale imediatamente**: o macOS só entrega a permissão a
  ///    um processo que subiu depois dela. Enquanto o app não for reaberto, a
  ///    resposta continua sendo `false` mesmo com a chave ligada nos Ajustes —
  ///    e é por isso que a interface avisa para reabrir o Evergreen em vez de
  ///    ficar dizendo que falta permissão.
  @available(macOS 26.0, *)
  private static func requestScreenRecording(result: @escaping FlutterResult) {
    if CGPreflightScreenCaptureAccess() {
      result(capabilities())
      return
    }

    if hasAskedScreenRecording() {
      openSettings(pane: "Privacy_ScreenCapture")
      result(capabilities())
      return
    }

    rememberAskedScreenRecording()
    CGRequestScreenCaptureAccess()
    result(capabilities())
  }

  /// Abre a página exata dos Ajustes, não a lista inteira de privacidade.
  private static func openSettings(pane: String) {
    guard let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    else { return }

    NSWorkspace.shared.open(url)
  }

  /// Varre áudio deixado para trás por uma queda no meio de uma reunião.
  ///
  /// O áudio é andaime: existe entre gravar e transcrever, e some depois. Se o
  /// app morrer no meio, ninguém apaga — daí esta varredura no início.
  @available(macOS 26.0, *)
  private static func cleanOrphanAudio() {
    let directory = EchoRecorder.audioDirectory
    guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                   includingPropertiesForKeys: nil)
    else { return }

    for file in files {
      try? FileManager.default.removeItem(at: file)
    }
  }
}

// MARK: - Gravação

/// Grava a reunião em duas faixas separadas.
///
/// A separação é a razão de o Echo saber quem falou sem nenhum modelo de
/// diarização: o microfone é você e só você; o áudio do sistema é todo mundo
/// menos você. Uma única `SCStream` entrega as duas — `captureMicrophone` (a
/// partir do macOS 15) e o áudio do sistema saem como saídas distintas do mesmo
/// fluxo, com uma permissão só e sem driver virtual.
///
/// `excludesCurrentProcessAudio` impede o Evergreen de gravar a si mesmo.
@available(macOS 26.0, *)
actor EchoRecorder {
  /// Onde o áudio mora enquanto existe.
  ///
  /// Em `Caches`, não junto do banco: é arquivo temporário, e o próprio macOS
  /// sabe limpar o que ficar para trás.
  nonisolated static var audioDirectory: URL {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("com.alencardev.evergreen/echo", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }

  private var stream: SCStream?
  private var output: EchoStreamOutput?
  private var startedAt: Date?

  /// Desde quando está pausada, e quanto já ficou pausada antes disso.
  private var pausedAt: Date?
  private var pausedTotal: TimeInterval = 0

  private var micURL: URL?
  private var systemURL: URL?

  /// Quem escuta a `SCStream` parar sozinha.
  ///
  /// A stream nascia com `delegate: nil`, e um `didStopWithError` no meio da
  /// reunião não chegava a lugar nenhum: a gravação virava silêncio e só se
  /// descobria na transcrição vazia, sem nada que dissesse o que aconteceu. O
  /// erro fica guardado no próprio delegate — ele é chamado de fora do ator, e
  /// escrever daqui num campo do gravador seria escrever no estado do ator a
  /// partir de outra thread.
  private var delegate: EchoStreamDelegate?

  /// A captura do microfone, feita por fora do `ScreenCaptureKit`.
  ///
  /// O `SCStreamConfiguration.captureMicrophone` era o caminho óbvio, e é o que
  /// estava aqui — mas nesta máquina ele **inicia e não entrega**: o `replayd`
  /// registra `micCaptureSessionCount=1`, o TCC responde Allow, a
  /// `AVCaptureSession` interna dele roda, e nenhum bloco de tipo `.microphone`
  /// chega ao processo. Reproduzido em duas builds e duas configurações
  /// diferentes, com a faixa do sistema gravando normalmente ao lado.
  ///
  /// O `AVAudioEngine` é o caminho de sempre para gravar entrada no macOS —
  /// anterior ao `captureMicrophone`, independente do `ScreenCaptureKit` e sem
  /// piso de sistema. As duas faixas continuam separadas, que é o que sustenta
  /// saber quem falou; muda só quem entrega uma delas.
  private let micEngine = AVAudioEngine()
  private var micError: String?

  /// Liga o microfone e entrega cada bloco ao [output].
  ///
  /// Devolve `nil` quando deu certo, ou o motivo de não ter dado — que sobe até
  /// a tela em vez de virar uma faixa muda sem explicação.
  ///
  /// O tap usa o formato do próprio dispositivo (`format: nil`): o microfone
  /// interno de um MacBook é um arranjo de três canais, e pedir um formato que
  /// ele não tem é justamente o tipo de desencontro que faz a entrada não
  /// entregar nada. A conversão para o formato do transcritor acontece depois,
  /// igual para as duas faixas.
  ///
  /// **O processamento de voz é ligado antes de tudo** — ver
  /// [enableVoiceProcessing].
  private static func startMicrophone(
    engine: AVAudioEngine,
    output: EchoStreamOutput
  ) -> String? {
    let input = engine.inputNode
    let processed = enableVoiceProcessing(on: input)

    // Depois de ligar o processamento, e nunca antes: ele troca o formato da
    // entrada (o arranjo de cápsulas vira um canal só). Ler o formato antes
    // daria o número de canais que a entrada tinha e não tem mais.
    let format = input.inputFormat(forBus: 0)

    guard format.sampleRate > 0, format.channelCount > 0 else {
      return "Nenhum dispositivo de entrada de áudio disponível."
    }

    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 4_096, format: nil) { buffer, _ in
      output.appendMicrophone(buffer)
    }

    engine.prepare()

    do {
      try engine.start()
      return nil
    } catch {
      // O motor pode recusar justamente por causa do processamento de voz: ele
      // exige um par de entrada e saída que nem toda configuração de áudio
      // oferece. Gravar sem ele é pior, mas é muito melhor que não gravar.
      guard processed else {
        input.removeTap(onBus: 0)
        return error.localizedDescription
      }

      input.removeTap(onBus: 0)
      try? input.setVoiceProcessingEnabled(false)
      input.installTap(onBus: 0, bufferSize: 4_096, format: nil) { buffer, _ in
        output.appendMicrophone(buffer)
      }

      do {
        try engine.start()
        return nil
      } catch {
        input.removeTap(onBus: 0)
        return error.localizedDescription
      }
    }
  }

  /// Liga o processamento de voz do sistema na entrada.
  ///
  /// É a diferença entre o que o Echo gravava e o que o Notas grava. O
  /// microfone interno é um arranjo de três cápsulas separadas por centímetros,
  /// e a mesma voz chega em cada uma com um atraso diferente. Somar os três
  /// canais na mão — que é o que [EchoStreamOutput.mono] faz, e o que salvou a
  /// faixa de sair muda — soma sinais defasados: dá filtro pente, com vales
  /// bem no meio da banda da fala. O modelo de fala não erra "um pouco" com
  /// fonema borrado; ele troca a palavra inteira pela vizinha mais provável.
  ///
  /// O processamento de voz resolve isso de outro jeito: usa o atraso entre as
  /// cápsulas **a favor** (formação de feixe na direção de quem fala), e ainda
  /// entrega três coisas de brinde —
  ///
  /// - **cancelamento de eco**: o que sai pela caixa de som não volta pela sua
  ///   faixa. É o mesmo trabalho do `CrossTalkFilter`, feito na origem em vez
  ///   de depois, no texto;
  /// - **redução de ruído**: ventilador, teclado, rua;
  /// - **ganho automático**: a fala ocupa a escala do arquivo, em vez de viver
  ///   nos primeiros bits e chegar granulada no modelo.
  ///
  /// Com ele ligado a entrada passa a ser mono, e a mixagem à mão vira um
  /// caminho que não é mais percorrido — de propósito.
  ///
  /// Devolve se conseguiu, porque quem chama precisa saber se ainda tem essa
  /// carta para jogar fora quando o motor não subir.
  @discardableResult
  private static func enableVoiceProcessing(on input: AVAudioInputNode) -> Bool {
    do {
      try input.setVoiceProcessingEnabled(true)

      // O processamento de voz vem com um quarto brinde que ninguém pediu: o
      // sistema abaixa o áudio de todos os outros apps. É a regra de uma
      // chamada — se você fala ao telefone, a música cede o lugar — e o macOS
      // não tem como saber que aqui a reunião está sendo *gravada* e não
      // conversada. Sem este ajuste, mandar transcrever com um vídeo tocando
      // deixava a saída quase muda, e o controle de volume no mesmo lugar: a
      // atenuação acontece depois do controle, no mixer do sistema.
      //
      // `.min` é o piso que a API oferece — desligar de vez não existe. E a
      // ducking avançada fica de fora de propósito: ela abaixaria os outros só
      // quando detectasse alguém falando, o que troca um volume baixo e
      // constante por um volume que oscila junto com a conversa.
      input.voiceProcessingOtherAudioDuckingConfiguration = .init(
        enableAdvancedDucking: false,
        duckingLevel: .min
      )

      return true
    } catch {
      // Sem ele a gravação continua — só volta a ser a média das cápsulas.
      return false
    }
  }

  private func stopMicrophone() {
    let input = micEngine.inputNode

    if micEngine.isRunning {
      // Tirar o tap antes de parar: com ele instalado, um último bloco pode
      // chegar depois de os arquivos terem sido fechados.
      input.removeTap(onBus: 0)
      micEngine.stop()
    }

    // Desligar o processamento de voz, e não só parar o motor.
    //
    // Ele é propriedade do nó de entrada, não do motor rodando: parado, o
    // `micEngine` continua vivo (é `let`, dura o que durar o gravador) e a
    // unidade de processamento continua montada nele — com a ducking dos
    // outros apps junto. O áudio do sistema só voltava ao normal quando o
    // processo inteiro morria, que é encerrar o aplicativo para parar de
    // gravar. Desligar aqui devolve a entrada ao estado comum e solta o mixer.
    //
    // Fora do `if` porque o motor pode ter falhado ao subir *depois* de o
    // processamento já estar ligado — o caso em que a ducking ficaria de pé
    // sem sequer haver gravação.
    try? input.setVoiceProcessingEnabled(false)
  }

  /// Confirma a Gravação de Tela — pedindo, se for o caso, antes de desistir.
  ///
  /// `CGPreflightScreenCaptureAccess` responder `false` não quer dizer
  /// "negado". Toda instalação nova troca o binário, e esta é a permissão que o
  /// macOS **reconfere** quando o app deixa de ser o mesmo: até a pessoa
  /// responder, o preflight diz que não há acesso. Recusar ali mesmo, como
  /// estava, era o que fazia o Echo parar de capturar depois de cada build — o
  /// diálogo do sistema nunca aparecia porque ninguém chegava a pedi-lo.
  ///
  /// Na main thread porque é ela que apresenta o diálogo; fora dela a chamada
  /// volta calada.
  private static func ensureScreenRecordingAccess() async -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }

    return await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        continuation.resume(returning: CGRequestScreenCaptureAccess())
      }
    }
  }

  func start(
    liveTranscription: Bool,
    locale: String,
    vocabulary: [String],
    channel: FlutterMethodChannel,
    result: @escaping FlutterResult
  ) async {
    guard stream == nil else {
      result(FlutterError(code: "already_recording", message: "Já existe uma gravação em andamento.", details: nil))
      return
    }

    guard await Self.ensureScreenRecordingAccess() else {
      result(FlutterError(
        code: "screen_recording_denied",
        message: "Sem permissão de Gravação de Tela não dá para capturar o áudio da reunião.",
        details: nil))
      return
    }

    // O idioma é conferido **antes** de gravar, e não na hora de transcrever.
    // Descobrir que o modelo daquele idioma não existe nesta máquina depois de
    // uma reunião de uma hora é tarde: o áudio já foi, e o que sobra é uma
    // transcrição de palavras erradas ou um erro sem volta.
    guard let resolved = await EchoSpeech.resolveLocale(locale) else {
      result(FlutterError(
        code: "locale_unsupported",
        message: "O macOS não tem modelo de transcrição para \(locale). "
          + "Escolha outro idioma nas preferências do Echo.",
        details: nil))
      return
    }

    // O formato de gravação vem do transcritor que vai ler o arquivo — o mesmo
    // que a transcrição monta depois. É o que garante que gravamos exatamente
    // no formato em que ele quer ouvir.
    let recordingFormat = await EchoSpeech.audioFormat(
      for: EchoSpeech.transcriber(locale: resolved, live: false))

    do {
      let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
      guard let display = content.displays.first else {
        result(FlutterError(code: "no_display", message: "Nenhuma tela disponível para capturar áudio.", details: nil))
        return
      }

      let stamp = Int(Date().timeIntervalSince1970 * 1000)
      let micURL = Self.audioDirectory.appendingPathComponent("\(stamp)-mic.caf")
      let systemURL = Self.audioDirectory.appendingPathComponent("\(stamp)-sistema.caf")

      let configuration = SCStreamConfiguration()
      configuration.capturesAudio = true
      configuration.excludesCurrentProcessAudio = true
      // O microfone **não** vem por aqui — ver [startMicrophone]. Sem fixar taxa
      // nem número de canais: cada bloco é convertido para `recordingFormat` a
      // partir do formato que ele mesmo declara, então impor 48 kHz estéreo
      // aqui não economiza nada e só restringe o que o sistema pode entregar.
      // O vídeo não interessa, mas a SCStream exige um filtro de tela. Dois
      // pixels a um quadro por segundo é o mais perto de "nada" que dá para
      // pedir sem abrir mão do áudio.
      configuration.width = 2
      configuration.height = 2
      configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)

      let filter = SCContentFilter(display: display, excludingWindows: [])
      let delegate = EchoStreamDelegate()
      let stream = SCStream(filter: filter, configuration: configuration, delegate: delegate)

      let queue = DispatchQueue(label: "com.alencardev.evergreen.echo.audio")
      let output = EchoStreamOutput(
        micURL: micURL, systemURL: systemURL, queue: queue,
        recordingFormat: recordingFormat, channel: channel)
      if liveTranscription {
        await output.enableLiveTranscription(
          locale: resolved, vocabulary: vocabulary, channel: channel)
      }

      try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: queue)

      try await stream.startCapture()

      // Depois da captura de tela, e nunca no lugar dela: se o microfone não
      // subir, a reunião continua sendo gravada pelo lado do sistema. O motivo
      // fica guardado e sai no resultado do `stop`.
      micError = Self.startMicrophone(engine: micEngine, output: output)

      self.stream = stream
      self.output = output
      self.delegate = delegate
      self.micURL = micURL
      self.systemURL = systemURL
      self.startedAt = Date()

      result(["startedAt": Int(Date().timeIntervalSince1970 * 1000)])
    } catch {
      result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
    }
  }

  /// Suspende a gravação sem encerrá-la.
  ///
  /// A captura continua de pé e os blocos continuam chegando — o que muda é
  /// que eles são descartados. O trecho pausado não entra no arquivo e não
  /// entra na duração; a reunião retoma exatamente de onde parou.
  func pause(result: @escaping FlutterResult) {
    guard let output = output, pausedAt == nil else {
      result(FlutterError(
        code: "not_recording",
        message: "Nenhuma gravação em andamento para pausar.",
        details: nil))
      return
    }

    output.setPaused(true)
    pausedAt = Date()
    result(nil)
  }

  /// Volta a gravar de onde parou.
  func resume(result: @escaping FlutterResult) {
    guard let output = output, let since = pausedAt else {
      result(FlutterError(
        code: "not_paused",
        message: "A gravação não está pausada.",
        details: nil))
      return
    }

    pausedTotal += Date().timeIntervalSince(since)
    pausedAt = nil
    output.setPaused(false)
    result(nil)
  }

  func stop(result: @escaping FlutterResult) async {
    guard let stream = stream else {
      result(FlutterError(code: "not_recording", message: "Nenhuma gravação em andamento.", details: nil))
      return
    }

    try? await stream.stopCapture()
    stopMicrophone()
    await output?.finish()

    // A duração é o tempo **gravado**, e não o tempo de relógio: o que passou
    // pausado não está no arquivo, e uma reunião de 40 minutos com 10 de pausa
    // que se anunciasse como 50 mentiria em duas telas (a lista e o Track).
    let paused = pausedTotal + (pausedAt.map { Date().timeIntervalSince($0) } ?? 0)
    let duration = startedAt.map {
      max(0, Int((Date().timeIntervalSince($0) - paused) * 1000))
    } ?? 0

    // O caminho só sai daqui quando existe arquivo com áudio dentro. Antes ele
    // saía sempre, e o Dart mandava transcrever um arquivo que nunca chegou a
    // ser criado — a faixa muda passava por faixa vazia, e o resultado era uma
    // transcrição sem explicação.
    let micFrames = output?.micFrames ?? 0
    let systemFrames = output?.systemFrames ?? 0

    let payload: [String: Any] = [
      "micPath": (micFrames > 0 ? micURL?.path : nil) as Any,
      "systemPath": (systemFrames > 0 ? systemURL?.path : nil) as Any,
      "durationMs": duration,
      // O diagnóstico das duas faixas, para o Dart poder dizer *o que* faltou
      // em vez de mostrar uma reunião vazia.
      "micFrames": micFrames,
      "systemFrames": systemFrames,
      "micPeak": output?.micPeak ?? 0,
      "systemPeak": output?.systemPeak ?? 0,
      "streamError": delegate?.error as Any,
      "micError": micError as Any,
    ]

    reset()
    result(payload)
  }

  /// Para e joga o áudio fora — para quando a pessoa desiste no meio.
  func cancel(result: @escaping FlutterResult) async {
    if let stream = stream {
      try? await stream.stopCapture()
      stopMicrophone()
      await output?.finish()
    }

    for url in [micURL, systemURL].compactMap({ $0 }) {
      try? FileManager.default.removeItem(at: url)
    }

    reset()
    result(nil)
  }

  private func reset() {
    stream = nil
    output = nil
    delegate = nil
    micError = nil
    startedAt = nil
    pausedAt = nil
    pausedTotal = 0
    micURL = nil
    systemURL = nil
  }
}

/// Recebe os blocos de áudio da `SCStream` e escreve cada faixa no seu arquivo.
///
/// Os dois arquivos nascem no primeiro bloco recebido, e não na abertura: o
/// formato de cada faixa vem do próprio sistema (o microfone raramente casa com
/// a saída), então só dá para criar o arquivo quando o primeiro bloco revela em
/// que formato ele vai chegar.
@available(macOS 26.0, *)
final class EchoStreamOutput: NSObject, SCStreamOutput {
  private let micURL: URL
  private let systemURL: URL

  private var micFile: AVAudioFile?
  private var systemFile: AVAudioFile?

  private var micConverter: AVAudioConverter?
  private var systemConverter: AVAudioConverter?

  /// Quanto chegou em cada faixa, e com que amplitude.
  ///
  /// Existe porque as duas maneiras de a gravação sair muda são
  /// indistinguíveis no arquivo final: uma faixa que **não recebeu bloco
  /// nenhum** e uma que recebeu 26 minutos de zeros produzem a mesma
  /// transcrição vazia, e cada uma tem uma causa diferente — a primeira é a
  /// captura que não veio, a segunda é o som que não estava lá. Sem contar,
  /// a única saída era ler o `.caf` na mão depois.
  private(set) var micFrames: Int64 = 0
  private(set) var systemFrames: Int64 = 0
  private(set) var micPeak: Int = 0
  private(set) var systemPeak: Int = 0

  private var live: EchoLiveTranscriber?

  /// Formato em que o áudio é gravado — o que o transcritor pediu.
  ///
  /// Na prática 16 kHz, mono, e é o que os modelos de fala esperam. Quem
  /// responde é o próprio `SpeechAnalyzer`, em vez de uma constante escrita
  /// aqui: o formato preferido pode mudar entre versões do sistema, e entregar
  /// ao analisador um formato que ele não aceita não devolve erro — aborta o
  /// processo lá dentro.
  ///
  /// O que a `SCStream` entrega é bem outra coisa: 48 kHz, estéreo, ponto
  /// flutuante. Gravar cru custaria **23 MB por minuto em cada faixa**, ou seja
  /// 2,8 GB por hora de reunião somando as duas. Convertido, a mesma hora ocupa
  /// cerca de 230 MB.
  ///
  /// A conversão não perde nada que importe aqui: a fala humana vive abaixo dos
  /// 8 kHz, que é exatamente o teto que 16 kHz de amostragem preserva — e
  /// gravar acima disso não melhoraria a transcrição, porque o modelo reamostra
  /// para a taxa dele antes de ouvir. Estéreo então não faz falta nenhuma:
  /// cada faixa já é uma fonte só.
  let recordingFormat: AVAudioFormat

  init(
    micURL: URL,
    systemURL: URL,
    queue: DispatchQueue,
    recordingFormat: AVAudioFormat,
    channel: FlutterMethodChannel
  ) {
    self.micURL = micURL
    self.systemURL = systemURL
    self.queue = queue
    self.recordingFormat = recordingFormat
    self.channel = channel
  }

  /// Por onde o nível de cada faixa sobe para a interface.
  ///
  /// O mesmo canal do engine que pediu a gravação — a janela flutuante —, e o
  /// mesmo caminho do aviso da transcrição ao vivo. A diferença é que o nível
  /// vai sempre, com ou sem transcrição ligada: ele é o que diz que o Echo
  /// está ouvindo, e essa pergunta existe em toda gravação.
  private let channel: FlutterMethodChannel

  /// Liga e desliga a pausa **na fila do áudio**.
  ///
  /// A bandeira é lida a cada bloco, de dentro dessa fila; escrevê-la da main
  /// thread seria uma corrida silenciosa com a thread de áudio.
  func setPaused(_ value: Bool) {
    queue.async { [weak self] in self?.isPaused = value }
  }

  /// A gravação está pausada: os blocos continuam chegando e são **jogados
  /// fora**.
  ///
  /// Descartar é o que faz a pausa existir no arquivo: o trecho pausado
  /// simplesmente não entra, e o áudio volta a correr onde parou. A
  /// alternativa — parar e recomeçar a `SCStream` — trocaria de formato no
  /// meio, criaria um segundo arquivo por faixa e faria a transcrição
  /// remontar duas gravações como se fossem uma.
  private var isPaused = false

  /// O espectro de cada faixa — é ele que vira as barras do painel.
  private lazy var micSpectrum = EchoSpectrum(
    sampleRate: recordingFormat.sampleRate)
  private lazy var systemSpectrum = EchoSpectrum(
    sampleRate: recordingFormat.sampleRate)
  private var lastLevelAt = Date.distantPast

  /// De quanto em quanto tempo o nível sobe.
  ///
  /// Dez avisos por segundo: abaixo disso a barra anda aos saltos e deixa de
  /// parecer um medidor; acima, é canal gasto para desenhar o que o olho não
  /// separa.
  private static let levelInterval: TimeInterval = 0.1

  /// Manda o espectro das duas faixas para a interface, dez vezes por segundo.
  ///
  /// Vai **o que foi medido** — a energia por banda de frequência, de 0 a 1 — e
  /// nada mais. Quantas barras, com que cor e com que altura mínima é decisão
  /// de desenho, e mora do outro lado; aqui é o fato.
  private func reportLevels() {
    let now = Date()
    guard now.timeIntervalSince(lastLevelAt) >= Self.levelInterval else { return }
    lastLevelAt = now

    let mic = micSpectrum.bands()
    let system = systemSpectrum.bands()

    // O canal é de main thread; daqui é a fila serial do áudio.
    DispatchQueue.main.async { [channel] in
      channel.invokeMethod("onLevels", arguments: ["mic": mic, "system": system])
    }
  }

  /// A fila serial por onde passam as duas faixas.
  ///
  /// A do sistema chega por ela porque é a `sampleHandlerQueue` da `SCStream`;
  /// a do microfone vem de uma thread de áudio do `AVAudioEngine` e salta para
  /// cá. Uma fila só é o que mantém a ordem entre as duas — o transcritor ao
  /// vivo recebe os blocos na sequência em que eles são escritos, e blocos
  /// embaralhados lá dentro saem como frases embaralhadas.
  private let queue: DispatchQueue

  func enableLiveTranscription(
    locale: Locale,
    vocabulary: [String],
    channel: FlutterMethodChannel
  ) async {
    live = await EchoLiveTranscriber.make(
      locale: locale, vocabulary: vocabulary, channel: channel)
  }

  func finish() async {
    micFile = nil
    systemFile = nil
    micConverter = nil
    systemConverter = nil
    await live?.finish()
    live = nil
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .audio else { return }
    guard let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }

    write(buffer, isMicrophone: false)
  }

  /// Recebe um bloco do microfone, vindo da thread de áudio do `AVAudioEngine`.
  ///
  /// O buffer do tap é reaproveitado assim que o bloco retorna, então ele é
  /// **copiado** antes de sair dessa thread — despachar o original guardaria
  /// um ponteiro para memória que o motor já reescreveu.
  func appendMicrophone(_ buffer: AVAudioPCMBuffer) {
    guard let copy = Self.copy(buffer) else { return }
    queue.async { [weak self] in self?.write(copy, isMicrophone: true) }
  }

  private func write(_ rawBuffer: AVAudioPCMBuffer, isMicrophone: Bool) {
    // Pausado, o bloco não é escrito nem transcrito — e o medidor cai a zero
    // sozinho, porque nada alimenta a janela do próximo aviso.
    if isPaused {
      reportLevels()
      return
    }

    // A mixagem para um canal é nossa, não do `AVAudioConverter` — ver [mono].
    let buffer = Self.mono(rawBuffer)
    var converted: AVAudioPCMBuffer?

    do {
      if isMicrophone {
        if micFile == nil {
          micFile = try makeFile(at: micURL)
          micConverter = makeConverter(from: buffer.format)
        }
        converted = convert(buffer, with: micConverter)
        if let converted = converted {
          try micFile?.write(from: converted)
          micFrames += Int64(converted.frameLength)
          micPeak = max(micPeak, Self.peak(of: converted))
          micSpectrum.append(converted)
        }
      } else {
        if systemFile == nil {
          systemFile = try makeFile(at: systemURL)
          systemConverter = makeConverter(from: buffer.format)
        }
        converted = convert(buffer, with: systemConverter)
        if let converted = converted {
          try systemFile?.write(from: converted)
          systemFrames += Int64(converted.frameLength)
          systemPeak = max(systemPeak, Self.peak(of: converted))
          systemSpectrum.append(converted)
        }
      }
    } catch {
      // Um bloco perdido não justifica derrubar a gravação inteira: o resto da
      // reunião continua valendo mais que o trecho que falhou.
      return
    }

    // O ao vivo recebe o bloco **convertido**, nunca o cru: o analisador de
    // fala só aceita o formato que ele mesmo declara em
    // `bestAvailableAudioFormat` — que é exatamente o [recordingFormat]. Com o
    // formato da captura (48 kHz, estéreo, ponto flutuante) o Speech aborta o
    // processo lá dentro, e não por um erro que dê para capturar.
    //
    // Entregue daqui, e não de uma `Task`: as duas faixas chegam por uma fila
    // serial só, então chamar direto preserva a ordem dos blocos. Uma `Task`
    // por bloco desmancharia justamente isso — elas não têm ordem entre si, e
    // o áudio chegaria embaralhado no analisador.
    if let converted = converted {
      live?.append(converted)
    }

    reportLevels()
  }

  /// Cria o arquivo já no formato em que os blocos vão chegar.
  ///
  /// Sem o `commonFormat:`, o `AVAudioFile` mantém o `processingFormat` em
  /// ponto flutuante mesmo quando os `settings` pedem inteiro de 16 bits — e aí
  /// `write(from:)` com um bloco Int16 **não devolve erro**: aborta o processo
  /// dentro do AudioToolbox, onde nenhum `catch` alcança. Dizer o formato aqui
  /// é o que faz o arquivo aceitar o que o conversor produz.
  private func makeFile(at url: URL) throws -> AVAudioFile {
    try AVAudioFile(
      forWriting: url,
      settings: recordingFormat.settings,
      commonFormat: recordingFormat.commonFormat,
      interleaved: recordingFormat.isInterleaved)
  }

  /// O conversor da faixa, na melhor qualidade de reamostragem que existe.
  ///
  /// Não é capricho de áudio: descer de 48 kHz para 16 kHz é exatamente o tipo
  /// de conversão em que o filtro importa. O que estiver acima de 8 kHz e não
  /// for barrado antes de reamostrar **não some** — volta rebatido para dentro
  /// da banda da fala, como um chiado que não existia. O modelo então tenta
  /// interpretar como fonema uma coisa que é artefato de conta.
  ///
  /// O padrão do `AVAudioConverter` é um meio-termo pensado para tempo real. A
  /// conversão aqui é de um bloco de 4.096 quadros por vez, com o processador
  /// praticamente parado; pagar o filtro caro não custa nada que se perceba, e
  /// é sinal limpo entregue ao reconhecimento.
  private func makeConverter(from format: AVAudioFormat) -> AVAudioConverter? {
    let converter = AVAudioConverter(from: format, to: recordingFormat)
    converter?.sampleRateConverterQuality = AVAudioQuality.max.rawValue
    converter?.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
    return converter
  }

  /// Reamostra o bloco para [recordingFormat].
  ///
  /// Precisa da API de bloco do `AVAudioConverter`, e não do `convert(to:from:)`
  /// simples: mudar a taxa de amostragem muda a quantidade de quadros, e a
  /// versão simples só aceita conversões que preservam a contagem.
  func convert(
    _ buffer: AVAudioPCMBuffer,
    with converter: AVAudioConverter?
  ) -> AVAudioPCMBuffer? {
    guard let converter = converter else { return nil }

    let ratio = recordingFormat.sampleRate / buffer.format.sampleRate
    // A folga cobre o arredondamento do reamostrador, que pode devolver um
    // quadro a mais do que a razão sugere.
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1_024

    guard let output = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: capacity)
    else { return nil }

    var consumed = false
    var error: NSError?

    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      // O conversor pede blocos até se dar por satisfeito; temos só um por
      // chamada, então o segundo pedido responde "no momento não há mais".
      if consumed {
        inputStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      inputStatus.pointee = .haveData
      return buffer
    }

    guard status != .error, output.frameLength > 0 else { return nil }
    return output
  }

  /// A maior amplitude do bloco, em módulo — 0 é silêncio digital exato.
  ///
  /// Sempre sobre o buffer **já convertido** para [recordingFormat], e sempre
  /// na escala de um Int16 (0 a 32.767), qualquer que seja o formato em que o
  /// transcritor tenha pedido para gravar. A escala é fixa porque quem lê este
  /// número é a interface, do outro lado do canal, para dizer se a faixa saiu
  /// muda — e um limiar que mudasse de significado conforme o formato do dia
  /// seria pior que não ter limiar nenhum.
  static func peak(of buffer: AVAudioPCMBuffer) -> Int {
    if let channel = buffer.int16ChannelData?[0] {
      var peak: Int32 = 0
      for index in 0..<Int(buffer.frameLength) {
        peak = max(peak, Int32(channel[index].magnitude))
      }
      return Int(peak)
    }

    if let channel = buffer.floatChannelData?[0] {
      var peak: Float = 0
      for index in 0..<Int(buffer.frameLength) {
        peak = max(peak, abs(channel[index]))
      }
      return Int((min(peak, 1) * 32_767).rounded())
    }

    return 0
  }

  /// Soma os canais do bloco em um só, na mão.
  ///
  /// **É aqui que a faixa do microfone estava morrendo.** O microfone interno
  /// de um MacBook é um arranjo de três canais, e pedir ao `AVAudioConverter`
  /// que vá de três canais para mono devolve `status == .haveData`, o número
  /// certo de quadros e **silêncio digital exato**: ele não recusa a conversão,
  /// não devolve erro, só escreve zeros. Medido: um seno de meia escala nos
  /// três canais entra, e sai um bloco de pico 0. Com a mixagem feita aqui, o
  /// mesmo seno sai com pico 16384.
  ///
  /// Vale para as duas faixas. A do sistema é estéreo com layout padrão e o
  /// conversor dá conta dela, mas a conta é a mesma e uma saída multicanal
  /// cairia no mesmo buraco.
  ///
  /// Devolve o bloco original quando não há o que fazer — um canal só, ou um
  /// formato que não é ponto flutuante. Nesses casos quem converte segue sendo
  /// o `AVAudioConverter`, como sempre foi.
  static func mono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
    let format = buffer.format

    guard format.channelCount > 1,
      format.commonFormat == .pcmFormatFloat32,
      let monoFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: format.sampleRate,
        channels: 1,
        interleaved: false),
      let output = AVAudioPCMBuffer(
        pcmFormat: monoFormat, frameCapacity: buffer.frameLength),
      let destination = output.floatChannelData?[0],
      let source = buffer.floatChannelData
    else { return buffer }

    output.frameLength = buffer.frameLength

    let frames = Int(buffer.frameLength)
    let channels = Int(format.channelCount)

    // Média, e não o primeiro canal: num arranjo de microfones cada canal é uma
    // cápsula, e escolher uma jogaria fora o sinal das outras duas.
    for frame in 0..<frames {
      var sum: Float = 0

      if format.isInterleaved {
        for channel in 0..<channels { sum += source[0][frame * channels + channel] }
      } else {
        for channel in 0..<channels { sum += source[channel][frame] }
      }

      destination[frame] = sum / Float(channels)
    }

    return output
  }

  /// Uma cópia independente do bloco, com o mesmo formato e conteúdo.
  static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard buffer.frameLength > 0,
      let copy = AVAudioPCMBuffer(
        pcmFormat: buffer.format, frameCapacity: buffer.frameLength)
    else { return nil }

    copy.frameLength = buffer.frameLength

    let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
    let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)

    for index in 0..<min(source.count, destination.count) {
      guard let from = source[index].mData, let to = destination[index].mData
      else { continue }

      memcpy(to, from, Int(min(source[index].mDataByteSize, destination[index].mDataByteSize)))
    }

    return copy
  }

  /// Converte o bloco da `SCStream` no formato que o `AVAudioFile` e o
  /// analisador de fala entendem.
  ///
  /// **Copia** as amostras, e é aí que mora a diferença. A versão anterior usava
  /// `CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer` preenchendo a
  /// lista do próprio `AVAudioPCMBuffer` — só que essa função não copia nada:
  /// ela aponta a lista para a memória de um `CMBlockBuffer`, devolvido numa
  /// variável local. Ao sair daqui, a variável morria, o bloco era liberado, e o
  /// buffer que este método devolvia apontava para memória solta.
  ///
  /// O sintoma não era um estouro: era **silêncio**. Memória liberada lê como
  /// zeros, então os arquivos saíam com a duração certa, o tamanho certo e nada
  /// dentro — e a transcrição, corretamente, não encontrava fala nenhuma.
  ///
  /// `withAudioBufferList` segura o bloco vivo enquanto o fecho roda, que é a
  /// janela em que a cópia acontece.
  static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
    guard let description = sampleBuffer.formatDescription,
          var streamDescription = description.audioStreamBasicDescription,
          let format = AVAudioFormat(streamDescription: &streamDescription)
    else { return nil }

    let frames = AVAudioFrameCount(sampleBuffer.numSamples)
    guard frames > 0,
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
    else { return nil }

    buffer.frameLength = frames

    do {
      try sampleBuffer.withAudioBufferList { source, _ in
        let destination = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)

        // Um buffer por canal quando o áudio é não-intercalado; um só quando é
        // intercalado. Percorrer o menor dos dois cobre os dois casos sem
        // supor qual deles a `SCStream` escolheu.
        for index in 0..<min(source.count, destination.count) {
          guard let from = source[index].mData,
                let to = destination[index].mData
          else { continue }

          memcpy(to, from, Int(min(source[index].mDataByteSize, destination[index].mDataByteSize)))
        }
      }
    } catch {
      return nil
    }

    return buffer
  }
}

// MARK: - Transcrição

/// O que o Echo sabe sobre o modelo de fala do sistema, num lugar só.
///
/// Existe porque três lugares diferentes precisam montar o *mesmo*
/// transcritor — a gravação (para descobrir em que formato gravar), a
/// transcrição do arquivo e a transcrição ao vivo. Quando cada um montava o
/// seu, bastava um deles divergir para o áudio ser gravado num formato e lido
/// em outro.
@available(macOS 26.0, *)
enum EchoSpeech {
  /// As opções escritas uma a uma, em vez de um `Preset` pronto.
  ///
  /// Um `Preset` é uma constante opaca: não dá para ler o que ele liga. E há
  /// uma opção que **não** pode entrar aqui por acidente — `.fastResults`, que
  /// troca precisão por latência. Numa reunião já gravada não existe pressa
  /// nenhuma: o arquivo está no disco e ninguém está esperando a frase
  /// aparecer. Trocar exatidão por velocidade aí é perder de graça.
  ///
  /// - `.audioTimeRange` é o relógio de cada trecho, e é o que permite
  ///   intercalar as duas faixas numa conversa.
  /// - `.alternativeTranscriptions` só no arquivo: são as outras hipóteses do
  ///   modelo para o mesmo trecho.
  /// - Ao vivo **não** pede `.volatileResults`. O painel só mostra trecho já
  ///   fechado, então pedir as revisões parciais seria gastar processador
  ///   durante a chamada para jogar o resultado fora.
  static func transcriber(locale: Locale, live: Bool) -> SpeechTranscriber {
    SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: live ? [] : [.alternativeTranscriptions],
      attributeOptions: [.audioTimeRange])
  }

  /// O idioma que o modelo de fala **de fato** tem, ou `nil`.
  ///
  /// O seletor da interface oferece um punhado de idiomas, mas quem decide
  /// quais existem é o sistema — e a lista do `SpeechTranscriber` é menor que a
  /// do ditado antigo. `supportedLocale(equivalentTo:)` é o próprio framework
  /// respondendo "para este identificador eu uso aquele modelo", o que também
  /// resolve o caso de a pessoa pedir uma variante regional que o sistema
  /// atende com outra.
  ///
  /// Devolver `nil` é informação, não falha: é a diferença entre avisar "este
  /// idioma não existe aqui" e entregar uma transcrição que erra palavra sim,
  /// palavra não.
  static func resolveLocale(_ identifier: String) async -> Locale? {
    await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: identifier))
  }

  /// Para cada idioma pedido, qual o sistema usaria — ou nada.
  ///
  /// A tela de preferências pergunta isto, e não a lista de idiomas
  /// suportados, porque a lista responde a pergunta errada: um identificador
  /// pode não estar nela e ainda assim ser atendido por um modelo equivalente.
  /// Perguntar exatamente o que a gravação pergunta é o que impede a tela de
  /// acusar falta de um modelo que existe — ou de calar sobre um que não
  /// existe.
  static func resolveLocales(_ identifiers: [String]) async -> [String: String] {
    var resolved: [String: String] = [:]

    for identifier in identifiers {
      if let locale = await resolveLocale(identifier) {
        resolved[identifier] = locale.identifier(.bcp47)
      }
    }

    return resolved
  }

  /// As palavras que o reconhecimento deve esperar ouvir.
  ///
  /// Nome de pessoa, de empresa e jargão são justamente o que um modelo de fala
  /// erra: ele encaixa o som na palavra mais provável do idioma, e "Riverpod"
  /// não é provável em português nenhum. `contextualStrings` inclina a decisão
  /// para essa lista sem travar nada — o que não estiver nela continua sendo
  /// reconhecido normalmente.
  static func context(vocabulary: [String]) -> AnalysisContext {
    let context = AnalysisContext()

    let cleaned = vocabulary
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    if !cleaned.isEmpty {
      context.contextualStrings = [.general: cleaned]
    }

    return context
  }

  /// O formato de áudio que o próprio transcritor pede.
  ///
  /// Era uma constante escrita à mão (16 kHz, mono, Int16) a partir de uma
  /// medição feita uma vez. Perguntar é melhor por dois motivos: o formato
  /// preferido pode mudar entre versões do sistema, e gravar num formato que o
  /// analisador não aceita não devolve erro — ele aborta o processo lá dentro.
  ///
  /// A constante continua existindo como piso, para o caso de a pergunta voltar
  /// sem resposta. Gravar acima do que o modelo consome não melhora nada: ele
  /// reamostra para a taxa dele antes de ouvir, e a fala humana termina abaixo
  /// dos 8 kHz de qualquer jeito.
  static func audioFormat(for transcriber: SpeechTranscriber) async -> AVAudioFormat {
    await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) ?? fallbackFormat
  }

  static let fallbackFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16_000,
    channels: 1,
    interleaved: true)!
}

enum EchoSpeaker: String {
  case me
  case others
}

/// Transcreve as duas faixas depois que a reunião acaba.
///
/// Depois, e não durante, por decisão de produto: transcrever ao vivo custa
/// processador justamente enquanto a chamada de vídeo já está consumindo a
/// máquina. Gravar é barato; transcrever é que pesa. Quem tiver folga de sobra
/// liga a transcrição ao vivo nas preferências — e mesmo assim o arquivo
/// continua sendo gravado, então o resultado final não depende dela.
@available(macOS 26.0, *)
enum EchoTranscriber {
  static func transcribe(
    micPath: String?,
    systemPath: String?,
    locale: String,
    vocabulary: [String],
    result: @escaping FlutterResult
  ) async {
    guard let resolved = await EchoSpeech.resolveLocale(locale) else {
      result(FlutterError(
        code: "locale_unsupported",
        message: "O macOS não tem modelo de transcrição para \(locale). "
          + "Escolha outro idioma nas preferências do Echo — o áudio desta "
          + "reunião continua no disco até lá.",
        details: nil))
      return
    }

    do {
      var segments: [[String: Any]] = []

      if let micPath = micPath, FileManager.default.fileExists(atPath: micPath) {
        segments += try await transcribeFile(
          at: micPath, locale: resolved, vocabulary: vocabulary, speaker: .me)
      }
      if let systemPath = systemPath, FileManager.default.fileExists(atPath: systemPath) {
        segments += try await transcribeFile(
          at: systemPath, locale: resolved, vocabulary: vocabulary, speaker: .others)
      }

      // Intercalar por tempo é o que transforma duas transcrições paralelas em
      // uma conversa legível.
      segments.sort { ($0["startMs"] as? Int ?? 0) < ($1["startMs"] as? Int ?? 0) }

      result(segments)
    } catch {
      result(FlutterError(code: "transcription_failed", message: error.localizedDescription, details: nil))
    }
  }

  private static func transcribeFile(
    at path: String,
    locale: Locale,
    vocabulary: [String],
    speaker: EchoSpeaker
  ) async throws -> [[String: Any]] {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let transcriber = EchoSpeech.transcriber(locale: locale, live: false)

    let analyzer = SpeechAnalyzer(modules: [transcriber])

    // O vocabulário entra antes de a análise começar — depois de
    // `analyzeSequence` o analisador já decidiu o começo do arquivo. É a
    // versão sem `inputSequence` do inicializador, que não recebe o contexto
    // de fábrica; aqui ele é dito em separado.
    if !vocabulary.isEmpty {
      try await analyzer.setContext(EchoSpeech.context(vocabulary: vocabulary))
    }

    let collector = Task { () -> [[String: Any]] in
      var collected: [[String: Any]] = []
      for try await result in transcriber.results {
        let text = String(result.text.characters)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

        collected.append([
          "speaker": speaker.rawValue,
          "startMs": Int(result.range.start.seconds * 1000),
          "endMs": Int(result.range.end.seconds * 1000),
          "text": text,
        ])
      }
      return collected
    }

    _ = try await analyzer.analyzeSequence(from: file)
    try await analyzer.finalizeAndFinishThroughEndOfInput()

    return try await collector.value
  }

  /// Garante que o modelo daquele idioma está na máquina, baixando se faltar.
  ///
  /// Antes isto respondia `true` mesmo quando não tinha instalado nada: para um
  /// idioma que o sistema não reconhece, `assetInstallationRequest` devolve
  /// `nil` — não há o que baixar — e o `if` simplesmente não entrava. A tela
  /// comemorava, e o erro só aparecia depois, como palavra trocada no meio da
  /// reunião. Agora o idioma é conferido primeiro, e "não existe" é uma
  /// resposta, não um silêncio.
  ///
  /// Devolve qual idioma o sistema vai usar de fato: pedir uma variante
  /// regional que ele atende com outra é normal, e a tela precisa poder dizer
  /// isso em vez de deixar a pessoa achando que está transcrevendo em PT-PT.
  static func installLocale(_ locale: String, result: @escaping FlutterResult) async {
    guard let resolved = await EchoSpeech.resolveLocale(locale) else {
      result(FlutterError(
        code: "locale_unsupported",
        message: "O macOS não tem modelo de transcrição para \(locale).",
        details: nil))
      return
    }

    let transcriber = EchoSpeech.transcriber(locale: resolved, live: false)

    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await request.downloadAndInstall()
      }

      // Reservar é o que impede o sistema de recolher o modelo depois de um
      // tempo sem uso: são poucos os idiomas que ele mantém alocados por app, e
      // o modelo recolhido volta a ser um download no pior momento — o começo
      // de uma reunião.
      try await AssetInventory.reserve(locale: resolved)

      result(["locale": resolved.identifier(.bcp47)])
    } catch {
      result(FlutterError(code: "locale_install_failed", message: error.localizedDescription, details: nil))
    }
  }
}

/// Transcrição ao vivo: opcional, e de propósito descartável.
///
/// O que ela produz é aviso na tela enquanto a reunião acontece, não o
/// resultado final — esse sai do arquivo, depois. Se ela falhar, engasgar ou
/// for desligada no meio, nada se perde.
///
/// Classe, e não `actor`, por causa da ordem: os blocos de áudio chegam por uma
/// fila serial só (a mesma para as duas faixas) e são entregues aqui de forma
/// síncrona. Num `actor`, cada bloco viraria uma `Task` — e `Task`s não têm
/// ordem garantida entre si, o que entregaria o áudio embaralhado.
@available(macOS 26.0, *)
final class EchoLiveTranscriber {
  private let channel: FlutterMethodChannel
  private let transcriber: SpeechTranscriber
  private let analyzer: SpeechAnalyzer
  private let continuation: AsyncStream<AnalyzerInput>.Continuation
  private var pump: Task<Void, Never>?

  static func make(
    locale: Locale,
    vocabulary: [String],
    channel: FlutterMethodChannel
  ) async -> EchoLiveTranscriber? {
    let transcriber = EchoSpeech.transcriber(locale: locale, live: true)

    var continuation: AsyncStream<AnalyzerInput>.Continuation!
    let stream = AsyncStream<AnalyzerInput> { continuation = $0 }

    let analyzer = SpeechAnalyzer(
      inputSequence: stream,
      modules: [transcriber],
      analysisContext: EchoSpeech.context(vocabulary: vocabulary))
    let live = EchoLiveTranscriber(
      channel: channel, transcriber: transcriber, analyzer: analyzer, continuation: continuation)
    live.startPump()
    return live
  }

  private init(
    channel: FlutterMethodChannel,
    transcriber: SpeechTranscriber,
    analyzer: SpeechAnalyzer,
    continuation: AsyncStream<AnalyzerInput>.Continuation
  ) {
    self.channel = channel
    self.transcriber = transcriber
    self.analyzer = analyzer
    self.continuation = continuation
  }

  private func startPump() {
    pump = Task { [transcriber, channel] in
      do {
        for try await result in transcriber.results {
          // Só o que o analisador já deu por fechado. O painel mostra frase
          // pronta, nunca a mesma frase crescendo ("olá", "olá tudo", "olá tudo
          // bem") — isso é ruído, não sinal. Por isso o transcritor ao vivo
          // nem pede as revisões parciais (`.volatileResults`): pedi-las seria
          // gastar processador durante a chamada para descartar o resultado
          // aqui. A guarda fica como rede, para o caso de alguma chegar.
          guard result.isFinal else { continue }

          let text = String(result.text.characters)
          guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

          await MainActor.run {
            channel.invokeMethod("onLiveSegment", arguments: ["text": text])
          }
        }
      } catch {
        // Ao vivo é enfeite: falhou, para de avisar e a reunião segue gravando.
      }
    }
  }

  /// Recebe um bloco **já convertido** para o formato de gravação.
  ///
  /// O analisador não aceita qualquer formato, e é justamente por isso que a
  /// gravação pergunta a ele (`EchoSpeech.audioFormat`) em que formato gravar,
  /// em vez de escolher um: o que a gravação escreve no arquivo é o mesmo que
  /// chega aqui. Entregar o bloco cru da captura aborta o processo dentro do
  /// Speech, sem erro que dê para capturar.
  ///
  /// Síncrono, e chamado da fila de áudio: é o que preserva a ordem dos blocos.
  func append(_ buffer: AVAudioPCMBuffer) {
    continuation.yield(AnalyzerInput(buffer: buffer))
  }

  func finish() async {
    continuation.finish()
    try? await analyzer.finalizeAndFinishThroughEndOfInput()
    pump?.cancel()
  }
}

// MARK: - Resumo

/// Resume um bloco de texto com o modelo do Apple Intelligence.
///
/// Um bloco por chamada, de propósito: quem corta o texto em blocos é o Dart,
/// onde isso é lógica testável. Aqui só entra o que já cabe na janela do
/// modelo.
@available(macOS 26.0, *)
enum EchoSummarizer {
  /// Instrução usada quando a pessoa não escreveu a dela nas preferências.
  ///
  /// Hoje é rede, não caminho: o Echo grava com cada resumo a instrução que o
  /// produziu, e para isso o Dart resolve a padrão antes de chamar e a manda
  /// explícita (`EchoSettings.defaultInstructions`, com esta mesma frase). Só
  /// chega aqui vazio quem chamar o canal sem passar por lá. Mexeu numa,
  /// mexa na outra.
  static let defaultInstructions = """
    Você resume reuniões em português do Brasil. \
    Escreva em tópicos curtos. \
    Registre decisões, pendências e quem ficou responsável por cada coisa. \
    Não invente nada que não esteja no texto.
    """

  /// Quantos tokens cabem numa chamada — instrução, texto e resposta juntos.
  ///
  /// Quem corta os blocos é o Dart, e ele precisa saber o tamanho da janela de
  /// verdade: ela dobrou no macOS 27 (de 4.096 para 8.192), e um teto escrito
  /// à mão para a janela antiga deixaria metade dela vazia. A propriedade
  /// existe desde o 26.0 (`@backDeployed`), então não há ramo por versão aqui.
  static var contextSize: Int {
    SystemLanguageModel.default.contextSize
  }

  static func summarize(text: String, instructions: String?, result: @escaping FlutterResult) async {
    guard case .available = SystemLanguageModel.default.availability else {
      result(FlutterError(
        code: "model_unavailable",
        message: "O modelo do Apple Intelligence não está disponível nesta máquina.",
        details: nil))
      return
    }

    let chosen = instructions?.trimmingCharacters(in: .whitespacesAndNewlines)
    let session = LanguageModelSession(
      instructions: (chosen?.isEmpty == false ? chosen : nil) ?? defaultInstructions)

    do {
      let response = try await session.respond(to: text)
      result(response.content)
    } catch where isContextSizeExceeded(error) {
      // O estouro de janela é o único erro que o Dart sabe tratar sozinho:
      // ele reparte o bloco e tenta de novo.
      result(FlutterError(code: "context_window_exceeded", message: error.localizedDescription, details: nil))
    } catch {
      result(FlutterError(code: "summary_failed", message: error.localizedDescription, details: nil))
    }
  }

  /// O estouro de janela, pelas duas portas por onde ele chega.
  ///
  /// No macOS 27 o erro mudou de tipo: o SDK aposenta o `GenerationError` e
  /// manda usar `LanguageModelError.contextSizeExceeded`. Olhar só o antigo
  /// faria o 27 cair em `summary_failed` — e o Dart, que reparte o
  /// bloco ao meio quando recebe `context_window_exceeded`, desistia da reunião
  /// inteira em vez de tentar de novo com metade.
  private static func isContextSizeExceeded(_ error: Error) -> Bool {
    if #available(macOS 27.0, *),
      let error = error as? LanguageModelError,
      case .contextSizeExceeded = error
    {
      return true
    }

    if let error = error as? LanguageModelSession.GenerationError,
      case .exceededContextWindowSize = error
    {
      return true
    }

    return false
  }
}

/// Escuta a `SCStream` só para o que ela tem de irreversível: parar sozinha.
///
/// Uma classe minúscula, e não o próprio `EchoRecorder`, porque o `SCStream`
/// retém o delegate e o gravador é quem retém o stream — fechar esse ciclo
/// seguraria a gravação inteira na memória depois de ela terminar.
@available(macOS 26.0, *)
final class EchoStreamDelegate: NSObject, SCStreamDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var stored: String?

  /// O que derrubou a captura, se alguma coisa derrubou.
  ///
  /// Sob trava porque o `SCStream` avisa de uma thread própria e quem lê é o
  /// gravador, ao parar.
  var error: String? {
    lock.lock()
    defer { lock.unlock() }
    return stored
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    lock.lock()
    stored = error.localizedDescription
    lock.unlock()
  }
}

/// O espectro de uma faixa, em bandas — o que faz o painel ter um equalizador
/// em vez de uma fita de áudio passando.
///
/// **Cada barra é uma faixa de frequência medida, não um enfeite que sobe e
/// desce.** Um pico só por faixa responde "está entrando som?" e nada mais: com
/// um número, todas as barras teriam a mesma altura, e desenhá-las diferentes
/// seria inventar. Aqui o bloco de áudio passa por uma FFT e vira energia por
/// banda, que é o que se vê mexendo quando alguém fala: as graves na voz, as
/// agudas nas consoantes.
///
/// Roda na fila do áudio, junto do resto — 512 amostras de FFT a cada 100 ms
/// são microssegundos de trabalho no Accelerate, contra os 23 MB por minuto que
/// a mesma fila já converte e escreve em disco.
@available(macOS 26.0, *)
final class EchoSpectrum {
  /// Amostras por análise.
  ///
  /// 512 a 16 kHz são 32 ms de som: janela curta o bastante para acompanhar a
  /// fala e longa o bastante para separar o que é grave do que é agudo (cada
  /// raia sai com 31 Hz de largura).
  static let size = 512

  /// Quantas barras cada faixa tem.
  static let bands = 10

  /// A faixa de frequência que interessa, em Hz.
  ///
  /// Começa acima do ronco de sala e do estouro de mesa; termina onde a voz
  /// humana já não tem energia que valha uma barra. Fora disso o desenho
  /// mostraria ar-condicionado.
  private static let lowestHz: Float = 110
  private static let highestHz: Float = 6000

  /// O piso em decibéis que vira barra zerada. Abaixo disso é silêncio de sala.
  private static let floorDb: Float = -58

  private let sampleRate: Float
  private let window: [Float]
  private let fft: vDSP.FFT<DSPSplitComplex>?

  /// As últimas [size] amostras, em anel: a análise é sempre sobre o som mais
  /// recente, e não sobre o que sobrou do bloco anterior.
  private var ring = [Float](repeating: 0, count: EchoSpectrum.size)
  private var cursor = 0

  init(sampleRate: Double) {
    self.sampleRate = Float(sampleRate)

    var hann = [Float](repeating: 0, count: Self.size)
    // Sem janela, o corte seco nas pontas do bloco espalha energia por todas as
    // raias — e um equalizador com todas as barras sempre acesas não mede nada.
    vDSP_hann_window(&hann, vDSP_Length(Self.size), Int32(vDSP_HANN_NORM))
    window = hann

    let log2n = vDSP_Length(log2(Float(Self.size)))
    fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)
  }

  /// Guarda o bloco recém-convertido. Barato: é só cópia para o anel.
  func append(_ buffer: AVAudioPCMBuffer) {
    let frames = Int(buffer.frameLength)
    guard frames > 0 else { return }

    if let channel = buffer.floatChannelData?[0] {
      for index in 0..<frames { push(channel[index]) }
      return
    }

    if let channel = buffer.int16ChannelData?[0] {
      for index in 0..<frames { push(Float(channel[index]) / 32768) }
    }
  }

  private func push(_ sample: Float) {
    ring[cursor] = sample
    cursor = (cursor + 1) % Self.size
  }

  /// As bandas, de 0 a 1, da mais grave para a mais aguda.
  func bands() -> [Double] {
    guard let fft = fft else { return Array(repeating: 0, count: Self.bands) }

    // Desenrola o anel: a amostra mais antiga primeiro, a mais nova por último.
    var input = [Float](repeating: 0, count: Self.size)
    for index in 0..<Self.size {
      input[index] = ring[(cursor + index) % Self.size]
    }
    vDSP_vmul(input, 1, window, 1, &input, 1, vDSP_Length(Self.size))

    let half = Self.size / 2
    var real = [Float](repeating: 0, count: half)
    var imaginary = [Float](repeating: 0, count: half)
    var outputReal = [Float](repeating: 0, count: half)
    var outputImaginary = [Float](repeating: 0, count: half)
    var magnitudes = [Float](repeating: 0, count: half)

    real.withUnsafeMutableBufferPointer { realPointer in
      imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
        var split = DSPSplitComplex(
          realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)

        input.withUnsafeBytes { raw in
          vDSP_ctoz(
            raw.bindMemory(to: DSPComplex.self).baseAddress!, 2,
            &split, 1, vDSP_Length(half))
        }

        outputReal.withUnsafeMutableBufferPointer { outputRealPointer in
          outputImaginary.withUnsafeMutableBufferPointer { outputImaginaryPointer in
            var output = DSPSplitComplex(
              realp: outputRealPointer.baseAddress!,
              imagp: outputImaginaryPointer.baseAddress!)

            fft.forward(input: split, output: &output)
            vDSP_zvabs(&output, 1, &magnitudes, 1, vDSP_Length(half))
          }
        }
      }
    }

    // A escala do `vDSP` é proporcional ao tamanho da janela; o fator devolve a
    // amplitude ao terreno de 0 a 1, que é onde o decibel abaixo faz sentido.
    let scale = 2 / Float(Self.size)
    var result = [Double](repeating: 0, count: Self.bands)

    for band in 0..<Self.bands {
      let (start, end) = binRange(of: band, half: half)
      var peak: Float = 0
      for bin in start...end { peak = max(peak, magnitudes[bin] * scale) }

      // Decibel, e não a amplitude crua: o ouvido é logarítmico, e em escala
      // linear a barra só sairia do chão com alguém gritando.
      let db = 20 * log10(peak + 1e-7)
      result[band] = Double(min(1, max(0, (db - Self.floorDb) / -Self.floorDb)))
    }

    return result
  }

  /// As raias que entram em cada banda — espaçadas por oitava, como o ouvido
  /// separa: em espaçamento linear, oito das dez barras seriam agudos que a voz
  /// quase não usa.
  private func binRange(of band: Int, half: Int) -> (Int, Int) {
    let ratio = Self.highestHz / Self.lowestHz
    let low = Self.lowestHz * pow(ratio, Float(band) / Float(Self.bands))
    let high = Self.lowestHz * pow(ratio, Float(band + 1) / Float(Self.bands))

    let hzPerBin = sampleRate / Float(Self.size)
    let start = max(1, Int(low / hzPerBin))
    let end = min(half - 1, max(start, Int(high / hzPerBin)))

    return (start, end)
  }
}

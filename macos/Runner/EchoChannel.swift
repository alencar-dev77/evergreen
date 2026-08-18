import AVFoundation
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
  /// o resto do Evergreen continuar rodando no macOS 10.15.
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
        Task {
          await recorder.start(
            liveTranscription: live, locale: locale, channel: channel, result: result)
        }

      case "stopRecording":
        Task { await recorder.stop(result: result) }

      case "cancelRecording":
        Task { await recorder.cancel(result: result) }

      case "transcribe":
        let micPath = arguments["micPath"] as? String
        let systemPath = arguments["systemPath"] as? String
        let locale = arguments["locale"] as? String ?? "pt-BR"
        Task {
          await EchoTranscriber.transcribe(
            micPath: micPath, systemPath: systemPath, locale: locale, result: result)
        }

      case "summarize":
        let text = arguments["text"] as? String ?? ""
        let instructions = arguments["instructions"] as? String
        Task { await EchoSummarizer.summarize(text: text, instructions: instructions, result: result) }

      case "installLocale":
        let locale = arguments["locale"] as? String ?? "pt-BR"
        Task { await EchoTranscriber.installLocale(locale, result: result) }

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
      configuration.captureMicrophone = true
      // Sem fixar taxa nem número de canais: cada bloco é convertido para
      // `recordingFormat` a partir do formato que ele mesmo declara, então
      // impor 48 kHz estéreo aqui não economiza nada e só restringe o que o
      // sistema pode entregar — inclusive na faixa do microfone, que o macOS
      // monta com uma `AVCaptureSession` própria em cima do dispositivo de
      // entrada padrão.
      // O vídeo não interessa, mas a SCStream exige um filtro de tela. Dois
      // pixels a um quadro por segundo é o mais perto de "nada" que dá para
      // pedir sem abrir mão do áudio.
      configuration.width = 2
      configuration.height = 2
      configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)

      let filter = SCContentFilter(display: display, excludingWindows: [])
      let delegate = EchoStreamDelegate()
      let stream = SCStream(filter: filter, configuration: configuration, delegate: delegate)

      let output = EchoStreamOutput(micURL: micURL, systemURL: systemURL)
      if liveTranscription {
        await output.enableLiveTranscription(locale: locale, channel: channel)
      }

      let queue = DispatchQueue(label: "com.alencardev.evergreen.echo.audio")
      try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: queue)
      try stream.addStreamOutput(output, type: .microphone, sampleHandlerQueue: queue)

      try await stream.startCapture()

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

  func stop(result: @escaping FlutterResult) async {
    guard let stream = stream else {
      result(FlutterError(code: "not_recording", message: "Nenhuma gravação em andamento.", details: nil))
      return
    }

    try? await stream.stopCapture()
    await output?.finish()

    let duration = startedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0

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
    ]

    reset()
    result(payload)
  }

  /// Para e joga o áudio fora — para quando a pessoa desiste no meio.
  func cancel(result: @escaping FlutterResult) async {
    if let stream = stream {
      try? await stream.stopCapture()
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
    startedAt = nil
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

  /// Formato em que o áudio é gravado: 16 kHz, mono, inteiro de 16 bits.
  ///
  /// É o que os modelos de fala esperam — e o que a `SCStream` entrega é bem
  /// outra coisa: 48 kHz, estéreo, ponto flutuante. Gravar cru custaria **23 MB
  /// por minuto em cada faixa**, ou seja 2,8 GB por hora de reunião somando as
  /// duas. Convertido, a mesma hora ocupa 230 MB.
  ///
  /// A conversão não perde nada que importe aqui: a fala humana vive abaixo dos
  /// 8 kHz, que é exatamente o teto que 16 kHz de amostragem preserva. Estéreo
  /// então não faz falta nenhuma — cada faixa já é uma fonte só.
  static let recordingFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16_000,
    channels: 1,
    interleaved: true)!

  init(micURL: URL, systemURL: URL) {
    self.micURL = micURL
    self.systemURL = systemURL
  }

  func enableLiveTranscription(locale: String, channel: FlutterMethodChannel) async {
    live = await EchoLiveTranscriber.make(locale: locale, channel: channel)
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
    guard type == .audio || type == .microphone else { return }
    guard let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }

    var converted: AVAudioPCMBuffer?

    do {
      if type == .microphone {
        if micFile == nil {
          micFile = try Self.makeFile(at: micURL)
          micConverter = AVAudioConverter(from: buffer.format, to: Self.recordingFormat)
        }
        converted = Self.convert(buffer, with: micConverter)
        if let converted = converted {
          try micFile?.write(from: converted)
          micFrames += Int64(converted.frameLength)
          micPeak = max(micPeak, Self.peak(of: converted))
        }
      } else {
        if systemFile == nil {
          systemFile = try Self.makeFile(at: systemURL)
          systemConverter = AVAudioConverter(from: buffer.format, to: Self.recordingFormat)
        }
        converted = Self.convert(buffer, with: systemConverter)
        if let converted = converted {
          try systemFile?.write(from: converted)
          systemFrames += Int64(converted.frameLength)
          systemPeak = max(systemPeak, Self.peak(of: converted))
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
  }

  /// Cria o arquivo já no formato em que os blocos vão chegar.
  ///
  /// Sem o `commonFormat:`, o `AVAudioFile` mantém o `processingFormat` em
  /// ponto flutuante mesmo quando os `settings` pedem inteiro de 16 bits — e aí
  /// `write(from:)` com um bloco Int16 **não devolve erro**: aborta o processo
  /// dentro do AudioToolbox, onde nenhum `catch` alcança. Dizer o formato aqui
  /// é o que faz o arquivo aceitar o que o conversor produz.
  private static func makeFile(at url: URL) throws -> AVAudioFile {
    try AVAudioFile(
      forWriting: url,
      settings: recordingFormat.settings,
      commonFormat: recordingFormat.commonFormat,
      interleaved: recordingFormat.isInterleaved)
  }

  /// Reamostra o bloco para [recordingFormat].
  ///
  /// Precisa da API de bloco do `AVAudioConverter`, e não do `convert(to:from:)`
  /// simples: mudar a taxa de amostragem muda a quantidade de quadros, e a
  /// versão simples só aceita conversões que preservam a contagem.
  static func convert(
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
  /// A maior amplitude do bloco, em módulo — 0 é silêncio digital exato.
  ///
  /// Sempre sobre o buffer **já convertido** para [recordingFormat], que é
  /// Int16 mono: um formato só para medir, em vez de um caso para cada coisa
  /// que a captura possa entregar.
  static func peak(of buffer: AVAudioPCMBuffer) -> Int {
    guard let channel = buffer.int16ChannelData?[0] else { return 0 }

    var peak: Int32 = 0
    for index in 0..<Int(buffer.frameLength) {
      peak = max(peak, Int32(channel[index].magnitude))
    }

    return Int(peak)
  }

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
    result: @escaping FlutterResult
  ) async {
    do {
      var segments: [[String: Any]] = []

      if let micPath = micPath, FileManager.default.fileExists(atPath: micPath) {
        segments += try await transcribeFile(at: micPath, locale: locale, speaker: .me)
      }
      if let systemPath = systemPath, FileManager.default.fileExists(atPath: systemPath) {
        segments += try await transcribeFile(at: systemPath, locale: locale, speaker: .others)
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
    locale: String,
    speaker: EchoSpeaker
  ) async throws -> [[String: Any]] {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let transcriber = SpeechTranscriber(
      locale: Locale(identifier: locale),
      preset: .timeIndexedTranscriptionWithAlternatives)

    let analyzer = SpeechAnalyzer(modules: [transcriber])

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
  static func installLocale(_ locale: String, result: @escaping FlutterResult) async {
    let transcriber = SpeechTranscriber(
      locale: Locale(identifier: locale),
      preset: .timeIndexedTranscriptionWithAlternatives)

    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await request.downloadAndInstall()
      }
      result(true)
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

  static func make(locale: String, channel: FlutterMethodChannel) async -> EchoLiveTranscriber? {
    let transcriber = SpeechTranscriber(
      locale: Locale(identifier: locale),
      preset: .timeIndexedProgressiveTranscription)

    var continuation: AsyncStream<AnalyzerInput>.Continuation!
    let stream = AsyncStream<AnalyzerInput> { continuation = $0 }

    let analyzer = SpeechAnalyzer(inputSequence: stream, modules: [transcriber])
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
          // Só o que o analisador já deu por fechado. O preset progressivo
          // reemite o mesmo trecho a cada revisão enquanto ainda está
          // decidindo — somar todos encheria o painel da mesma frase crescendo
          // ("olá", "olá tudo", "olá tudo bem"), que é ruído, não sinal.
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

  /// Recebe um bloco **já convertido** para `EchoStreamOutput.recordingFormat`.
  ///
  /// O analisador não aceita qualquer formato: `bestAvailableAudioFormat`
  /// responde 16 kHz, mono, inteiro de 16 bits — exatamente o formato em que a
  /// gravação já grava. Entregar o bloco cru da captura aborta o processo
  /// dentro do Speech, sem erro que dê para capturar.
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
  static let defaultInstructions = """
    Você resume reuniões em português do Brasil. \
    Escreva em tópicos curtos. \
    Registre decisões, pendências e quem ficou responsável por cada coisa. \
    Não invente nada que não esteja no texto.
    """

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
    } catch let error as LanguageModelSession.GenerationError {
      // O estouro de janela é o único erro que o Dart sabe tratar sozinho:
      // ele reparte o bloco e tenta de novo.
      if case .exceededContextWindowSize = error {
        result(FlutterError(code: "context_window_exceeded", message: error.localizedDescription, details: nil))
        return
      }
      result(FlutterError(code: "summary_failed", message: error.localizedDescription, details: nil))
    } catch {
      result(FlutterError(code: "summary_failed", message: error.localizedDescription, details: nil))
    }
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

import AVFoundation
import Accelerate
import Foundation

/// Tira da faixa do microfone o que, na verdade, saiu pela caixa de som.
///
/// Com a reunião tocando no alto-falante do Mac, o microfone ouve de volta o
/// que o computador toca: a mesma fala entra nas duas faixas, uns 50 ms
/// atrasada na do microfone. Na transcrição ela aparecia duas vezes, uma como
/// "Reunião" e outra como sua; no áudio guardado, que soma as duas faixas, ela
/// tocava dobrada, como um eco curto. Quem cancelava isso era o processamento
/// de voz do sistema, e ele saiu por mexer na reunião dos outros apps (ver
/// `docs/Ideis projeto/echo-transcricao.md`). O `CrossTalkFilter`, que ficou
/// sozinho no lugar, compara texto, e texto reconhecido duas vezes nunca sai
/// igual: "Interno" de um lado, "Interna" do outro; um número inteiro de um e
/// partido em três do outro.
///
/// Aqui a conta é feita no som, **depois** da reunião, com as duas faixas
/// inteiras no disco. A faixa do computador é a referência: ela é o que foi
/// tocado, antes de virar som no ar. A cada 16 ms o cancelador decide se o
/// quadro do microfone é só a referência atrasada e atenuada — e aí ele desce
/// ao fundo da sala — ou se tem você nele, e aí ele passa como entrou. Onde a
/// referência está calada (passada a cauda da sala, uns 200 ms), não há
/// decisão: a sua voz sozinha sai igual entrou.
///
/// É decisão por quadro, e não subtração da onda: a caixa do notebook
/// distorce, a sala reverbera, e o ganho da cápsula (`EchoMicGain`) muda de
/// segundo em segundo. Prever a onda exata do eco exigiria um filtro
/// adaptativo que diverge justamente quando os dois lados falam juntos. E
/// tirar o eco frequência por frequência, dentro de um quadro com você, foi
/// medido e descartado: o reconhecimento de fala perdia a frase inteira dita
/// por cima de alguém.
///
/// **Nada disto toca no microfone ao vivo.** Roda sobre a cópia do Echo, no
/// disco, depois de a gravação parar; o app da reunião nunca fica sabendo. O
/// cancelamento de eco do sistema saiu justamente por mudar o que os outros
/// ouviam da sua voz.
///
/// Três passadas pelos arquivos, e o que se mede da própria reunião:
///
/// 1. **o atraso**, pela correlação entre o contorno de volume das duas
///    faixas nos trechos em que o computador fala, e depois refinado até a
///    amostra pela correlação de fase;
/// 2. **onde há eco**: com fone, o computador fala e o microfone não o
///    acompanha. A mesma correlação, medida numa janela de 10 s em volta de
///    cada instante, diz se ali o microfone está seguindo a referência. Sem
///    isso, a sua voz falando por cima de alguém, de fone, seria lida como eco;
/// 3. **o formato do eco no espectro** (a caixa toca umas frequências mais que
///    outras, e isso não muda) e **o volume do eco a cada segundo**, que muda:
///    o ganho da cápsula sobe e desce, e a pessoa pode trocar de caixa para
///    fone no meio;
/// 4. **se num dado instante há você junto com o eco.** Pela energia (o
///    microfone passa muito do eco esperado?) e pela coerência: o eco tem a
///    mesma estrutura fina da referência, frequência por frequência, e a sua
///    voz não tem.
///
/// O quadro que é só eco desce até o chão de ruído do microfone, e não "uns
/// tantos dB": o reconhecimento de fala normaliza o volume, e eco 30 dB abaixo
/// do original, mas acima do fundo da sala, ainda saía transcrito.
///
/// Os números foram calibrados com fala sintética em português, eco simulado
/// de caixa de notebook (atraso, sala, distorção e o ganho da cápsula subindo
/// e descendo) e a transcrição do próprio `SpeechTranscriber` antes e depois:
/// a fala da reunião sumiu da sua faixa, a sua fala sozinha saiu idêntica, e a
/// fala por cima se salvou sempre que você estava mais alto que o eco. No
/// mesmo volume dele, ela se perde — é o caso que nenhum cancelador resolve
/// sem a onda do eco, e o `CrossTalkFilter` segue de rede para o que escapar.
///
/// Fica fora do Swift do canal por ser só conta: não conhece Flutter nem
/// `ScreenCaptureKit`, e por isso se testa com duas faixas sintéticas.
enum EchoCanceller {
  /// O que a limpeza fez, para quem precisar contar.
  struct Report: CustomStringConvertible {
    /// A faixa foi reescrita. `false` quando não havia eco para tirar.
    var applied = false

    /// Quanto o microfone atrasa em relação à referência.
    var delayMs: Double = 0

    /// Correlação do contorno de volume no atraso achado, de −1 a 1.
    var correlation: Float = 0

    /// Fração dos quadros com a referência falando em que havia eco.
    var presence: Float = 0

    /// Fração desses quadros que foi inteira ao chão de ruído.
    var silenced: Float = 0

    /// Quanto o atraso anda por segundo, em milionésimos: zero quando a caixa
    /// e o microfone são do mesmo aparelho.
    var driftPpm: Float = 0

    var description: String {
      String(
        format:
          "aplicado=%@ atraso=%.1fms deriva=%.0fppm correlação=%.2f presença=%.2f silenciados=%.2f",
        applied ? "sim" : "não", delayMs, driftPpm, correlation, presence, silenced)
    }
  }

  /// A correlação que uma janela de 10 s precisa ter para o atraso dela
  /// contar na reta — ver [Survey.delayLine].
  static let windowCorrelation: Float = 0.3

  /// A correlação que uma janela precisa ter para valer sozinha, quando as
  /// outras não formam uma reta. Medido: fone fica abaixo de 0,3 em toda
  /// janela; caixa, acima de 0,6.
  static let loneWindowCorrelation: Float = 0.45

  /// A maior deriva que se aceita entre a caixa e o microfone: 500
  /// milionésimos, meio segundo por quarto de hora. Relógio de áudio de
  /// verdade fica abaixo de 100; uma reta mais inclinada que isto é sorteio.
  static let maxDrift: Float = 500e-6

  /// A presença local que conta como "aqui tem eco", e a que conta como
  /// "aqui não tem" — entre as duas, o eco esperado é proporcional, e com ele
  /// a chance de o quadro ser julgado eco.
  ///
  /// Medido nas faixas sintéticas: eco de caixa de notebook dá 0,6 a 0,8 com a
  /// pessoa falando por cima; fone dá menos de 0,15.
  static let presenceLow: Float = 0.25
  static let presenceHigh: Float = 0.45

  /// Quanto o atraso pode ser.
  ///
  /// Eco de caixa nunca chega ao microfone antes de a referência tocar: o
  /// pouco de adiantamento aceito cobre só a diferença de latência entre as
  /// duas capturas. Buscar mais que isso era perigoso — quando alguém do
  /// outro lado não tem cancelamento de eco, a *sua* voz volta pela faixa do
  /// computador uns 150 a 400 ms depois de você, e aí é o microfone que
  /// parece adiantado: o cancelador tomaria a sua voz por eco, até de fone.
  static let maxLeadMs = 48
  static let maxLagMs = 800

  /// A cauda da sala: por quantos quadros o eco continua soando depois de a
  /// referência calar, e quanto ele cai em cada um.
  static let tailFrames = 12
  static let tailDecay: Float = 0.6

  /// Abaixo disto o quadro é eco, coerente ou não: o microfone não passa do
  /// eco esperado na banda da fala.
  static let nearEndMargin: Float = 1

  /// Até quanto acima do eco esperado (8 dB) um quadro **coerente** com a
  /// referência ([echoCoherence]) ainda é eco.
  ///
  /// A coerência é a que separa os dois quando têm o mesmo volume; a margem é
  /// a que salva a sua voz bem mais alta que o eco, que herda um pouco da
  /// coerência do quadro anterior pela média curta.
  static let coherentMargin: Float = 6.3

  /// A coerência média, na banda da fala, acima da qual o quadro se parece
  /// com a referência.
  ///
  /// Medido: quadro só de eco fica em 0,97 na mediana e acima de 0,8 em 90%
  /// deles; com você mais alto que o eco, a mediana cai para 0,2. Com os três
  /// números juntos, 99% dos quadros só de eco vão ao fundo da sala, e 6 a 10%
  /// dos quadros em que você está mais alto que o eco — quase todos na borda
  /// de uma sílaba.
  static let echoCoherence: Float = 0.8

  static func clean(micURL: URL, referenceURL: URL) throws -> Report {
    let mic = try AVAudioFile(
      forReading: micURL, commonFormat: .pcmFormatFloat32, interleaved: false)
    let reference = try AVAudioFile(
      forReading: referenceURL, commonFormat: .pcmFormatFloat32, interleaved: false)

    var report = Report()
    let rate = mic.processingFormat.sampleRate

    guard rate > 0, reference.processingFormat.sampleRate == rate,
      mic.length > 0, reference.length > 0
    else { return report }

    let stft = EchoSTFT(sampleRate: rate)
    let hop = stft.hop
    let frameMs = Double(hop) / rate * 1000
    // Um quadro a mais no fim, para a sobreposição devolver a última amostra.
    let frames = Int((mic.length + Int64(hop) - 1) / Int64(hop)) + 1

    // 1. O contorno de volume e o chão de cada faixa.
    let survey = try Survey.measure(
      mic: mic, reference: reference, stft: stft, frames: frames)

    // 2. O atraso ao longo da reunião — uma reta, porque dois relógios
    // diferentes derivam a passo constante.
    let maxLead = Int(Double(maxLeadMs) / frameMs)
    let maxLag = Int(Double(maxLagMs) / frameMs)
    guard
      let line = survey.delayLine(
        minLag: -maxLead, maxLag: maxLag, window: Int(10_000 / frameMs))
    else { return report }

    report.correlation = line.correlation
    report.driftPpm = line.slope * 1e6
    let lags = (0..<frames).map { Int(line.lag(at: $0).rounded()) }

    // 3. Onde há eco, quadro a quadro.
    let presence = survey.presence(lags: lags, halfWindow: Int(5_000 / frameMs))
    let active = survey.referenceActive.indices.filter { survey.referenceActive[$0] }
    let present = active.filter {
      presence[min(max($0 + lags[$0], 0), frames - 1)] >= presenceHigh
    }.count
    report.presence = active.isEmpty ? 0 : Float(present) / Float(active.count)
    guard present > 0 else { return report }

    // 4. O caminho do eco — e o atraso fino, até a amostra, a cada 10 s.
    let coarse = (0..<frames).map { Int((line.lag(at: $0) * Float(hop)).rounded()) }
    let block = Int(10_000 / frameMs)
    guard
      let path = try EchoPath.measure(
        mic: mic, reference: reference, stft: stft, frames: frames,
        delays: coarse, block: block, survey: survey, presence: presence)
    else { return report }

    let delays = path.refined(coarse, block: block)
    report.delayMs = Double(delays[frames / 2]) / rate * 1000

    // 5. A limpeza, num arquivo ao lado — só substitui o original no fim.
    let cleanedURL = micURL.deletingLastPathComponent()
      .appendingPathComponent(micURL.deletingPathExtension().lastPathComponent + "-limpo.caf")
    try? FileManager.default.removeItem(at: cleanedURL)

    do {
      report.silenced = try Suppressor.write(
        mic: mic, reference: reference, stft: stft, frames: frames, delays: delays,
        survey: survey, presence: presence, path: path, to: cleanedURL)
      _ = try FileManager.default.replaceItemAt(micURL, withItemAt: cleanedURL)
    } catch {
      try? FileManager.default.removeItem(at: cleanedURL)
      throw error
    }

    report.applied = true
    return report
  }
}

// MARK: - Primeira passada: o contorno de volume

/// O que se mede das duas faixas lado a lado, antes de saber o atraso.
private struct Survey {
  /// O volume da fala em cada quadro, em log natural da energia entre 300 Hz e
  /// 3,4 kHz — a banda em que a fala vive e em que a caixa do notebook toca.
  var micEnvelope: [Float]
  var referenceEnvelope: [Float]

  /// A referência tem fala naquele quadro.
  var referenceActive: [Bool]

  /// O chão de ruído do microfone em cada frequência (o 10º percentil).
  var micFloor: [Float]

  /// O nível abaixo do qual a referência, naquela frequência, é silêncio.
  var referenceFloor: [Float]

  /// O fundo da sala somado na banda da fala.
  var bandFloor: Float

  static func measure(
    mic: AVAudioFile, reference: AVAudioFile, stft: EchoSTFT, frames: Int
  ) throws -> Survey {
    let bins = stft.bins
    let band = stft.speechBand

    var micEnvelope = [Float](repeating: 0, count: frames)
    var referenceEnvelope = [Float](repeating: 0, count: frames)
    var micHistogram = LogHistogram(bins: bins, low: -40, high: 20, step: 0.25)
    var referenceHistogram = LogHistogram(bins: bins, low: -40, high: 20, step: 0.25)

    try EchoFramePair.run(
      mic: mic, reference: reference, referenceDelay: { _ in 0 }, stft: stft, frames: frames
    ) { frame, pair in
      let micBand = pair.micPower[band].reduce(0, +)
      micEnvelope[frame] = logf(micBand + 1e-10)
      referenceEnvelope[frame] = logf(pair.referencePower[band].reduce(0, +) + 1e-10)

      // O silêncio digital que o próprio Echo escreve — o buraco de um
      // religamento, o microfone que morreu — não é o fundo da sala: com ele
      // no meio, o chão de ruído ia a zero, e o eco virava buraco.
      let micHasSound = micBand > 1e-9
      for bin in 0..<bins {
        if micHasSound { micHistogram.add(bin, logf(pair.micPower[bin] + 1e-12)) }
        referenceHistogram.add(bin, logf(pair.referencePower[bin] + 1e-12))
      }
    }

    // A referência é digital: calada, ela é zero exato. "Falando" é estar a
    // menos de 50 dB do trecho mais alto dela.
    let loudest = referenceEnvelope.max() ?? 0
    let referenceActive = referenceEnvelope.map { $0 > loudest - 11.5 }

    let micFloor = (0..<bins).map { expf(micHistogram.quantile($0, 0.1)) }
    let referenceFloor = (0..<bins).map {
      max(1e-10, expf(referenceHistogram.quantile($0, 0.99)) * 1e-5)
    }

    return Survey(
      micEnvelope: micEnvelope, referenceEnvelope: referenceEnvelope,
      referenceActive: referenceActive, micFloor: micFloor,
      referenceFloor: referenceFloor, bandFloor: micFloor[band].reduce(0, +))
  }

  /// O atraso do microfone, em quadros, ao longo da reunião.
  ///
  /// Uma reta e não um número: com a caixa numa interface USB e o microfone
  /// no Mac, cada aparelho tem o próprio relógio, e o atraso do eco anda — 100
  /// milionésimos são 360 ms numa hora. Medido nas faixas sintéticas: com um
  /// atraso só, 37 ms de deriva já bastavam para o eco voltar a passar.
  ///
  /// Cada janela de 10 s acha o atraso dela; a reta é a de Theil–Sen (a
  /// mediana das inclinações), que ignora as janelas que acharam outra
  /// coisa. É também o que protege o fone: sem eco, cada janela acha um
  /// atraso ao acaso, e atrasos ao acaso não ficam numa reta.
  func delayLine(minLag: Int, maxLag: Int, window: Int) -> DelayLine? {
    let frames = micEnvelope.count
    let (reference, mic) = clampedEnvelopes()
    let span = max(1, min(window, frames))
    let step = max(1, span / 2)

    var points: [(center: Float, lag: Float, correlation: Float)] = []
    var start = 0
    while true {
      let end = min(frames, start + span)
      if let (lag, correlation) = bestLag(
        reference, mic, in: start..<end, minLag: minLag, maxLag: maxLag),
        correlation >= EchoCanceller.windowCorrelation
      {
        points.append((Float(start + end) / 2, Float(lag), correlation))
      }
      if end == frames { break }
      start += step
    }

    guard !points.isEmpty else { return nil }

    // Só pares de janelas que não se sobrepõem: duas vizinhas dividem metade
    // dos quadros e acham quase sempre o mesmo atraso.
    var slopes: [Float] = []
    for i in points.indices {
      for j in points.indices where points[j].center - points[i].center >= Float(span) {
        slopes.append((points[j].lag - points[i].lag) / (points[j].center - points[i].center))
      }
    }
    var slope = slopes.isEmpty ? 0 : Self.median(slopes)
    if abs(slope) > EchoCanceller.maxDrift { slope = 0 }

    let intercept = Self.median(points.map { $0.lag - slope * $0.center })
    let inliers = points.filter { abs($0.lag - (intercept + slope * $0.center)) <= 2 }

    // Pelo menos duas janelas e metade delas na reta. Sem isso, ainda vale
    // uma janela sozinha que seja convincente — a reunião curta, ou a que
    // passou da caixa para o fone logo no começo —, com o atraso dela parado.
    guard inliers.count >= 2, inliers.count * 2 >= points.count else {
      guard let strongest = points.max(by: { $0.correlation < $1.correlation }),
        strongest.correlation >= EchoCanceller.loneWindowCorrelation
      else { return nil }
      return DelayLine(intercept: strongest.lag, slope: 0, correlation: strongest.correlation)
    }

    return DelayLine(
      intercept: Self.median(inliers.map { $0.lag - slope * $0.center }),
      slope: slope,
      correlation: Self.median(inliers.map(\.correlation)))
  }

  /// O atraso com maior correlação dentro de uma janela, só sobre os quadros
  /// em que a referência fala: é ali que o eco existe. Com os silêncios
  /// dentro, a conversa em turnos — o computador calado enquanto você fala —
  /// puxaria a correlação para baixo e esconderia o eco.
  private func bestLag(
    _ reference: [Float], _ mic: [Float], in range: Range<Int>, minLag: Int, maxLag: Int
  ) -> (Int, Float)? {
    let frames = mic.count
    var best: (Int, Float)?

    for lag in minLag...maxLag {
      var sums = CorrelationSums()
      for frame in range where referenceActive[frame] {
        let other = frame + lag
        guard other >= 0, other < frames else { continue }
        sums.add(reference[frame], mic[other])
      }

      guard sums.count >= 50, let correlation = sums.correlation else { continue }
      if best == nil || correlation > best!.1 { best = (lag, correlation) }
    }

    return best
  }

  private static func median(_ values: [Float]) -> Float {
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
  }

  /// Quanto, em volta de cada quadro do microfone, ele segue a referência.
  ///
  /// A mesma correlação do [delayLine], numa janela de `2 × halfWindow`
  /// quadros, com o atraso de cada quadro (`lags`, indexado pela referência).
  func presence(lags: [Int], halfWindow: Int) -> [Float] {
    let frames = micEnvelope.count
    let (reference, mic) = clampedEnvelopes()

    // Somas acumuladas, para cada janela custar uma subtração.
    var prefix = [CorrelationSums](repeating: CorrelationSums(), count: frames + 1)
    for frame in 0..<frames {
      prefix[frame + 1] = prefix[frame]
      let other = frame + lags[frame]
      if referenceActive[frame], other >= 0, other < frames {
        prefix[frame + 1].add(reference[frame], mic[other])
      }
    }

    // Indexada pelo quadro do microfone, que é onde ela é usada.
    return (0..<frames).map { frame in
      let center = min(max(frame - lags[frame], 0), frames - 1)
      let window = prefix[min(frames, center + halfWindow)] - prefix[max(0, center - halfWindow)]
      guard window.count >= 30 else { return 0 }
      return window.correlation ?? 0
    }
  }

  /// Os contornos sem o fundo do poço: 60 dB abaixo do mais alto vira o
  /// chão. Sem o corte, o silêncio digital (log de zero) pesaria mais que toda
  /// a fala junta.
  private func clampedEnvelopes() -> ([Float], [Float]) {
    func clamp(_ values: [Float]) -> [Float] {
      let floor = (values.max() ?? 0) - 13.8
      return values.map { max($0, floor) }
    }
    return (clamp(referenceEnvelope), clamp(micEnvelope))
  }
}

/// O atraso do microfone ao longo da reunião, em quadros.
private struct DelayLine {
  var intercept: Float
  var slope: Float

  /// A correlação mediana das janelas que caíram na reta.
  var correlation: Float

  func lag(at frame: Int) -> Float { intercept + slope * Float(frame) }
}

/// As somas de que a correlação de Pearson precisa, acumuláveis.
private struct CorrelationSums {
  // Em `Double`: numa reunião de duas horas as somas acumuladas passam de
  // dez milhões, e em `Float` a diferença entre duas delas — a janela —
  // viraria arredondamento.
  var count: Double = 0
  var x: Double = 0
  var y: Double = 0
  var xx: Double = 0
  var yy: Double = 0
  var xy: Double = 0

  mutating func add(_ a: Float, _ b: Float) {
    let a = Double(a), b = Double(b)
    count += 1
    x += a
    y += b
    xx += a * a
    yy += b * b
    xy += a * b
  }

  var correlation: Float? {
    guard count > 1 else { return nil }
    let covariance = xy - x * y / count
    let varianceX = xx - x * x / count
    let varianceY = yy - y * y / count
    guard varianceX > 0, varianceY > 0 else { return nil }
    return Float(covariance / (varianceX * varianceY).squareRoot())
  }

  static func - (lhs: CorrelationSums, rhs: CorrelationSums) -> CorrelationSums {
    CorrelationSums(
      count: lhs.count - rhs.count, x: lhs.x - rhs.x, y: lhs.y - rhs.y,
      xx: lhs.xx - rhs.xx, yy: lhs.yy - rhs.yy, xy: lhs.xy - rhs.xy)
  }
}

// MARK: - Segunda passada: o caminho do eco

/// Quanto da referência chega ao microfone, por frequência e por momento.
///
/// O eco de cada quadro é estimado como `forma[f] × volume(t) × referência`:
/// a forma é da caixa e da sala, e fica a mesma; o volume é do ganho da
/// cápsula e de onde o som está saindo, e muda. As duas são medidas pela
/// mediana, e não pela média: um quadro em que você fala por cima do
/// computador parece um eco muito alto, e a mediana o ignora enquanto ele for
/// minoria.
private struct EchoPath {
  /// A razão eco/referência de cada frequência, em relação ao quadro.
  var shape: [Float]

  /// O volume do eco em cada quadro.
  var level: [Float]

  /// Quantas amostras o atraso tem além da reta, bloco a bloco de 10 s;
  /// `nil` no bloco sem eco para medir.
  var residuals: [Int?]

  /// Quadros ativos por grupo, ao medir o volume: uns 1 s de fala.
  static let groupSize = 60

  static func measure(
    mic: AVAudioFile, reference: AVAudioFile, stft: EchoSTFT, frames: Int,
    delays: [Int], block: Int, survey: Survey, presence: [Float]
  ) throws -> EchoPath? {
    let bins = stft.bins
    let reach = EchoReach(bins: bins)
    var histogram = LogHistogram(bins: bins, low: -12, high: 12, step: 0.1)
    var measuredFrames: [Int] = []
    var measuredLevels: [Float] = []
    var ratios = [Float](repeating: 0, count: bins)
    var usable = [Bool](repeating: false, count: bins)

    // A correlação de fase entre as duas faixas, somada bloco a bloco: o pico
    // dela é o atraso que sobra além da reta.
    let blocks = (frames + block - 1) / block
    var phaseReal = [[Float]](repeating: [Float](repeating: 0, count: bins), count: blocks)
    var phaseImag = phaseReal
    var phaseFrames = [Int](repeating: 0, count: blocks)

    try EchoFramePair.run(
      mic: mic, reference: reference, referenceDelay: { delays[$0] }, stft: stft,
      frames: frames
    ) { frame, pair in
      let echo = reach.push(pair.referencePower)
      guard presence[frame] >= EchoCanceller.presenceHigh else { return }

      var count = 0
      for bin in 0..<bins {
        usable[bin] =
          echo[bin] > survey.referenceFloor[bin]
          && pair.micPower[bin] > survey.micFloor[bin] * 2
        guard usable[bin] else { continue }
        ratios[count] = logf((pair.micPower[bin] - survey.micFloor[bin]) / echo[bin])
        count += 1
      }
      guard count >= 8 else { return }

      var sorted = Array(ratios[0..<count])
      sorted.sort()
      let level = sorted[count / 2]
      measuredFrames.append(frame)
      measuredLevels.append(level)

      let aligned = pair.reference
      let index = frame / block
      phaseFrames[index] += 1
      for bin in 0..<bins where usable[bin] {
        histogram.add(
          bin, logf((pair.micPower[bin] - survey.micFloor[bin]) / echo[bin]) - level)

        // Microfone vezes o conjugado da referência, só com a fase.
        let (micReal, micImag) = pair.mic.at(bin)
        let (refReal, refImag) = aligned.at(bin)
        let real = micReal * refReal + micImag * refImag
        let imag = micImag * refReal - micReal * refImag
        let magnitude = (real * real + imag * imag).squareRoot()
        guard magnitude > 0 else { continue }
        phaseReal[index][bin] += real / magnitude
        phaseImag[index][bin] += imag / magnitude
      }
    }

    guard measuredFrames.count >= groupSize else { return nil }

    // A forma: mediana de cada frequência. Frequência que nunca teve medida
    // copia a vizinha mais próxima que teve.
    var shape = [Float?](repeating: nil, count: bins)
    for bin in 0..<bins where histogram.count(bin) >= 30 {
      shape[bin] = histogram.quantile(bin, 0.5)
    }
    guard shape.contains(where: { $0 != nil }) else { return nil }
    let filled = (0..<bins).map { bin -> Float in
      if let value = shape[bin] { return expf(value) }
      for distance in 1..<bins {
        if bin - distance >= 0, let value = shape[bin - distance] { return expf(value) }
        if bin + distance < bins, let value = shape[bin + distance] { return expf(value) }
      }
      return 1
    }

    // O volume: um valor por grupo de quadros, o 40º percentil — abaixo da
    // mediana, para um grupo com muita fala por cima não inflar o eco —, e a
    // mediana de cinco grupos vizinhos por cima disso.
    var centers: [Int] = []
    var values: [Float] = []
    var start = 0
    while start < measuredFrames.count {
      let end = min(measuredFrames.count, start + groupSize)
      if end - start < groupSize / 2, !values.isEmpty { break }
      var group = Array(measuredLevels[start..<end])
      group.sort()
      values.append(group[Int(Float(group.count - 1) * 0.4)])
      centers.append(measuredFrames[(start + end) / 2])
      start = end
    }
    let smoothed = values.indices.map { index -> Float in
      var neighbors = Array(values[max(0, index - 2)...min(values.count - 1, index + 2)])
      neighbors.sort()
      return neighbors[neighbors.count / 2]
    }

    // De grupo em grupo, em linha reta; antes do primeiro e depois do último,
    // o valor dele.
    var level = [Float](repeating: 0, count: frames)
    var next = 0
    for frame in 0..<frames {
      while next < centers.count, centers[next] <= frame { next += 1 }
      let value: Float
      if next == 0 {
        value = smoothed[0]
      } else if next == centers.count {
        value = smoothed[centers.count - 1]
      } else {
        let a = centers[next - 1], b = centers[next]
        let t = Float(frame - a) / Float(max(1, b - a))
        value = smoothed[next - 1] * (1 - t) + smoothed[next] * t
      }
      level[frame] = expf(value)
    }

    // O atraso fino de cada bloco: o pico da correlação de fase, dentro de
    // meio quadro para cada lado. A reta já põe o eco a menos de meio quadro.
    let residuals = (0..<blocks).map { index -> Int? in
      guard phaseFrames[index] >= 50 else { return nil }
      let correlation = stft.inverse(real: phaseReal[index], imag: phaseImag[index])
      var peak = 0
      var highest = -Float.infinity
      for shift in -stft.hop...stft.hop {
        let value = correlation[(shift + stft.size) % stft.size]
        if value > highest {
          highest = value
          peak = shift
        }
      }
      return peak
    }

    return EchoPath(shape: filled, level: level, residuals: residuals)
  }

  /// O atraso de cada quadro, em amostras: a reta mais o que cada bloco
  /// mediu além dela.
  ///
  /// O de cada bloco é a mediana dele com os vizinhos — um bloco com muita
  /// fala por cima pode achar outro pico — e entre os centros dos blocos o
  /// atraso anda em linha reta. Bloco sem medida herda o vizinho mais
  /// próximo que mediu.
  func refined(_ coarse: [Int], block: Int) -> [Int] {
    let measured = residuals.indices.compactMap { index in
      residuals[index].map { (index, $0) }
    }
    guard !measured.isEmpty else { return coarse }

    let smoothed = measured.indices.map { position -> (Float, Float) in
      let neighbors = measured[max(0, position - 1)...min(measured.count - 1, position + 1)]
        .map(\.1).sorted()
      let center = (Float(measured[position].0) + 0.5) * Float(block)
      return (center, Float(neighbors[neighbors.count / 2]))
    }

    var next = 0
    return coarse.indices.map { frame in
      let position = Float(frame)
      while next < smoothed.count, smoothed[next].0 <= position { next += 1 }
      let residual: Float
      if next == 0 {
        residual = smoothed[0].1
      } else if next == smoothed.count {
        residual = smoothed[smoothed.count - 1].1
      } else {
        let (a, ra) = smoothed[next - 1], (b, rb) = smoothed[next]
        residual = ra + (rb - ra) * (position - a) / max(1, b - a)
      }
      return coarse[frame] + Int(residual.rounded())
    }
  }
}

// MARK: - Terceira passada: a faixa limpa

private enum Suppressor {
  /// Escreve a faixa limpa em `url` e devolve a fração dos quadros com eco
  /// que foi ao chão de ruído.
  ///
  /// A decisão é **do quadro inteiro**: ou ele é eco e desce ao fundo da sala,
  /// ou ele tem você e passa como entrou. Tirar o eco frequência por
  /// frequência dentro de um quadro com você parecia o meio-termo certo, e era
  /// o que apagava a sua voz: o reconhecimento de fala perdia a frase inteira
  /// dita por cima de alguém, mesmo com 6 dB de folga sobre o eco. Com o
  /// quadro inteiro, a mesma frase saiu completa, e o eco dos trechos só da
  /// reunião continuou 35 a 45 dB abaixo.
  static func write(
    mic: AVAudioFile, reference: AVAudioFile, stft: EchoSTFT, frames: Int, delays: [Int],
    survey: Survey, presence: [Float], path: EchoPath, to url: URL
  ) throws -> Float {
    let bins = stft.bins
    let reach = EchoReach(bins: bins)
    let band = stft.speechBand
    var coherence = EchoCoherence(bins: bins)

    // O arquivo novo no mesmo formato do original — o transcritor escolheu
    // esse formato, e é o que ele vai ler.
    let output = try AVAudioFile(
      forWriting: url, settings: mic.fileFormat.settings,
      commonFormat: .pcmFormatFloat32, interleaved: false)
    // Falhar aqui é lançar, nunca voltar: o arquivo novo já existe, vazio, e
    // quem chama o poria no lugar da faixa.
    guard
      let block = AVAudioPCMBuffer(
        pcmFormat: output.processingFormat, frameCapacity: AVAudioFrameCount(stft.hop))
    else {
      throw NSError(
        domain: "EchoCanceller", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Formato de áudio inválido."])
    }

    var gains = [Float](repeating: 1, count: bins)
    var synthesized = [Float](repeating: 0, count: stft.size)
    var overlap = [Float](repeating: 0, count: stft.size)
    var remaining = Int(mic.length)
    var started = false
    var echoFrames = 0
    var silencedFrames = 0

    /// Reconstrói um quadro — no chão de ruído, se for eco — e escreve a
    /// metade dele que ficou pronta.
    func emit(_ held: Held, silence: Bool) throws {
      for bin in 0..<bins { gains[bin] = 1 }
      if silence {
        silencedFrames += 1
        // O piso é o fundo da sala, e não um número de dB: o reconhecimento
        // de fala normaliza o volume, e eco 30 dB abaixo do original, mas
        // acima do fundo, ainda saía transcrito.
        for bin in 0..<bins where held.power[bin] > 0 {
          gains[bin] = min(1, (survey.micFloor[bin] / held.power[bin]).squareRoot())
        }
      }

      stft.synthesize(held.spectrum, gains: gains, into: &synthesized)

      // Sobreposição de metade: o quadro novo soma com a metade de trás do
      // anterior, e a metade da frente sai pronta.
      for index in 0..<stft.size { overlap[index] += synthesized[index] }

      // O primeiro quadro só tem a metade de trás: a da frente é o
      // preenchimento antes da primeira amostra.
      if started, remaining > 0 {
        let count = min(stft.hop, remaining)
        block.frameLength = AVAudioFrameCount(count)
        let data = block.floatChannelData![0]
        for index in 0..<count { data[index] = max(-1, min(1, overlap[index])) }
        try output.write(from: block)
        remaining -= count
      }
      started = true

      overlap.removeFirst(stft.hop)
      overlap.append(contentsOf: repeatElement(0, count: stft.hop))
    }

    // Cada quadro espera o seguinte para ser decidido: a decisão final é a da
    // maioria entre ele e os dois vizinhos. Um quadro de 16 ms que escapava
    // sozinho no meio do eco não virava palavra, mas soava como estalo no
    // áudio guardado; e um quadro solto julgado eco no meio da sua fala
    // cortava uma sílaba.
    var held: Held?
    var before: Bool?

    try EchoFramePair.run(
      mic: mic, reference: reference, referenceDelay: { delays[$0] }, stft: stft,
      frames: frames
    ) { frame, pair in
      let echo = reach.push(pair.referencePower)
      coherence.push(mic: pair.mic, reference: pair.reference)
      let weight = Self.weight(presence[frame])

      var expected: Float = 0
      var measured: Float = 0
      var coherent: Float = 0
      var loud: Float = 0

      if weight > 0 {
        for bin in band {
          let power = pair.micPower[bin]
          expected += path.shape[bin] * path.level[frame] * weight * echo[bin]
          measured += max(0, power - survey.micFloor[bin])
          coherent += coherence.value(bin) * power
          loud += power
        }
      }

      // Sem eco esperado acima do fundo da sala, não há o que decidir.
      var isEcho = false
      if expected > survey.bandFloor {
        echoFrames += 1

        let margin = measured / expected
        let similarity = loud > 0 ? coherent / loud : 0
        isEcho =
          margin < EchoCanceller.nearEndMargin
          || (margin < EchoCanceller.coherentMargin && similarity > EchoCanceller.echoCoherence)
      }

      if let previous = held {
        let votes = [before ?? previous.isEcho, previous.isEcho, isEcho].filter { $0 }.count
        try emit(previous, silence: votes >= 2)
        before = previous.isEcho
      }
      held = Held(spectrum: pair.mic, power: pair.micPower, isEcho: isEcho)
    }

    if let last = held { try emit(last, silence: last.isEcho) }

    // A maioria pode silenciar um quadro vizinho que nem chegou a ser julgado.
    return echoFrames > 0 ? min(1, Float(silencedFrames) / Float(echoFrames)) : 0
  }

  /// Um quadro do microfone esperando a decisão.
  struct Held {
    var spectrum: EchoSpectrumFrame
    var power: [Float]
    var isEcho: Bool
  }

  /// Quanto da supressão vale, pela presença de eco em volta do quadro.
  static func weight(_ presence: Float) -> Float {
    let low = EchoCanceller.presenceLow, high = EchoCanceller.presenceHigh
    return max(0, min(1, (presence - low) / (high - low)))
  }
}

// MARK: - Peças

/// Quanto da referência pode estar soando no microfone agora: o quadro que
/// soou no mesmo instante, e a cauda da sala, que decai quadro a quadro
/// depois de a referência calar.
private final class EchoReach {
  private let bins: Int
  private let weights: [Float]
  private var history: [Float]
  private var scaled: [Float]
  private var echo: [Float]
  private var cursor = 0

  init(bins: Int) {
    self.bins = bins
    weights = (0...EchoCanceller.tailFrames).map { powf(EchoCanceller.tailDecay, Float($0)) }
    history = [Float](repeating: 0, count: bins * weights.count)
    scaled = [Float](repeating: 0, count: bins)
    echo = [Float](repeating: 0, count: bins)
  }

  func push(_ power: [Float]) -> [Float] {
    let rows = weights.count
    let length = vDSP_Length(bins)
    let row = cursor % rows

    history.withUnsafeMutableBufferPointer { history in
      let base = history.baseAddress!
      power.withUnsafeBufferPointer {
        (base + row * bins).update(from: $0.baseAddress!, count: bins)
      }

      vDSP_vclr(&echo, 1, length)
      for age in 0..<rows {
        let past = base + ((row - age + rows) % rows) * bins
        var weight = weights[age]
        vDSP_vsmul(past, 1, &weight, &scaled, 1, length)
        vDSP_vmax(echo, 1, scaled, 1, &echo, 1, length)
      }
    }

    cursor += 1
    return echo
  }
}

/// Quanto o microfone se parece com a referência, frequência por frequência.
///
/// A coerência ao quadrado, com médias de poucos quadros: 1 quando o microfone
/// é a referência vezes um número, 0 quando os dois não têm nada a ver. O eco
/// é a referência que passou por uma caixa e uma sala, e fica perto de 1; a
/// sua voz não tem a estrutura fina da referência, e fica perto de 0 mesmo
/// quando é tão alta quanto o eco.
private struct EchoCoherence {
  private var crossReal: [Float]
  private var crossImag: [Float]
  private var micPower: [Float]
  private var referencePower: [Float]

  /// Quanto do quadro anterior fica na média: uns 30 ms de memória.
  private static let memory: Float = 0.6

  init(bins: Int) {
    crossReal = [Float](repeating: 0, count: bins)
    crossImag = crossReal
    micPower = crossReal
    referencePower = crossReal
  }

  mutating func push(mic: EchoSpectrumFrame, reference: EchoSpectrumFrame) {
    let keep = Self.memory, add = 1 - Self.memory
    for bin in 0..<crossReal.count {
      let (micReal, micImag) = mic.at(bin)
      let (refReal, refImag) = reference.at(bin)
      crossReal[bin] = keep * crossReal[bin] + add * (micReal * refReal + micImag * refImag)
      crossImag[bin] = keep * crossImag[bin] + add * (micImag * refReal - micReal * refImag)
      micPower[bin] = keep * micPower[bin] + add * (micReal * micReal + micImag * micImag)
      referencePower[bin] =
        keep * referencePower[bin] + add * (refReal * refReal + refImag * refImag)
    }
  }

  func value(_ bin: Int) -> Float {
    let denominator = micPower[bin] * referencePower[bin]
    guard denominator > 0 else { return 0 }
    return min(1, (crossReal[bin] * crossReal[bin] + crossImag[bin] * crossImag[bin]) / denominator)
  }
}

/// O espectro complexo de um quadro, como o `zrip` o deixa: a frequência zero
/// e a de Nyquist dividem a primeira posição.
struct EchoSpectrumFrame {
  var real: [Float]
  var imag: [Float]

  init(bins: Int) {
    real = [Float](repeating: 0, count: bins - 1)
    imag = real
  }

  init(real: [Float], imag: [Float]) {
    self.real = real
    self.imag = imag
  }

  /// A frequência `bin`, de 0 a `bins - 1`.
  func at(_ bin: Int) -> (Float, Float) {
    if bin == 0 { return (real[0], 0) }
    if bin == real.count { return (imag[0], 0) }
    return (real[bin], imag[bin])
  }
}

/// As duas faixas no mesmo quadro: a potência de cada frequência e o espectro.
private struct EchoPair {
  var micPower: [Float]
  var referencePower: [Float]
  var mic: EchoSpectrumFrame
  var reference: EchoSpectrumFrame
}

/// Lê as duas faixas em quadros sobrepostos, lado a lado.
///
/// `referenceDelay` diz, para cada quadro, quantas amostras a referência é
/// atrasada (negativo adianta): é o que põe o quadro `t` do microfone ao lado
/// do quadro da referência que soou naquele instante.
private enum EchoFramePair {
  static func run(
    mic: AVAudioFile, reference: AVAudioFile, referenceDelay: (Int) -> Int, stft: EchoSTFT,
    frames: Int, body: (Int, EchoPair) throws -> Void
  ) throws {
    let micReader = try EchoHopReader(mic, delay: 0)
    let referenceReader = try EchoHopReader(reference, delay: referenceDelay(0))
    let referenceSTFT = EchoSTFT(sampleRate: stft.sampleRate)

    var micFrame = [Float](repeating: 0, count: stft.size)
    var referenceFrame = [Float](repeating: 0, count: stft.size)
    var pair = EchoPair(
      micPower: [Float](repeating: 0, count: stft.bins),
      referencePower: [Float](repeating: 0, count: stft.bins),
      mic: EchoSpectrumFrame(bins: stft.bins),
      reference: EchoSpectrumFrame(bins: stft.bins))

    for frame in 0..<frames {
      try micReader.advance(&micFrame, hop: stft.hop)
      try referenceReader.advance(&referenceFrame, hop: stft.hop, delay: referenceDelay(frame))
      stft.analyze(micFrame, power: &pair.micPower)
      referenceSTFT.analyze(referenceFrame, power: &pair.referencePower)
      pair.mic = stft.spectrum
      pair.reference = referenceSTFT.spectrum
      try body(frame, pair)
    }
  }
}

/// Lê uma faixa de `hop` em `hop` amostras, com zeros depois do fim.
private final class EchoHopReader {
  private let file: AVAudioFile
  private let buffer: AVAudioPCMBuffer
  private var cursor = 0
  private var zeros: Int
  private var skip = 0
  private var delay: Int
  private var ended = false

  /// `delay` positivo começa com esse tanto de zeros; negativo pula amostras.
  init(_ file: AVAudioFile, delay: Int) throws {
    self.file = file
    self.delay = delay
    file.framePosition = delay < 0 ? min(AVAudioFramePosition(-delay), file.length) : 0
    zeros = max(0, delay)
    guard
      let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 65_536)
    else {
      throw NSError(
        domain: "EchoCanceller", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Formato de áudio inválido."])
    }
    self.buffer = buffer
    buffer.frameLength = 0
  }

  /// Desliza o quadro `hop` amostras para a esquerda e completa com as
  /// seguintes.
  ///
  /// `delay`, quando muda, é cumprido aqui: atrasar mais é pôr zeros, atrasar
  /// menos é pular amostras. Só serve para a referência, que é medida e nunca
  /// ouvida — na faixa do microfone, isso seria um estalo.
  func advance(_ frame: inout [Float], hop: Int, delay target: Int? = nil) throws {
    if let target = target, target != delay {
      if target > delay { zeros += target - delay } else { skip += delay - target }
      let cancel = min(zeros, skip)
      zeros -= cancel
      skip -= cancel
      delay = target
    }

    let keep = frame.count - hop
    for index in 0..<keep { frame[index] = frame[index + hop] }

    var filled = keep
    while filled < frame.count {
      if skip > 0, !ended {
        if cursor >= Int(buffer.frameLength) {
          guard file.framePosition < file.length else {
            ended = true
            continue
          }
          buffer.frameLength = 0
          try file.read(into: buffer)
          cursor = 0
          if buffer.frameLength == 0 { ended = true }
          continue
        }
        let count = min(skip, Int(buffer.frameLength) - cursor)
        cursor += count
        skip -= count
        continue
      }

      if zeros > 0 {
        let count = min(zeros, frame.count - filled)
        for index in filled..<(filled + count) { frame[index] = 0 }
        zeros -= count
        filled += count
        continue
      }

      if cursor >= Int(buffer.frameLength) {
        if ended || file.framePosition >= file.length {
          ended = true
          for index in filled..<frame.count { frame[index] = 0 }
          return
        }
        buffer.frameLength = 0
        try file.read(into: buffer)
        cursor = 0
        if buffer.frameLength == 0 {
          ended = true
          continue
        }
      }

      let data = buffer.floatChannelData![0]
      let count = min(Int(buffer.frameLength) - cursor, frame.count - filled)
      for index in 0..<count { frame[filled + index] = data[cursor + index] }
      cursor += count
      filled += count
    }
  }
}

/// A transformada de quadros de ~32 ms com metade de sobreposição, e a volta.
///
/// Janela raiz de Hann na ida e na volta: o produto das duas é uma Hann, que
/// somada com metade de sobreposição dá exatamente 1. Com ganho 1 em tudo, a
/// faixa sai igual à que entrou.
final class EchoSTFT {
  let size: Int
  let hop: Int
  let bins: Int
  let sampleRate: Double

  private let log2n: vDSP_Length
  private let setup: FFTSetup
  private let window: [Float]
  private var windowed: [Float]
  private var real: [Float]
  private var imag: [Float]

  init(sampleRate: Double) {
    var size = 256
    while Double(size) < sampleRate * 0.032 { size *= 2 }

    self.size = size
    self.sampleRate = sampleRate
    hop = size / 2
    bins = size / 2 + 1
    log2n = vDSP_Length(log2(Double(size)))
    setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    window = (0..<size).map {
      (0.5 - 0.5 * cosf(2 * .pi * Float($0) / Float(size))).squareRoot()
    }
    windowed = [Float](repeating: 0, count: size)
    real = [Float](repeating: 0, count: size / 2)
    imag = [Float](repeating: 0, count: size / 2)
  }

  deinit { vDSP_destroy_fftsetup(setup) }

  /// A banda em que a fala vive e em que a caixa do notebook toca: 300 Hz a
  /// 3,4 kHz, como índices de frequência.
  var speechBand: Range<Int> {
    let resolution = sampleRate / Double(size)
    let first = max(1, Int(300 / resolution))
    let last = min(bins - 1, Int(3_400 / resolution))
    return first..<max(first + 1, last)
  }

  /// O espectro do último quadro analisado.
  var spectrum: EchoSpectrumFrame { EchoSpectrumFrame(real: real, imag: imag) }

  /// Transforma o quadro e escreve a potência de cada frequência.
  ///
  /// O espectro fica em [spectrum].
  func analyze(_ frame: [Float], power: inout [Float]) {
    vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(size))

    let half = size / 2
    real.withUnsafeMutableBufferPointer { realPointer in
      imag.withUnsafeMutableBufferPointer { imagPointer in
        var split = DSPSplitComplex(
          realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
        windowed.withUnsafeBufferPointer { input in
          input.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
            vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
          }
        }
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
      }
    }

    // O `zrip` guarda a frequência zero e a de Nyquist juntas na primeira
    // posição: a real é uma, a imaginária é a outra.
    power[0] = real[0] * real[0]
    power[half] = imag[0] * imag[0]
    for bin in 1..<half { power[bin] = real[bin] * real[bin] + imag[bin] * imag[bin] }
  }

  /// Um quadro analisado antes, com cada frequência multiplicada pelo ganho
  /// dela, de volta ao tempo e já janelado para a sobreposição.
  func synthesize(_ spectrum: EchoSpectrumFrame, gains: [Float], into output: inout [Float]) {
    let half = size / 2

    real[0] = spectrum.real[0] * gains[0]
    imag[0] = spectrum.imag[0] * gains[half]
    for bin in 1..<half {
      real[bin] = spectrum.real[bin] * gains[bin]
      imag[bin] = spectrum.imag[bin] * gains[bin]
    }

    inverse(into: &output)
    vDSP_vmul(output, 1, window, 1, &output, 1, vDSP_Length(size))
  }

  /// A volta ao tempo de um espectro dado por frequência (de 0 a `bins - 1`),
  /// sem janela.
  func inverse(real spectrumReal: [Float], imag spectrumImag: [Float]) -> [Float] {
    let half = size / 2
    real[0] = spectrumReal[0]
    imag[0] = spectrumReal[half]
    for bin in 1..<half {
      real[bin] = spectrumReal[bin]
      imag[bin] = spectrumImag[bin]
    }

    var output = [Float](repeating: 0, count: size)
    inverse(into: &output)
    return output
  }

  private func inverse(into output: inout [Float]) {
    let half = size / 2
    real.withUnsafeMutableBufferPointer { realPointer in
      imag.withUnsafeMutableBufferPointer { imagPointer in
        var split = DSPSplitComplex(
          realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
        output.withUnsafeMutableBufferPointer { out in
          out.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
            vDSP_ztoc(&split, 1, $0, 2, vDSP_Length(half))
          }
        }
      }
    }

    // Ida e volta do `zrip` multiplicam por 2 × tamanho.
    var scale = 1 / Float(2 * size)
    vDSP_vsmul(output, 1, &scale, &output, 1, vDSP_Length(size))
  }
}

/// Um histograma por frequência, para tirar percentis sem guardar cada
/// quadro de uma reunião de uma hora.
private struct LogHistogram {
  private let bins: Int
  private let low: Float
  private let step: Float
  private let slots: Int
  private var counts: [Int32]
  private var totals: [Int]

  init(bins: Int, low: Float, high: Float, step: Float) {
    self.bins = bins
    self.low = low
    self.step = step
    slots = Int((high - low) / step) + 1
    counts = [Int32](repeating: 0, count: bins * slots)
    totals = [Int](repeating: 0, count: bins)
  }

  mutating func add(_ bin: Int, _ value: Float) {
    guard value.isFinite else { return }
    let slot = max(0, min(slots - 1, Int((value - low) / step)))
    counts[bin * slots + slot] += 1
    totals[bin] += 1
  }

  func count(_ bin: Int) -> Int { totals[bin] }

  func quantile(_ bin: Int, _ fraction: Float) -> Float {
    let total = totals[bin]
    guard total > 0 else { return low }

    let wanted = Int32(Float(total) * fraction)
    var seen: Int32 = 0
    for slot in 0..<slots {
      seen += counts[bin * slots + slot]
      if seen > wanted { return low + (Float(slot) + 0.5) * step }
    }
    return low + Float(slots) * step
  }
}

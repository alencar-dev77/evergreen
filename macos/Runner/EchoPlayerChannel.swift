import AVFoundation
import FlutterMacOS

/// O player da reunião, na região de leitura do Echo.
///
/// Nativo porque Flutter não toca áudio sozinho: todo pacote de áudio é um
/// plugin com código nativo por baixo, e um a mais seria mais um para entrar
/// no callback de sub-janela e na fila da migração para SPM (ver o
/// `hotkey_manager` no AGENTS.md). O que se usa é pouco — abrir um `.m4a`,
/// tocar, pausar, saltar e dizer onde está —, e o `AVAudioPlayer` faz isso
/// lendo do disco, sem carregar a reunião inteira na memória.
///
/// **Um player por engine.** A instância mora na closure do canal, e a closure
/// mora no engine que a registrou: fechar o Hub destrói o engine, o canal, e o
/// player com eles — o áudio para junto com a janela, sem ninguém precisar
/// lembrar de parar. Um player estático continuaria tocando com o Hub fechado.
final class EchoPlayerChannel {
  static let channelName = "echo_player"

  private var player: AVAudioPlayer?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = EchoPlayerChannel()

    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "load":
      player?.stop()
      player = nil

      let path = arguments["path"] as? String ?? ""
      do {
        let loaded = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        loaded.prepareToPlay()
        player = loaded
        result(["durationMs": Int(loaded.duration * 1000)])
      } catch {
        result(FlutterError(
          code: "load_failed", message: error.localizedDescription, details: nil))
      }

    case "play":
      player?.play()
      result(nil)

    case "pause":
      player?.pause()
      result(nil)

    case "seek":
      if let player = player {
        let ms = (arguments["positionMs"] as? NSNumber)?.doubleValue ?? 0
        player.currentTime = max(0, min(player.duration, ms / 1000))
      }
      result(nil)

    case "status":
      guard let player = player else {
        result(["positionMs": 0, "isPlaying": false])
        return
      }
      result([
        "positionMs": Int(player.currentTime * 1000),
        "isPlaying": player.isPlaying,
      ])

    case "unload":
      player?.stop()
      player = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

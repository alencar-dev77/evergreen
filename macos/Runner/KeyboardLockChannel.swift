import ApplicationServices
import Carbon.HIToolbox
import Cocoa
import FlutterMacOS

/// O bloqueio de teclado do Awake: um `CGEventTap` na sessão que devolve `nil`
/// para toda tecla enquanto o bloqueio vale.
///
/// Não tem equivalente em Flutter — engolir tecla de **outros** apps só se faz
/// abaixo deles, no fluxo de eventos da sessão. O tap não lê o que foi
/// digitado: ele olha o tipo do evento e o descarta, e nada sai daqui além de
/// "bloqueado" ou "não deu".
///
/// Quatro tipos de evento são engolidos: tecla descendo, tecla subindo, as
/// modificadoras (`flagsChanged`) e as teclas de sistema (brilho, volume,
/// tocar), que chegam como `NSSystemDefined` de subtipo 8. O resto desse tipo
/// passa — o subtipo 7 são os botões extras do mouse, e o mouse é a saída do
/// bloqueio.
///
/// O tap roda numa thread própria, com run loop só dele. Na principal ele
/// dividiria a vez com o Flutter e os outros canais, e qualquer trecho de mais
/// de um segundo nela faria o sistema desligá-lo — com as teclas escapando até
/// o religamento.
///
/// Estático, como os outros canais: o bloqueio é do processo. Só a janela 0
/// registra o canal, porque é nela que mora quem decide quando ele acaba.
enum KeyboardLockChannel {
  private static let channelName = "keyboard_lock"

  /// `NSSystemDefined`.
  private static let systemDefinedType = CGEventType(rawValue: 14)!

  /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`: brilho, volume e mídia.
  private static let auxControlButtons: Int16 = 8

  private static var tap: CFMachPort?

  /// A run loop da thread do tap, para pará-la no desbloqueio.
  private static var loop: CFRunLoop?

  /// As teclas que estavam apertadas quando o bloqueio começou — o `t` do
  /// painel, por exemplo. A subida delas passa, senão o app que viu a descida
  /// ficaria achando que a tecla continua apertada.
  private static var heldAtLock = Set<Int64>()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "lock":
        result(lock())

      case "unlock":
        unlock()
        result(nil)

      case "isHolding":
        // Desligado pelo sistema e ainda não religado, ou com a entrada
        // segura ligada no meio do caminho: as teclas estão passando.
        let enabled = tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        result(enabled && !IsSecureEventInputEnabled())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `nil` quando bloqueou; senão, o motivo — que o Dart traduz em frase.
  ///
  /// Devolvido como valor, e não como `FlutterError`: não é falha, é o sistema
  /// dizendo por que não, e o painel mostra isso a quem pediu.
  private static func lock() -> String? {
    if tap != nil { return nil }

    // Sem a Acessibilidade o `tapCreate` devolve nil — mas perguntar antes dá
    // o motivo certo em vez de um "não deu" genérico.
    guard AXIsProcessTrusted() else { return "accessibility" }

    // Com a entrada segura ligada (um campo de senha com foco, o "Secure
    // Keyboard Entry" do Terminal) o macOS não entrega tecla a tap nenhum: o
    // bloqueio seria uma promessa vazia.
    if IsSecureEventInputEnabled() { return "secure_input" }

    let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, systemDefinedType]
    let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

    guard
      let created = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: { _, type, event, _ in KeyboardLockChannel.handle(type, event) },
        userInfo: nil
      )
    else { return "unavailable" }

    heldAtLock = Set(
      (0..<128).filter { CGEventSource.keyState(.combinedSessionState, key: CGKeyCode($0)) }
        .map { Int64($0) }
    )

    tap = created
    let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
    let ready = DispatchSemaphore(value: 0)
    let thread = Thread {
      let current = CFRunLoopGetCurrent()
      CFRunLoopAddSource(current, loopSource, .commonModes)
      loop = current
      ready.signal()
      CFRunLoopRun()
    }
    thread.name = "Evergreen: bloqueio de teclado"
    thread.qualityOfService = .userInteractive
    thread.start()
    ready.wait()

    CGEvent.tapEnable(tap: created, enable: true)
    return nil
  }

  private static func unlock() {
    guard let current = tap else { return }

    CGEvent.tapEnable(tap: current, enable: false)
    // Invalidar a porta tira a source da run loop; parar a run loop termina a
    // thread do tap.
    CFMachPortInvalidate(current)
    if let threadLoop = loop { CFRunLoopStop(threadLoop) }

    tap = nil
    loop = nil
    heldAtLock.removeAll()
  }

  private static func handle(
    _ type: CGEventType,
    _ event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      // O sistema desliga o tap que demorou a responder. Bloqueado, ele volta
      // na hora: um teclado que "escapa" no meio do bloqueio é o defeito que
      // este canal existe para não ter.
      if let current = tap { CGEvent.tapEnable(tap: current, enable: true) }
      return Unmanaged.passUnretained(event)

    case systemDefinedType:
      let subtype = NSEvent(cgEvent: event)?.subtype.rawValue
      return subtype == auxControlButtons ? nil : Unmanaged.passUnretained(event)

    case .keyUp, .flagsChanged:
      let key = event.getIntegerValueField(.keyboardEventKeycode)
      if heldAtLock.contains(key) {
        heldAtLock.remove(key)
        return Unmanaged.passUnretained(event)
      }
      return nil

    default:
      return nil
    }
  }
}

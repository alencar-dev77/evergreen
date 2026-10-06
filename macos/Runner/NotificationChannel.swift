import Cocoa
import FlutterMacOS
import UserNotifications

/// Notificações locais do Evergreen: fim de sessão do Focus, fim do prazo do
/// Awake e o resumo da semana do Track.
///
/// Nativo porque não há caminho em Flutter puro, e escrito à mão em vez do
/// `flutter_local_notifications` por três razões: o pacote seria mais um
/// plugin para acompanhar a migração para SPM (ver o `hotkey_manager` no
/// AGENTS.md), entraria no callback de sub-janela sem que o Hub precise dele, e
/// o que se usa aqui — postar, receber o clique e mostrar com o app à frente —
/// cabe neste arquivo.
///
/// **Local, nunca push**: nada aqui fala com o APNs, então não há
/// entitlement nem conta de desenvolvedor envolvidos. A permissão é guardada
/// pelo macOS contra o bundle id, e é a assinatura estável do
/// `run_build_copy` que a faz sobreviver às builds.
///
/// Só a janela 0 registra este canal: o centro de notificações tem **um**
/// delegate por processo, e quem trata o clique (abrir um painel, começar a
/// pausa) são os serviços que vivem naquele engine.
final class NotificationChannel: NSObject, UNUserNotificationCenterDelegate {
  private static let channelName = "notifications"
  private static let shared = NotificationChannel()
  private static var channel: FlutterMethodChannel?

  /// Categorias já entregues ao sistema, pelo identificador. Os botões de uma
  /// notificação moram na categoria, e `setNotificationCategories` substitui o
  /// conjunto inteiro — por isso o conjunto é guardado e reenviado completo.
  private static var categories: [String: UNNotificationCategory] = [:]

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    self.channel = channel
    UNUserNotificationCenter.current().delegate = shared

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "post":
        post(call.arguments as? [String: Any] ?? [:], result: result)
      case "cancel":
        let ids = call.arguments as? [String] ?? []
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Pede a permissão na primeira notificação, e não na abertura do app: a
  /// pergunta faz sentido no instante em que existe algo para avisar.
  private static func post(_ args: [String: Any], result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()

    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        deliver(args, result: result)
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
          if granted {
            deliver(args, result: result)
          } else {
            DispatchQueue.main.async { result(false) }
          }
        }
      default:
        DispatchQueue.main.async { result(false) }
      }
    }
  }

  private static func deliver(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String, let title = args["title"] as? String else {
      DispatchQueue.main.async { result(false) }
      return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.subtitle = args["subtitle"] as? String ?? ""
    content.body = args["body"] as? String ?? ""
    content.threadIdentifier = args["thread"] as? String ?? ""
    content.userInfo = ["id": id]
    if args["sound"] as? Bool ?? false { content.sound = .default }

    if let path = args["image"] as? String,
       let attachment = try? UNNotificationAttachment(
         identifier: "image",
         url: URL(fileURLWithPath: path),
         options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
       ) {
      content.attachments = [attachment]
    }

    let actions = (args["actions"] as? [[String: String]] ?? []).compactMap {
      action -> UNNotificationAction? in
      guard let id = action["id"], let title = action["title"] else { return nil }
      return UNNotificationAction(identifier: id, title: title, options: [])
    }

    if !actions.isEmpty {
      let categoryId = "eg." + actions.map(\.identifier).joined(separator: "+")
      if categories[categoryId] == nil {
        categories[categoryId] = UNNotificationCategory(
          identifier: categoryId,
          actions: actions,
          intentIdentifiers: [],
          options: []
        )
        UNUserNotificationCenter.current()
          .setNotificationCategories(Set(categories.values))
      }
      content.categoryIdentifier = categoryId
    }

    // Com `at`, a notificação é **agendada no sistema** — o lembrete do Leaf.
    // É o macOS quem dispara na hora, e não um `Timer` do Dart: o relógio do
    // processo para quando o Mac dorme, e um lembrete das 15h que acordasse às
    // 15h40 junto com a tampa não seria lembrete.
    var trigger: UNNotificationTrigger?
    if let at = args["at"] as? NSNumber {
      let date = Date(timeIntervalSince1970: at.doubleValue / 1000)
      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: date
      )
      trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    // O identificador da notificação é o do assunto: um fim de sessão novo
    // substitui o anterior em vez de empilhar avisos do mesmo cronômetro — e
    // reagendar um lembrete troca o que estava marcado.
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
      DispatchQueue.main.async { result(error == nil) }
    }
  }

  /// Mostra o aviso mesmo com o Evergreen à frente — o padrão do macOS é
  /// engoli-lo, e o Hub aberto não pode ser motivo para perder o fim do foco.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let id = response.notification.request.content.userInfo["id"] as? String
      ?? response.notification.request.identifier

    let action: String?
    switch response.actionIdentifier {
    case UNNotificationDefaultActionIdentifier: action = nil
    case UNNotificationDismissActionIdentifier: action = "dismiss"
    default: action = response.actionIdentifier
    }

    DispatchQueue.main.async {
      Self.channel?.invokeMethod("onResponse", arguments: ["id": id, "action": action as Any])
      completionHandler()
    }
  }
}

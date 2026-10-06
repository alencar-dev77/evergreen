import 'package:evergreen/core/system/notification_service.dart';

/// Centro de notificações em memória: guarda o que foi mostrado, agendado e
/// cancelado, para o teste conferir.
class FakeNotificationService implements NotificationService {
  final posted = <EgNotification>[];

  /// O que está agendado agora, pelo id — agendar de novo substitui, como no
  /// sistema.
  final scheduled = <String, (EgNotification, DateTime)>{};

  final cancelled = <String>[];

  @override
  Future<bool> post(EgNotification notification) async {
    posted.add(notification);
    return true;
  }

  @override
  Future<bool> schedule(EgNotification notification, DateTime at) async {
    scheduled[notification.id] = (notification, at);
    return true;
  }

  @override
  Future<void> cancel(List<String> ids) async {
    cancelled.addAll(ids);
    ids.forEach(scheduled.remove);
  }

  @override
  Stream<EgNotificationResponse> get responses => const Stream.empty();
}

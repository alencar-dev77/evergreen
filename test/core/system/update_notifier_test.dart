import 'package:evergreen/core/system/update_notifier.dart';
import 'package:evergreen/core/system/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/fake_notification_service.dart';

/// O aviso de versão nova: uma vez por versão, nunca para quem acabou de
/// procurar, e tirado do sistema quando o app vai instalar.
void main() {
  late SharedPreferences preferences;
  late FakeNotificationService notifications;
  late UpdateNotifier notifier;

  const notes = [
    UpdateNote.heading('1.1.14'),
    UpdateNote.item('Exportar a reunião em PDF'),
    UpdateNote.item('Ajustes internos no instalador'),
  ];

  UpdateState found(String version) =>
      UpdateState(phase: UpdatePhase.available, version: version, notes: notes);

  UpdateNotifier restart() =>
      UpdateNotifier(preferences: preferences, notifications: notifications);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    notifications = FakeNotificationService();
    notifier = restart();
  });

  test('avisa a versão achada pela procura diária', () async {
    await notifier.observe(const UpdateState());
    await notifier.observe(found('1.1.14'));

    expect(notifications.posted, hasLength(1));
    final posted = notifications.posted.single;
    expect(posted.id, UpdateNotifications.id);
    expect(posted.title, 'Evergreen 1.1.14 disponível');
    expect(posted.body, 'Exportar a reunião em PDF — e mais 1 novidade.');
  });

  test('a mesma versão não instalada não avisa de novo', () async {
    // A primeira leitura e o aviso do canal trazem o mesmo estado.
    await notifier.observe(found('1.1.14'));
    await notifier.observe(found('1.1.14'));

    // "Agora não", o app reaberto e a procura diária que acha a mesma versão.
    final restarted = restart();
    await restarted.observe(const UpdateState());
    await restarted.observe(found('1.1.14'));

    // Uma instalação que falhou, e a procura seguinte.
    await restarted.observe(const UpdateState(phase: UpdatePhase.error));
    await restarted.observe(found('1.1.14'));

    expect(notifications.posted, hasLength(1));
  });

  test('uma versão mais nova avisa de novo', () async {
    await notifier.observe(found('1.1.14'));

    final restarted = restart();
    await restarted.observe(const UpdateState());
    await restarted.observe(found('1.1.15'));

    expect(notifications.posted.map((n) => n.title), [
      'Evergreen 1.1.14 disponível',
      'Evergreen 1.1.15 disponível',
    ]);
  });

  test('quem clicou em "Procurar" não é avisado — nem depois', () async {
    await notifier.observe(const UpdateState(phase: UpdatePhase.checking));
    await notifier.observe(found('1.1.14'));

    final restarted = restart();
    await restarted.observe(found('1.1.14'));

    expect(notifications.posted, isEmpty);
  });

  test('instalando, o aviso sai do Centro de Notificações', () async {
    await notifier.observe(found('1.1.14'));
    await notifier.observe(
      const UpdateState(phase: UpdatePhase.installing, version: '1.1.14'),
    );

    expect(notifications.cancelled, [UpdateNotifications.id]);
  });

  test('sem novidades, o texto convida a ver o que mudou', () {
    expect(
      UpdateNotifications.body(const []),
      'Veja o que mudou e atualize quando quiser.',
    );
    expect(
      UpdateNotifications.body(const [UpdateNote.item('Uma coisa')]),
      'Uma coisa',
    );
  });
}

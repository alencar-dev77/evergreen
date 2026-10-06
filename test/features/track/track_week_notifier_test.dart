import 'package:evergreen/features/home/data/app_settings_repository.dart';
import 'package:evergreen/features/track/data/track_week_notifier.dart';
import 'package:evergreen/features/track/models/track_day.dart';
import 'package:evergreen/features/track/models/track_week_digest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/fake_notification_service.dart';
import 'fake_track_repository.dart';

/// O resumo da semana: avisa uma vez por semana, sobre a semana que acabou, e
/// só quando ela teve alguma coisa.
void main() {
  /// Segunda-feira, 5 de outubro de 2026 — a semana passada vai de 28 set a
  /// 4 out.
  final monday = DateTime(2026, 10, 5, 8, 30);
  final lastMonday = DateTime(2026, 9, 28);

  TrackEntry entry(int minutes) => TrackEntry(
    at: lastMonday,
    duration: Duration(minutes: minutes),
  );

  final lastWeek = [
    TrackDay(date: lastMonday, focus: [entry(50), entry(25)]),
    TrackDay(
      date: DateTime(2026, 9, 30),
      focus: [entry(120)],
      meetings: [entry(60)],
    ),
    // Desta semana: não entra no resumo da passada.
    TrackDay(date: DateTime(2026, 10, 5), focus: [entry(500)]),
  ];

  late SharedPreferences preferences;
  late FakeNotificationService notifications;
  late DateTime now;

  Future<TrackWeekNotifier> notifierFor(
    List<TrackDay> days, {
    Map<String, Object> initial = const {
      'track.week_digest_sent': '2026-09-28',
    },
  }) async {
    SharedPreferences.setMockInitialValues({
      ...initial,
      'app.user_name': 'Lucas',
    });
    preferences = await SharedPreferences.getInstance();
    notifications = FakeNotificationService();
    now = monday;

    return TrackWeekNotifier(
      repository: FakeTrackRepository(days),
      preferences: preferences,
      appSettings: AppSettingsRepository(preferences),
      notifications: notifications,
      clock: () => now,
      chart: (_) async => '/tmp/semana.png',
    );
  }

  test('na virada da semana, avisa sobre a semana passada', () async {
    final notifier = await notifierFor(lastWeek);

    await notifier.check(enabled: true);

    final posted = notifications.posted.single;
    expect(posted.id, TrackWeekDigest.id);
    expect(posted.title, 'Lucas, sua semana passada');
    expect(posted.subtitle, '28 set – 4 out');
    expect(
      posted.body,
      '4h 15min registradas — 3h 15min de foco em 3 sessões e 1h em '
      '1 reunião. Seu melhor dia foi quarta, com 3h.',
    );
    expect(posted.imagePath, '/tmp/semana.png');
  });

  test('avisa uma vez só por semana', () async {
    final notifier = await notifierFor(lastWeek);

    await notifier.check(enabled: true);
    now = monday.add(const Duration(days: 3));
    await notifier.check(enabled: true);

    expect(notifications.posted, hasLength(1));
  });

  test('a primeira verificação da instalação não avisa', () async {
    final notifier = await notifierFor(lastWeek, initial: const {});

    await notifier.check(enabled: true);

    expect(notifications.posted, isEmpty);
    expect(preferences.getString('track.week_digest_sent'), '2026-10-05');
  });

  test('com o Track desligado, a vez é consumida sem avisar', () async {
    final notifier = await notifierFor(lastWeek);

    await notifier.check(enabled: false);
    await notifier.check(enabled: true);

    expect(notifications.posted, isEmpty);
  });

  test('semana vazia não vira notificação', () async {
    final notifier = await notifierFor([
      TrackDay(date: DateTime(2026, 10, 5), focus: [entry(30)]),
    ]);

    await notifier.check(enabled: true);

    expect(notifications.posted, isEmpty);
  });

  test('sem tempo registrado, conta o resto', () {
    final digest = TrackWeekDigest.of([
      TrackDay(date: DateTime(2026, 9, 29), notesWritten: 2, filesOrganized: 1),
    ], weekStart: lastMonday)!;

    expect(
      digest.body,
      'Nenhum foco ou reunião registrado, mas 2 anotações e '
      '1 arquivo organizado.',
    );
    expect(digest.bestDay, isNull);
    expect(digest.title(''), 'Sua semana passada');
  });
}

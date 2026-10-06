import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/system/notification_service.dart';
import '../../../shared/utils/day_bounds.dart';
import '../../home/data/app_settings_repository.dart';
import '../models/track_week_digest.dart';
import 'track_repository.dart';
import 'track_week_chart.dart';

/// Avisa, uma vez por semana, como foi a semana que acabou.
///
/// Não é uma notificação agendada no sistema: o texto depende do que foi
/// gravado até domingo à noite, e uma agendada teria de ser escrita antes
/// disso. O Evergreen fica aberto o dia inteiro na barra de menus, então quem
/// o chama é uma verificação barata de tempos em tempos — a primeira que cair
/// numa semana nova é a que avisa.
///
/// **Cedo, e não às nove da manhã**: o histórico do Focus zera na primeira
/// sessão da semana (`trimToCurrentWeek`), e um resumo montado depois disso
/// diria que a semana passada não teve foco nenhum.
class TrackWeekNotifier {
  TrackWeekNotifier({
    required TrackRepository repository,
    required SharedPreferences preferences,
    required AppSettingsRepository appSettings,
    required NotificationService notifications,
    required DateTime Function() clock,
    Future<String?> Function(TrackWeekDigest digest)? chart,
  }) : _repository = repository,
       _preferences = preferences,
       _appSettings = appSettings,
       _notifications = notifications,
       _clock = clock,
       _chart = chart ?? TrackWeekChart.render;

  final TrackRepository _repository;
  final SharedPreferences _preferences;
  final AppSettingsRepository _appSettings;
  final NotificationService _notifications;
  final DateTime Function() _clock;
  final Future<String?> Function(TrackWeekDigest digest) _chart;

  /// A segunda-feira da última semana já avisada, em `aaaa-mm-dd`.
  static const _key = 'track.week_digest_sent';

  /// Avisa sobre a semana passada, se esta semana ainda não foi avisada.
  ///
  /// [enabled] falso (o Track desligado) consome a vez sem avisar: religar o
  /// módulo na quinta-feira não pode disparar o resumo de segunda.
  Future<void> check({required bool enabled}) async {
    final thisWeek = DayBounds.startOfWeek(_clock());
    final stamp = _stamp(thisWeek);
    final sent = _preferences.getString(_key);
    if (sent == stamp) return;

    // Marcado antes de montar o resumo: duas verificações cruzadas não podem
    // avisar duas vezes.
    await _preferences.setString(_key, stamp);

    // Primeira vez nesta instalação: a semana passada pode já ter perdido o
    // foco para o `trimToCurrentWeek`, e um resumo pela metade é pior que
    // nenhum. O primeiro aviso é o da próxima segunda.
    if (sent == null || !enabled) return;

    final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);
    final days = _repository
        .loadDays(since: lastWeek)
        .where((day) => day.date.isBefore(thisWeek))
        .toList();

    final digest = TrackWeekDigest.of(days, weekStart: lastWeek);
    if (digest == null) return;

    await _appSettings.reload();
    await _notifications.post(
      digest.notification(
        userName: _appSettings.load().userName,
        imagePath: await _chart(digest),
      ),
    );
  }

  static String _stamp(DateTime monday) =>
      monday.toIso8601String().substring(0, 10);
}

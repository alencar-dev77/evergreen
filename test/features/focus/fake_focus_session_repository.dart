import 'package:evergreen/features/focus/data/focus_session_repository.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';

/// Repositório em memória com a mesma ordenação e as mesmas janelas de tempo do
/// SQLite: mais recentes primeiro, "hoje" a partir da meia-noite e a semana a
/// partir da segunda-feira.
class FakeFocusSessionRepository implements FocusSessionRepository {
  FakeFocusSessionRepository([List<FocusSession> initial = const []])
    : _sessions = [...initial];

  final List<FocusSession> _sessions;

  int _nextId = 1000;

  @override
  List<FocusSession> loadRecent({int limit = 50, DateTime? now}) {
    final weekStart = SqliteFocusSessionRepository.startOfWeek(
      now ?? DateTime.now(),
    );

    final sorted =
        _sessions
            .where((session) => !session.startedAt.isBefore(weekStart))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return sorted.take(limit).toList(growable: false);
  }

  @override
  FocusSession insert(FocusSession session) {
    final created = session.copyWith(id: _nextId++);
    _sessions.add(created);
    return created;
  }

  @override
  void setSummary(int id, String? summary) {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;

    _sessions[index] = _sessions[index].copyWith(summary: summary);
  }

  @override
  void delete(int id) => _sessions.removeWhere((session) => session.id == id);

  @override
  void clearAll() => _sessions.clear();

  @override
  void trimOldWeeks({DateTime? now}) {
    final keptSince = FocusSessionRepository.keptSince(now ?? DateTime.now());

    _sessions.removeWhere((session) => session.startedAt.isBefore(keptSince));
  }

  @override
  FocusStats stats({DateTime? now}) {
    final moment = now ?? DateTime.now();
    final today = _startOfDay(moment);
    final weekStart = SqliteFocusSessionRepository.startOfWeek(moment);

    return FocusStats(
      today: _sum((session) => !session.startedAt.isBefore(today)),
      week: _sum((session) => !session.startedAt.isBefore(weekStart)),
    );
  }

  Duration _sum(bool Function(FocusSession session) test) {
    return _sessions
        .where(test)
        .fold(Duration.zero, (total, session) => total + session.duration);
  }

  static DateTime _startOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);
}

import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_run.dart';
import '../models/focus_session_note.dart';

/// Persistência do rastro da sessão em andamento (ver [FocusRun]).
///
/// `SharedPreferences`, e não o banco: é **um** registro, que se sobrescreve a
/// cada batimento e some quando a sessão acaba. O banco guarda histórico — o
/// que entra lá é sessão terminada, e uma linha em andamento ali obrigaria toda
/// consulta do histórico a saber que existe uma linha que não conta.
///
/// Também é o que garante a leitura na hora certa: as preferências já estão
/// carregadas quando o `EvergreenBootstrap` sobe, antes de qualquer janela.
class FocusRunRepository {
  FocusRunRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _startedAtKey = 'focus.run.started_at';
  static const _focusedSecondsKey = 'focus.run.focused_seconds';
  static const _activityKey = 'focus.run.activity';
  static const _notesKey = 'focus.run.notes';

  /// O rastro deixado pela última sessão, ou `null` se não há nenhum.
  FocusRun? load() {
    final startedAt = _prefs.getInt(_startedAtKey);
    if (startedAt == null) return null;

    return FocusRun(
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
      focused: Duration(seconds: _prefs.getInt(_focusedSecondsKey) ?? 0),
      activity: _prefs.getString(_activityKey) ?? '',
      notes: FocusSessionNote.decodeList(_prefs.getString(_notesKey)),
    );
  }

  Future<void> save(FocusRun run) async {
    await Future.wait([
      _prefs.setInt(_startedAtKey, run.startedAt.millisecondsSinceEpoch),
      _prefs.setInt(_focusedSecondsKey, run.focused.inSeconds),
      _prefs.setString(_activityKey, run.activity),
      _prefs.setString(_notesKey, FocusSessionNote.encodeList(run.notes) ?? ''),
    ]);
  }

  /// Apaga o rastro. Chamado sempre que a sessão termina por um caminho normal
  /// — o que já foi registrado no histórico não pode ser registrado de novo na
  /// abertura seguinte.
  Future<void> clear() async {
    await Future.wait([
      _prefs.remove(_startedAtKey),
      _prefs.remove(_focusedSecondsKey),
      _prefs.remove(_activityKey),
      _prefs.remove(_notesKey),
    ]);
  }
}

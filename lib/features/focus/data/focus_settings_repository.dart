import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_settings.dart';

/// Persistência das preferências do Focus.
///
/// Mesmo motivo do Pin: são poucas e pequenas, então `SharedPreferences`
/// (plist nativo no macOS) é mais adequado que o banco — e continua local.
class FocusSettingsRepository {
  FocusSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _focusMinutesKey = 'focus.focus_minutes';
  static const _breakMinutesKey = 'focus.break_minutes';
  static const _pomodoroOnlyKey = 'focus.pomodoro_only';
  static const _askActivityKey = 'focus.ask_activity';
  static const _askSummaryKey = 'focus.ask_summary';
  static const _playSoundKey = 'focus.play_sound';
  static const _alertOnScreenKey = 'focus.alert_on_screen';

  FocusSettings load() {
    const defaults = FocusSettings();

    return FocusSettings(
      focusMinutes: _prefs.getInt(_focusMinutesKey) ?? defaults.focusMinutes,
      breakMinutes: _prefs.getInt(_breakMinutesKey) ?? defaults.breakMinutes,
      pomodoroOnly: _prefs.getBool(_pomodoroOnlyKey) ?? defaults.pomodoroOnly,
      askActivity: _prefs.getBool(_askActivityKey) ?? defaults.askActivity,
      askSummary: _prefs.getBool(_askSummaryKey) ?? defaults.askSummary,
      playSound: _prefs.getBool(_playSoundKey) ?? defaults.playSound,
      alertOnScreen:
          _prefs.getBool(_alertOnScreenKey) ?? defaults.alertOnScreen,
    );
  }

  /// Relê o plist nativo antes de responder.
  ///
  /// As preferências são editadas no Hub, que roda em outro engine Flutter —
  /// sem isso o painel do Focus continuaria usando a duração antiga até o app
  /// ser relançado.
  Future<void> reload() => _prefs.reload();

  Future<void> save(FocusSettings settings) async {
    await Future.wait([
      _prefs.setInt(_focusMinutesKey, settings.focusMinutes),
      _prefs.setInt(_breakMinutesKey, settings.breakMinutes),
      _prefs.setBool(_pomodoroOnlyKey, settings.pomodoroOnly),
      _prefs.setBool(_askActivityKey, settings.askActivity),
      _prefs.setBool(_askSummaryKey, settings.askSummary),
      _prefs.setBool(_playSoundKey, settings.playSound),
      _prefs.setBool(_alertOnScreenKey, settings.alertOnScreen),
    ]);
  }
}

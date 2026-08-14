import 'package:shared_preferences/shared_preferences.dart';

import '../models/echo_settings.dart';
import '../models/transcription_language.dart';

/// Preferências do Echo em `shared_preferences`.
class EchoSettingsRepository {
  EchoSettingsRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _liveTranscriptionKey = 'echo.liveTranscription';
  static const _languageKey = 'echo.language';
  static const _instructionsKey = 'echo.summaryInstructions';
  static const _historyLimitKey = 'echo.historyLimit';

  EchoSettings load() {
    const fallback = EchoSettings();

    return EchoSettings(
      liveTranscription:
          _preferences.getBool(_liveTranscriptionKey) ?? fallback.liveTranscription,
      language: TranscriptionLanguage.fromLocale(
        _preferences.getString(_languageKey) ?? fallback.language.locale,
      ),
      summaryInstructions:
          _preferences.getString(_instructionsKey) ?? fallback.summaryInstructions,
      historyLimit: _preferences.getInt(_historyLimitKey) ?? fallback.historyLimit,
    );
  }

  Future<void> save(EchoSettings settings) async {
    await _preferences.setBool(_liveTranscriptionKey, settings.liveTranscription);
    await _preferences.setString(_languageKey, settings.language.locale);
    await _preferences.setString(_instructionsKey, settings.summaryInstructions);
    await _preferences.setInt(_historyLimitKey, settings.historyLimit);
  }

  /// Relê do disco.
  ///
  /// As preferências do Echo são editadas no Hub, que roda em outro engine — o
  /// engine da janela flutuante precisa reler antes de gravar ou de resumir,
  /// senão usa a instrução antiga. É a mesma armadilha que o auto-colar do Pin
  /// já tinha caído.
  Future<void> reload() => _preferences.reload();
}

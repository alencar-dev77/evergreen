import 'package:shared_preferences/shared_preferences.dart';

import '../models/awake_duration.dart';
import '../models/awake_mode.dart';
import '../models/awake_settings.dart';

/// Persistência das preferências do Awake.
///
/// Mesmo motivo do Pin e do Focus: são poucas e pequenas, então
/// `SharedPreferences` (plist nativo no macOS) basta — e continua local.
class AwakeSettingsRepository {
  AwakeSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _defaultDurationKey = 'awake.default_duration';
  static const _modeKey = 'awake.mode';

  AwakeSettings load() => AwakeSettings(
    defaultDuration: AwakeDuration.fromName(
      _prefs.getString(_defaultDurationKey),
    ),
    mode: AwakeMode.fromName(_prefs.getString(_modeKey)),
  );

  /// Relê o plist nativo antes de responder — a preferência é editada no Hub,
  /// que roda em outro engine Flutter.
  Future<void> reload() => _prefs.reload();

  Future<void> save(AwakeSettings settings) async {
    await Future.wait([
      _prefs.setString(_defaultDurationKey, settings.defaultDuration.name),
      _prefs.setString(_modeKey, settings.mode.name),
    ]);
  }
}

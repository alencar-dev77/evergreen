import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/nest_destination.dart';
import '../models/nest_settings.dart';
import '../models/nest_transfer_mode.dart';

/// Persistência das preferências do Nest.
///
/// Mesmo motivo do Pin, do Focus e do Awake: são poucas e pequenas, então
/// `SharedPreferences` (plist nativo no macOS) basta — e continua local.
///
/// Os destinos vão em JSON, e não no formato `campo|campo` das observações do
/// Focus, porque um deles é um caminho de arquivo: `/Users/eu/Pastas|estranhas`
/// é um nome de pasta perfeitamente válido, e qualquer separador que se
/// escolhesse poderia estar dentro do dado.
class NestSettingsRepository {
  NestSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _defaultModeKey = 'nest.default_mode';
  static const _useNotchKey = 'nest.use_notch';
  static const _destinationsKey = 'nest.destinations';

  NestSettings load() => NestSettings(
    defaultMode: NestTransferMode.fromName(_prefs.getString(_defaultModeKey)),
    useNotch: _prefs.getBool(_useNotchKey) ?? true,
    destinations: _readDestinations(),
  );

  /// Relê o plist nativo antes de responder — as preferências são editadas no
  /// Hub, que roda em outro engine Flutter, e quem as usa é o painel, que roda
  /// na janela 0.
  Future<void> reload() => _prefs.reload();

  Future<void> save(NestSettings settings) async {
    await Future.wait([
      _prefs.setString(_defaultModeKey, settings.defaultMode.name),
      _prefs.setBool(_useNotchKey, settings.useNotch),
      _prefs.setStringList(_destinationsKey, [
        for (final destination in settings.destinations)
          jsonEncode(destination.toJson()),
      ]),
    ]);
  }

  List<NestDestination> _readDestinations() {
    final stored = _prefs.getStringList(_destinationsKey);
    if (stored == null) return const [];

    final destinations = <NestDestination>[];

    for (final line in stored) {
      // Uma linha ilegível não derruba as outras: a pasta some da lista e o
      // resto continua de pé. O caso real é uma versão futura que grave um
      // campo a mais e alguém volte para esta.
      try {
        final json = jsonDecode(line);
        if (json is! Map<String, Object?>) continue;

        final destination = NestDestination.fromJson(json);
        if (destination != null) destinations.add(destination);
      } on FormatException {
        continue;
      }
    }

    return destinations;
  }
}

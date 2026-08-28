import 'package:shared_preferences/shared_preferences.dart';

/// Guarda qual build já mostrou a abertura animada do Hub.
///
/// Fica ao lado do [AppSettingsRepository] e usa o mesmo prefixo `app.` — é do
/// aplicativo, não de módulo nenhum —, mas **não** entra no `AppSettings`. O
/// motivo é o que aquele modelo é: um punhado de preferências que a pessoa liga
/// e desliga numa tela, salvas em bloco a cada mexida. Isto aqui é estado
/// interno, ninguém escolhe e nada mostra; misturar os dois faria cada toggle
/// reescrever o carimbo e daria à tela de preferências um campo que ela nunca
/// vai desenhar.
class HubIntroRepository {
  HubIntroRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _lastSeenBuildKey = 'app.last_seen_build';

  /// A abertura roda uma vez por build instalada.
  ///
  /// Carimbo vazio nunca mostra: vazio é "não consegui ler o executável", e
  /// nesse caso a resposta certa é não fazer nada em vez de animar a cada
  /// abertura para sempre.
  bool shouldShow(String stamp) =>
      stamp.isNotEmpty && _prefs.getString(_lastSeenBuildKey) != stamp;

  /// Gravado **depois** de a animação terminar, nunca ao começar: quem fecha o
  /// Hub no meio do giro não viu a marca, e merece vê-la na próxima abertura.
  Future<void> markSeen(String stamp) =>
      _prefs.setString(_lastSeenBuildKey, stamp);
}

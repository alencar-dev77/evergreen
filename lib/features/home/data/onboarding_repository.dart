import 'package:shared_preferences/shared_preferences.dart';

/// Liga a apresentação de boas-vindas em **toda** abertura do Hub.
///
/// É uma alavanca de desenvolvimento, e nasce `false` de propósito: a
/// apresentação é para quem acabou de instalar ou atualizar, e roda uma vez
/// por build. Ligue aqui para trabalhar nela sem precisar apagar preferência
/// nenhuma; **não suba com `true`**.
///
/// Ligada, ela também impede que a apresentação se marque como vista — senão
/// desligá-la depois deixaria você sem conseguir vê-la de novo pelo caminho
/// normal.
const bool kAlwaysShowOnboarding = false;

/// Guarda qual build já mostrou a apresentação de boas-vindas.
///
/// A mesma régua da abertura animada do Hub (`HubIntroRepository`): **uma vez
/// por build instalada**. Quem instala vê; quem atualiza vê de novo, porque a
/// versão nova pode ter painel novo (foi assim que o Nest entrou nela); e quem
/// builda com o `run_build_copy` vê a cada build, que é quando ela mais precisa
/// ser conferida. Era uma vez por instalação e nunca mais — e aí a apresentação
/// não alcançava ninguém que já usava o app quando um módulo novo chegava.
///
/// O carimbo é o mesmo `buildStampProvider` da abertura, mas a chave é outra:
/// cada uma grava quando **ela** termina, e quem fecha o Hub entre as duas não
/// pode perder a segunda por ter visto a primeira.
class OnboardingRepository {
  OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _seenBuildKey = 'app.onboarding_seen_build';

  /// Carimbo vazio nunca mostra, pelo mesmo motivo da abertura: vazio é "não
  /// consegui ler o executável", e apresentar a cada abertura para sempre seria
  /// pior que não apresentar.
  bool shouldShow(String stamp) =>
      kAlwaysShowOnboarding ||
      (stamp.isNotEmpty && _prefs.getString(_seenBuildKey) != stamp);

  /// Gravado quando a apresentação termina ou é pulada — os dois contam como
  /// "já vi". Pular é uma resposta, não um adiamento: quem fecha a apresentação
  /// está dizendo que não quer, e reabri-la antes da próxima build seria não
  /// escutar.
  Future<void> markSeen(String stamp) async {
    if (kAlwaysShowOnboarding) return;
    await _prefs.setString(_seenBuildKey, stamp);
  }
}

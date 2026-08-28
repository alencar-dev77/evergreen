import 'package:shared_preferences/shared_preferences.dart';

/// Liga a apresentação de boas-vindas em **toda** abertura do Hub.
///
/// É uma alavanca de desenvolvimento, e nasce `false` de propósito: a
/// apresentação é para quem acabou de instalar, e para essa pessoa ela roda uma
/// vez na vida. Ligue aqui para trabalhar nela sem precisar apagar preferência
/// nenhuma; **não suba com `true`**.
///
/// Ligada, ela também impede que a apresentação se marque como vista — senão
/// desligá-la depois deixaria você sem conseguir vê-la de novo pelo caminho
/// normal.
const bool kAlwaysShowOnboarding = false;

/// Guarda se a apresentação de boas-vindas já foi vista.
///
/// Diferente da abertura animada do Hub, que roda a cada build nova: esta roda
/// **uma vez por instalação e nunca mais**, atualização inclusive. Quem já
/// conhece os cinco painéis não precisa ser reapresentado a eles porque uma
/// versão nova saiu.
class OnboardingRepository {
  OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _seenKey = 'app.onboarding_seen';

  bool shouldShow() =>
      kAlwaysShowOnboarding || !(_prefs.getBool(_seenKey) ?? false);

  /// Gravado quando a apresentação termina ou é pulada — os dois contam como
  /// "já vi". Pular é uma resposta, não um adiamento: quem fecha a apresentação
  /// está dizendo que não quer, e reabri-la na próxima vez seria não escutar.
  Future<void> markSeen() async {
    if (kAlwaysShowOnboarding) return;
    await _prefs.setBool(_seenKey, true);
  }
}

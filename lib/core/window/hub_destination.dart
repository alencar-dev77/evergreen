import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde o Hub deve cair quando abrir — quando quem o abriu tinha um destino.
///
/// Existe porque abrir o Hub e **chegar** em algum lugar dele são duas coisas
/// diferentes, e quem pede vive noutro engine. O botão "Abrir no Hub" do painel
/// do Echo pedia a janela e caía onde ela estivesse: quem acabou de gravar uma
/// reunião ia parar nas preferências do Pin, e tinha de procurar o módulo que
/// tinha acabado de usar.
///
/// **O disco é a fonte de verdade, e o canal é só o aviso** — o mesmo arranjo
/// (e as mesmas razões) do `ModuleSettingsHost`. Os dois caminhos existem
/// porque os dois casos existem: com o Hub fechado, o destino tem de sobreviver
/// à subida de um engine inteiro, e nenhum canal alcança um engine que ainda
/// não subiu; com o Hub aberto e escondido, nada mais acontece no disco depois
/// que ele leu, e é o aviso que o faz reler.
///
/// O destino é gasto ao ser lido: ele é o pedido de uma abertura, não uma
/// preferência de onde o Hub abre. Sem isso, o Hub seguiria caindo no Echo
/// pelo resto da instalação.
abstract final class HubDestination {
  /// O módulo pedido, pelo `EvergreenModule.id`. `null` quando ninguém pediu.
  static const _key = 'hub.pending_module';

  /// O único destino que não é um módulo: a tela do aplicativo com a pergunta
  /// de desinstalar já aberta. É o caminho do item do menu da barra — a
  /// confirmação é um modal, e modal só existe no Hub.
  static const uninstall = 'app.uninstall';

  /// A tela de novidades da versão nova, por cima da tela do aplicativo. É o
  /// caminho do "Atualizar para a …" do menu da barra.
  static const update = 'app.update';

  static const channel = WindowMethodChannel(
    'hub_navigation',
    mode: ChannelMode.unidirectional,
  );

  /// Anota o destino — o `EvergreenModule.id` de um módulo, ou [uninstall] —
  /// e avisa um Hub que já esteja de pé.
  ///
  /// Nesta ordem, e não na inversa: o aviso manda reler o disco, então o disco
  /// precisa já estar escrito quando ele chega.
  static Future<void> request(String moduleId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, moduleId);

    try {
      await channel.invokeMethod<void>('goto');
    } on WindowChannelException {
      // O Hub ainda não subiu: ele lê o disco ao nascer, que é o outro caminho.
    } on MissingPluginException {
      // Sem lado nativo (teste): idem.
    } on PlatformException {
      // Qualquer outra falha do canal cai aqui pela mesma razão — o pior caso é
      // o Hub abrir onde estava, que é o que ele fazia antes disto existir.
    }
  }

  /// Lê o destino pedido e o apaga. Chamado de dentro do Hub.
  ///
  /// Relê o disco antes: o Hub tem a própria cópia em memória do
  /// `shared_preferences`, carregada quando ele subiu, e quem escreveu foi o
  /// outro engine — sem o `reload`, um Hub aberto há dez minutos leria o
  /// destino de dez minutos atrás (ou nenhum).
  static Future<String?> take() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();

    final moduleId = preferences.getString(_key);
    if (moduleId != null) await preferences.remove(_key);

    return moduleId;
  }

  /// Liga o Hub como quem atende o aviso. Só o Hub chama isto.
  static Future<void> listen(Future<void> Function() onGoto) async {
    try {
      await channel.setMethodCallHandler((call) async {
        if (call.method != 'goto') {
          throw MissingPluginException('hub_navigation: ${call.method}');
        }
        await onGoto();
      });
    } on WindowChannelException {
      // Sem canal, o Hub continua lendo o disco ao nascer.
    } on MissingPluginException {
      // Em teste não há lado nativo.
    }
  }
}

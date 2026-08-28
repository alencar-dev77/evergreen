/// As chaves que ligam e desligam partes do Evergreen na hora de compilar.
///
/// São **constantes**, e não preferências: quem mexe aqui é quem builda, não
/// quem usa. Uma bandeira desligada não deixa uma tela escondida esperando ser
/// descoberta — ela some do binário, junto com o que só ela alcançava.
///
/// Regra de uso: uma bandeira é para **desligar** algo pronto, nunca para
/// esconder algo pela metade. Código atrás de bandeira desligada continua
/// compilando, continua nos testes e continua sendo mantido — senão, no dia em
/// que ela virar `true`, o que aparece do outro lado é uma ruína.
abstract final class FeatureFlags {
  /// A escolha de aparência: o tema Apple e a linha "Aparência" nas
  /// preferências.
  ///
  /// Em `false`, o app inteiro fica no tema da casa e a linha some da tela do
  /// Evergreen — não desabilitada, some. Um controle apagado diz "isto existe,
  /// mas não para você"; aqui a resposta certa é a tela não mencionar uma
  /// escolha que ninguém pode fazer.
  ///
  /// O que **não** acontece ao desligar: a preferência guardada não é apagada.
  /// Quem tinha escolhido o Apple continua com `apple` no disco, esperando; a
  /// bandeira de volta em `true` devolve a escolha em vez de zerá-la. É a
  /// diferença entre desligar uma funcionalidade e desfazer o que a pessoa fez.
  ///
  /// O código dos dois temas continua compilando e testado dos dois lados —
  /// ver `THEMING.md`, e `AppSettings.activeTheme`, que é por onde a bandeira
  /// realmente manda.
  static const themes = false;

  /// A abertura animada do Hub — a lâmina do canivete girando para fora do
  /// cabo, uma vez por build instalada.
  ///
  /// Em `false` o Hub abre direto no conteúdo, como em toda abertura que não é
  /// a primeira. Nada mais muda de lugar: a marca continua na barra lateral, no
  /// ícone e na barra de menus.
  ///
  /// Uma consequência que não é óbvia: é o fim da cena que leva o Hub para a
  /// tela do aplicativo quando ainda não se sabe o nome de quem usa. Com a
  /// abertura desligada, ninguém é levado até lá — a pergunta do nome continua
  /// no topo daquela tela, esperando quem for. É o preço de desligar a
  /// cerimônia de primeira vez: ela vai inteira.
  static const intro = false;

  /// A apresentação de boas-vindas: os cinco passos com o print de cada painel,
  /// na primeira abertura de uma instalação.
  ///
  /// É a irmã da [intro], e por isso vive ao lado dela: a abertura animada
  /// mostra a marca, a apresentação mostra o que o app faz. Desligar as duas é
  /// o app entrando direto no assunto, que é o que ele faz da segunda abertura
  /// em diante.
  ///
  /// Como na [intro], desligada ela **não** grava o "já vi": ligada de volta,
  /// quem nunca foi apresentado é apresentado.
  static const onboarding = false;
}

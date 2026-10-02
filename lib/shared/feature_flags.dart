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
  static const intro = true;

  /// A apresentação de boas-vindas: os seis passos com o print de cada painel,
  /// uma vez por build instalada — instalação ou atualização, como a [intro].
  ///
  /// É a irmã da [intro], e por isso vive ao lado dela: a abertura animada
  /// mostra a marca, a apresentação mostra o que o app faz. Desligar as duas é
  /// o app entrando direto no assunto, que é o que ele faz da segunda abertura
  /// em diante.
  ///
  /// Como na [intro], desligada ela **não** grava o "já vi": ligada de volta,
  /// quem nunca foi apresentado é apresentado.
  static const onboarding = true;
}

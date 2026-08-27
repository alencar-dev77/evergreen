/// O que o Awake segura enquanto está ligado.
///
/// Duas coisas diferentes, e a diferença importa: manter a tela acesa é sobre
/// **olhar** (a apresentação, o painel de monitoramento, a receita na bancada),
/// e manter o sistema acordado é sobre **terminar** (a compilação, o download,
/// o backup) — nesse caso a tela pode apagar, e é melhor que apague.
///
/// Nasceu porque o módulo só sabia a primeira: quem deixava um build longo
/// rodando precisava manter a tela acesa a noite inteira para o Mac não
/// suspender, o que gasta a tela para resolver um problema que não é dela.
enum AwakeMode {
  /// Nada apaga: nem a tela, nem o sistema (a trava de tela já impede a
  /// suspensão por ociosidade).
  screen(label: 'Tela'),

  /// A tela apaga quando quiser; o Mac é que não suspende.
  system(label: 'Sistema');

  const AwakeMode({required this.label});

  /// Como a opção aparece no seletor.
  final String label;

  bool get keepsScreenOn => this == AwakeMode.screen;

  /// Como um período deste modo se chama no dia reconstruído.
  ///
  /// Diferente de [label], que é o rótulo do seletor: ali as opções dividem uma
  /// linha e se leem uma ao lado da outra ("Tela · Sistema"), aqui a frase
  /// aparece sozinha numa lista com sessões de foco e reuniões, e precisa
  /// dizer o que aconteceu sem o contexto do seletor ao redor.
  String get periodLabel =>
      keepsScreenOn ? 'Tela acesa' : 'Sistema acordado';

  /// Todas as opções, na ordem em que o seletor as mostra.
  static const options = values;

  static AwakeMode fromName(String? name) => values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => screen,
      );
}

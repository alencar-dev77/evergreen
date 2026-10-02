import 'evergreen_module.dart';

/// Um passo da apresentação de boas-vindas: um módulo, o print do painel dele e
/// duas linhas dizendo o que ele resolve.
///
/// A frase daqui **não** é a [EvergreenModule.description]: aquela é a ficha
/// técnica do módulo dentro do Hub, com três linhas de detalhe, e quem está
/// vendo o app pela primeira vez não está lendo ficha — está decidindo se
/// aquilo serve para ele. Aqui cabe o problema e a tecla, nessa ordem, em duas
/// linhas.
class OnboardingStep {
  const OnboardingStep({
    required this.module,
    required this.image,
    required this.imageWidth,
    required this.imageHeight,
    required this.shortcut,
    required this.line,
  });

  final EvergreenModule module;

  /// Print do painel em uso, recortado rente à borda dele.
  ///
  /// Sai do golden de conferência do mesmo painel (`test/goldens/`), e não de
  /// uma captura de tela: assim o print mostra dados de exemplo em vez do
  /// histórico de quem tirou, e refazer os seis depois de uma mudança de
  /// interface é rodar os goldens e recortar de novo. O recorte é o retângulo
  /// do painel (tudo o que é mais claro que o fundo do golden), com os cantos
  /// transparentes no raio do painel — o palco é verde, e o fundo do golden
  /// apareceria nas quinas.
  final String image;

  /// Largura natural do print, em pixels.
  ///
  /// Está aqui porque o palco **nunca amplia**: um print de 420px esticado para
  /// 556 fica borrado, e borrado é o que denuncia print de marketing. Quando o
  /// print é mais largo que o palco — só o Leaf, com 778 —, ele reduz; nos
  /// outros o palco simplesmente sobra em volta, que é o efeito desejado.
  final double imageWidth;

  /// Altura natural do print. Junto com [imageWidth] decide se ele cabe de pé
  /// no palco — cabendo, é centralizado; não cabendo, sangra pela base.
  final double imageHeight;

  /// O atalho global que abre o painel — é a informação que a pessoa precisa
  /// levar da tela, e a única que ela não descobre sozinha depois.
  final String shortcut;

  /// Duas linhas. Mais que isso ninguém lê numa tela que se atravessa.
  final String line;

  /// A ordem é a do Hub, com uma troca: o Pin abre porque é o que a pessoa usa
  /// no primeiro minuto, e o Echo fecha porque é o que exige mais dela
  /// (permissão de microfone, macOS 26) — por isso o Nest vem antes dele.
  ///
  /// O Track fica de fora: ele não tem painel, só a tela do Hub, e um passo sem
  /// print seria o passo em que a apresentação admite que acabou o assunto.
  static const all = <OnboardingStep>[
    OnboardingStep(
      module: EvergreenModule.pin,
      image: 'assets/onboarding/pin.png',
      imageWidth: 420,
      imageHeight: 452,
      shortcut: '⌘⇧C',
      line:
          'Tudo o que você copia fica guardado aqui, com busca e fixados.\n'
          'Nada sai da sua máquina.',
    ),
    OnboardingStep(
      module: EvergreenModule.focus,
      image: 'assets/onboarding/focus.png',
      imageWidth: 380,
      imageHeight: 410,
      shortcut: '⌘⇧F',
      line:
          'Um cronômetro que pergunta no que você vai trabalhar e guarda\n'
          'a resposta. No fim do dia, o Track junta tudo.',
    ),
    OnboardingStep(
      module: EvergreenModule.leaf,
      image: 'assets/onboarding/leaf.png',
      imageWidth: 778,
      imageHeight: 736,
      shortcut: '⌘⇧D',
      line:
          'Nove anotações curtas, todas à vista de uma vez.\n'
          'Para o que precisa sair da cabeça agora.',
    ),
    OnboardingStep(
      module: EvergreenModule.awake,
      image: 'assets/onboarding/awake.png',
      imageWidth: 380,
      imageHeight: 250,
      shortcut: '⌘⇧X',
      line:
          'Mantém a tela acesa pelo tempo que você escolher.\n'
          'Sem abrir as configurações de energia.',
    ),
    OnboardingStep(
      module: EvergreenModule.nest,
      image: 'assets/onboarding/nest.png',
      imageWidth: 420,
      imageHeight: 434,
      shortcut: '⌘⇧R',
      line:
          'Junte arquivos de várias pastas numa prateleira só\n'
          'e mande todos de uma vez para onde precisam ir.',
    ),
    OnboardingStep(
      module: EvergreenModule.echo,
      image: 'assets/onboarding/echo.png',
      imageWidth: 380,
      imageHeight: 318,
      shortcut: '⌘⇧E',
      line:
          'Grava a reunião, separa a sua voz da dos outros e devolve em texto.\n'
          'O resumo sai do modelo do próprio Mac.',
    ),
  ];
}

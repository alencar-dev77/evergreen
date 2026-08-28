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

  /// Print do painel real, recortado rente à borda dele.
  final String image;

  /// Largura natural do print, em pixels.
  ///
  /// Está aqui porque o palco **nunca amplia**: um print de 418px esticado para
  /// 556 fica borrado, e borrado é o que denuncia print de marketing. Quando o
  /// print é mais largo que o palco — só o Leaf, com 776 —, ele reduz; nos
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

  /// A ordem é a do Hub, e não a de importância declarada: o Pin abre porque é
  /// o que a pessoa usa no primeiro minuto, e o Echo fecha porque é o que exige
  /// mais dela (permissão de microfone, macOS 26).
  ///
  /// O Track fica de fora: ele não tem painel, só a tela do Hub, e um passo sem
  /// print seria o passo em que a apresentação admite que acabou o assunto.
  static const all = <OnboardingStep>[
    OnboardingStep(
      module: EvergreenModule.pin,
      image: 'assets/onboarding/pin.png',
      imageWidth: 418,
      imageHeight: 467,
      shortcut: '⌘⇧C',
      line:
          'Tudo que você copia fica guardado aqui, com busca e itens fixados.\n'
          'Nada sai da sua máquina.',
    ),
    OnboardingStep(
      module: EvergreenModule.focus,
      image: 'assets/onboarding/focus.png',
      imageWidth: 378,
      imageHeight: 250,
      shortcut: '⌘⇧F',
      line:
          'Um cronômetro que pergunta no que você vai trabalhar e guarda a\n'
          'resposta. No fim do dia, o Track junta tudo.',
    ),
    OnboardingStep(
      module: EvergreenModule.leaf,
      image: 'assets/onboarding/leaf.png',
      imageWidth: 776,
      imageHeight: 494,
      shortcut: '⌘⇧D',
      line:
          'Nove anotações curtas, todas à vista de uma vez.\n'
          'Para o que precisa sair da cabeça agora e ser resolvido depois.',
    ),
    OnboardingStep(
      module: EvergreenModule.awake,
      image: 'assets/onboarding/awake.png',
      imageWidth: 378,
      imageHeight: 240,
      shortcut: '⌘⇧X',
      line:
          'Segura a tela acesa pelo tempo que você escolher.\n'
          'Sem abrir as configurações de energia por causa de uma reunião.',
    ),
    OnboardingStep(
      module: EvergreenModule.echo,
      image: 'assets/onboarding/echo.png',
      imageWidth: 378,
      imageHeight: 214,
      shortcut: '⌘⇧E',
      line:
          'Grava a reunião, separa a sua voz da dos outros e devolve em texto.\n'
          'O resumo sai do modelo do próprio Mac.',
    ),
  ];
}

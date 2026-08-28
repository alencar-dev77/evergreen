import 'package:flutter/widgets.dart';

/// A escala de texto de um tema.
///
/// Os papéis são os mesmos nos dois — o que muda é a família, o tamanho e o
/// peso de cada degrau. O Evergreen usa Inter em 17/15/14/13/12/11; o Apple usa
/// a fonte do sistema, um degrau menor e com o tracking negativo que a SF Pro
/// pede para não parecer frouxa.
@immutable
class EgTypeScale {
  const EgTypeScale({
    required this.screenTitle,
    required this.sectionTitle,
    required this.panelTitle,
    required this.body,
    required this.bodyEmphasis,
    required this.bodyStrong,
    required this.reading,
    required this.bodyCompact,
    required this.bodyCompactEmphasis,
    required this.caption,
    required this.captionSmall,
    required this.captionSmallEmphasis,
    required this.captionXS,
    required this.overline,
    required this.button,
    required this.timer,
    required this.mono,
    required this.monoSmall,
  });

  /// Título de tela — o maior texto do app, a um degrau do corpo.
  final TextStyle screenTitle;

  final TextStyle sectionTitle;
  final TextStyle panelTitle;

  final TextStyle body;
  final TextStyle bodyEmphasis;

  /// O degrau acima do [bodyEmphasis], para nome próprio dentro de uma lista.
  final TextStyle bodyStrong;

  /// Texto que se lê em parágrafos — a transcrição de uma reunião.
  final TextStyle reading;

  final TextStyle bodyCompact;
  final TextStyle bodyCompactEmphasis;

  final TextStyle caption;
  final TextStyle captionSmall;
  final TextStyle captionSmallEmphasis;
  final TextStyle captionXS;

  /// Header de seção em caixa alta.
  final TextStyle overline;

  final TextStyle button;

  /// A contagem regressiva do Focus, com algarismos tabulares.
  final TextStyle timer;

  final TextStyle mono;
  final TextStyle monoSmall;

  /// Interpola dois estilos degrau a degrau — tamanho, peso e cor juntos.
  static EgTypeScale lerp(EgTypeScale a, EgTypeScale b, double t) =>
      EgTypeScale(
        screenTitle: TextStyle.lerp(a.screenTitle, b.screenTitle, t)!,
        sectionTitle: TextStyle.lerp(a.sectionTitle, b.sectionTitle, t)!,
        panelTitle: TextStyle.lerp(a.panelTitle, b.panelTitle, t)!,
        body: TextStyle.lerp(a.body, b.body, t)!,
        bodyEmphasis: TextStyle.lerp(a.bodyEmphasis, b.bodyEmphasis, t)!,
        bodyStrong: TextStyle.lerp(a.bodyStrong, b.bodyStrong, t)!,
        reading: TextStyle.lerp(a.reading, b.reading, t)!,
        bodyCompact: TextStyle.lerp(a.bodyCompact, b.bodyCompact, t)!,
        bodyCompactEmphasis: TextStyle.lerp(
          a.bodyCompactEmphasis,
          b.bodyCompactEmphasis,
          t,
        )!,
        caption: TextStyle.lerp(a.caption, b.caption, t)!,
        captionSmall: TextStyle.lerp(a.captionSmall, b.captionSmall, t)!,
        captionSmallEmphasis: TextStyle.lerp(
          a.captionSmallEmphasis,
          b.captionSmallEmphasis,
          t,
        )!,
        captionXS: TextStyle.lerp(a.captionXS, b.captionXS, t)!,
        overline: TextStyle.lerp(a.overline, b.overline, t)!,
        button: TextStyle.lerp(a.button, b.button, t)!,
        timer: TextStyle.lerp(a.timer, b.timer, t)!,
        mono: TextStyle.lerp(a.mono, b.mono, t)!,
        monoSmall: TextStyle.lerp(a.monoSmall, b.monoSmall, t)!,
      );
}

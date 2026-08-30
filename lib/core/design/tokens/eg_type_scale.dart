import 'package:flutter/widgets.dart';

/// A escala tipográfica do Evergreen.
///
/// Fechada de propósito: um degrau que falta **nasce aqui, com nome**, e não
/// num `copyWith` dentro de um widget. `copyWith` em estilo vale só para cor —
/// peso e tamanho são degraus, e um 14/500 solto no meio de uma tela é uma
/// decisão que ninguém tomou.
///
/// O que mudou no "Estufa": entraram [display] e [title], porque o topo da
/// escala era 17 pt e nenhuma tela tinha ponto de entrada — tudo começava com
/// o mesmo peso, que é a razão de o app inteiro parecer plano. E [overline]
/// passou a **mono**: ele é rótulo de estrutura, não de conteúdo, e em mono com
/// tracking alto o olho o lê como etiqueta de gaveta em vez de disputar com o
/// corpo do texto.
@immutable
class EgTypeScale {
  const EgTypeScale({
    required this.display,
    required this.title,
    required this.panelTitle,
    required this.body,
    required this.bodyEmphasis,
    required this.bodyStrong,
    required this.bodyCompact,
    required this.reading,
    required this.footnote,
    required this.caption,
    required this.overline,
    required this.keycap,
    required this.button,
    required this.timer,
    required this.timerSmall,
    required this.mono,
    required this.monoSmall,
  });

  /// O nome do módulo no cabeçalho do Hub. **Um por tela** — se aparecem dois,
  /// um deles é [title].
  final TextStyle display;

  /// O título de um bloco dentro da tela: "Semana", "Destinos", o título da
  /// região de leitura.
  final TextStyle title;

  /// Título de painel flutuante.
  final TextStyle panelTitle;

  /// A linha de configuração, e o texto corrente em geral.
  final TextStyle body;

  /// Item de lista que importa — o nome da reunião, o do arquivo.
  final TextStyle bodyEmphasis;

  /// **A linha selecionada.** Selecionado é peso e elevação, não cor.
  final TextStyle bodyStrong;

  /// Lista dentro de painel flutuante, onde o espaço é curto.
  final TextStyle bodyCompact;

  /// Leitura longa — a região do Hub. A altura de 1,65 é o que separa "texto
  /// que se lê" de "texto que se confere".
  final TextStyle reading;

  /// A explicação de uma linha sob o rótulo de um ajuste.
  final TextStyle footnote;

  /// Metadado: hora, contagem, origem.
  final TextStyle caption;

  /// Rótulo de seção — mono, caixa alta, tracking largo.
  final TextStyle overline;

  /// A tecla: mono, tabular, para `⌘⇧C` não dançar de largura entre linhas.
  final TextStyle keycap;

  final TextStyle button;

  /// O cronômetro do painel do Focus.
  final TextStyle timer;

  /// O mesmo cronômetro onde a largura não permite o [timer].
  final TextStyle timerSmall;

  final TextStyle mono;
  final TextStyle monoSmall;

  static EgTypeScale lerp(EgTypeScale a, EgTypeScale b, double t) => EgTypeScale(
    display: TextStyle.lerp(a.display, b.display, t)!,
    title: TextStyle.lerp(a.title, b.title, t)!,
    panelTitle: TextStyle.lerp(a.panelTitle, b.panelTitle, t)!,
    body: TextStyle.lerp(a.body, b.body, t)!,
    bodyEmphasis: TextStyle.lerp(a.bodyEmphasis, b.bodyEmphasis, t)!,
    bodyStrong: TextStyle.lerp(a.bodyStrong, b.bodyStrong, t)!,
    bodyCompact: TextStyle.lerp(a.bodyCompact, b.bodyCompact, t)!,
    reading: TextStyle.lerp(a.reading, b.reading, t)!,
    footnote: TextStyle.lerp(a.footnote, b.footnote, t)!,
    caption: TextStyle.lerp(a.caption, b.caption, t)!,
    overline: TextStyle.lerp(a.overline, b.overline, t)!,
    keycap: TextStyle.lerp(a.keycap, b.keycap, t)!,
    button: TextStyle.lerp(a.button, b.button, t)!,
    timer: TextStyle.lerp(a.timer, b.timer, t)!,
    timerSmall: TextStyle.lerp(a.timerSmall, b.timerSmall, t)!,
    mono: TextStyle.lerp(a.mono, b.mono, t)!,
    monoSmall: TextStyle.lerp(a.monoSmall, b.monoSmall, t)!,
  );
}

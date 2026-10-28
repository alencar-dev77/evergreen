import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Escala de espaçamento. Múltiplos de 4 com nomes semânticos, para manter o
/// "muito respiro" pedido no design sem números mágicos espalhados.
abstract final class AppSpacing {
  /// Fio de cabelo — o vão entre um título e o subtítulo colado nele, onde 4px
  /// já leria como duas linhas separadas em vez de um bloco só.
  static const hairline = 1.0;

  /// Respiro concêntrico: o padding que um container dá ao filho encostado na
  /// borda dele (o segmented control em volta da pílula).
  static const xxxs = 2.0;

  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const xxxl = 24.0;
  static const huge = 32.0;

  /// Margem externa máxima — rodapé de janela, respiro final de scroll.
  /// Usada com parcimônia: é o topo da escala, não um preenchimento genérico.
  static const giant = 48.0;
}

/// Escala de tamanho de ícone.
///
/// Ícone não escolhe tamanho por widget: um glifo de 14 ao lado de um de 15 na
/// mesma tela não é uma decisão, é um esquecimento. A escala é curta porque
/// ícone aqui é sempre acessório de um texto — quem manda no tamanho é a linha
/// em que ele vive.
abstract final class AppIconSizes {
  /// Metadado dentro de linha compacta — lixeira do cartão, estrela do preview.
  static const xs = 13.0;

  /// Ícone que acompanha um rótulo dentro de um botão.
  static const sm = 14.0;

  /// Ícone de linha de lista, de campo de busca e de item de sidebar — o
  /// tamanho padrão da interface.
  static const md = 15.0;

  /// Ícone sozinho, sem rótulo ao lado: botão de ícone e a marca da sidebar.
  static const lg = 16.0;

  /// Ícone dentro de um badge grande — estado vazio, módulo por vir.
  static const xl = 18.0;
}

/// Tamanho dos badges quadrados que abrigam um ícone (`EgIconBadge`).
///
/// São três, e cada um tem um lugar: dentro de uma linha, dentro de um bloco,
/// sozinho no centro de um estado vazio.
abstract final class AppBadgeSizes {
  /// Dentro de uma linha — item de sidebar, cabeçalho do preview.
  static const sm = 28.0;

  /// Dentro de um bloco de conteúdo — o painel de módulo por vir.
  static const md = 36.0;

  /// Sozinho, acima de um texto centralizado — estado vazio.
  static const lg = 40.0;
}

/// Opacidades de estado.
///
/// Existe uma só para "indisponível", e não uma por componente: um toggle a 50%
/// ao lado de um botão a 40% na mesma tela conta duas histórias diferentes
/// sobre a mesma condição.
abstract final class AppOpacities {
  /// Controle desabilitado: presente, legível, claramente fora de alcance.
  static const disabled = 0.4;

  /// Módulo ainda não lançado na sidebar. Mais forte que [disabled] porque a
  /// linha continua clicável — ela leva à tela que conta o que vem por aí.
  static const unavailable = 0.55;
}

/// Durações de animação. Tudo curto e suave — nada de transições longas.
///
/// **Iguais nos dois temas, e de propósito.** A escala do `motion.md` é do
/// produto, não da pele: um app que fica mais lento ao trocar de aparência
/// estaria mentindo sobre o que a troca faz. O que muda com o tema é só a
/// curva, que mora no `EgMotion` — e é por isso que estas constantes seguem
/// aqui, estáticas, em vez de virarem token de tema.
abstract final class AppDurations {
  /// Micro-feedback: hover, pressed, anel de foco. Precisa ser imperceptível
  /// como animação — a interface só não pode "piscar" (`motion.md`: 80–120ms).
  static const instant = Duration(milliseconds: 90);

  /// Transições de estado pequenas — badge que muda, seleção que se move.
  static const fast = Duration(milliseconds: 150);

  /// Entrada de superfície flutuante (overlay do Pin, diálogo). A saída não tem
  /// duração: fechar é instantâneo, sempre (`motion.md`).
  static const entrance = Duration(milliseconds: 120);

  /// Transições de layout.
  static const medium = Duration(milliseconds: 220);

  /// A prateleira saindo do notch: a pílula preta cresce do recorte até o
  /// tamanho do painel e se dissolve nele.
  ///
  /// No teto da faixa de transição de painel (`motion.md`: 180–260ms), e não no
  /// [medium]: são dois movimentos num só — crescer e virar painel —, e em
  /// 220ms o segundo vira um piscar.
  static const notchReveal = Duration(milliseconds: 260);

  /// O assentamento no fim de um movimento que "trava".
  ///
  /// É o único spring do Evergreen, e o `motion.md` libera exatamente um: a
  /// lâmina da marca passa 5° do ponto e volta na abertura do Hub. Curto de
  /// propósito — acima disso deixa de ser o clique de uma trava e vira o
  /// quique de app consumer que o resto da escala existe para evitar.
  static const settle = Duration(milliseconds: 60);

  /// Quanto tempo um botão ignora o segundo clique depois de uma ação que
  /// termina na hora.
  ///
  /// É a janela do duplo clique: abaixo do intervalo do macOS, que a mão usa
  /// sem querer, e acima de um clique repetido de propósito — quem aperta
  /// "+5 min" três vezes seguidas não espera 300 ms entre um e outro.
  static const pressGuard = Duration(milliseconds: 300);

  /// Quanto uma ação que demora espera antes de trocar o rótulo do botão pelo
  /// spinner. Abaixo disso a troca seria um piscar: a ação já acabou quando o
  /// olho chega.
  static const pressFeedback = Duration(milliseconds: 150);

  static const curve = Curves.easeOutCubic;

  /// Se o macOS pede para reduzir movimento (Ajustes → Acessibilidade →
  /// Exibição → Reduzir movimento).
  ///
  /// O ponto único dessa decisão: widget nenhum lê o `MediaQuery` por conta
  /// própria. `maybe`, e não `disableAnimationsOf`, porque um widget testado
  /// sem `MediaQuery` acima dele não deve quebrar por uma preferência de
  /// acessibilidade.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// A duração de um **deslocamento** — posição, tamanho, rolagem —, que vira
  /// zero com movimento reduzido.
  ///
  /// Só deslocamento: troca de cor e de opacidade continua com a duração dela,
  /// porque não é movimento — é o que o `accessibility.md` manda pôr no lugar
  /// do movimento. Encurtar o deslize não basta: reduzir é não deslizar, e o
  /// estado final, parado, tem de dizer tudo sozinho.
  static Duration movement(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Materiais translúcidos — o "vidro" das superfícies flutuantes.
///
/// Existe um só, e ele é caro: um `BackdropFilter` recompõe tudo que está atrás
/// dele a cada quadro. Por isso o material é privilégio de painel flutuante, que
/// aparece por alguns segundos e some — nunca de superfície que fica na tela o
/// tempo todo, como a sidebar do Hub (ver `colors.md` sobre custo de blur
/// permanente).
abstract final class AppMaterials {
  /// Raio do blur do vidro. Largo o bastante para o que passa por baixo virar
  /// cor e luz, e não desenho reconhecível — é a diferença entre translucidez e
  /// distração.
  static const panelBlurSigma = 40.0;

  /// O material do painel flutuante: blur largo + saturação a 160%.
  ///
  /// O blur sozinho entrega um cinza morto: borrar médias de cor lava a
  /// saturação do que estava lá. Devolvê-la é o que o macOS chama de vibrancy —
  /// é dela que vem a impressão de que o painel é feito do ambiente, e não
  /// pintado por cima dele.
  static final panelVibrancy = ui.ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturate160),
    inner: ui.ImageFilter.blur(sigmaX: panelBlurSigma, sigmaY: panelBlurSigma),
  );

  /// Matriz de saturação a 160%, preservando a luminância percebida
  /// (coeficientes 0.213 / 0.715 / 0.072 — os mesmos do `saturate()` do CSS).
  static const _saturate160 = <double>[
    1.4722, -0.4290, -0.0432, 0, 0, //
    -0.1278, 1.1710, -0.0432, 0, 0, //
    -0.1278, -0.4290, 1.5568, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

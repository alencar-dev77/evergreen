import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Raios de canto padronizados.
///
/// A escala é deliberadamente baixa (12 no máximo): radius alto empurra a
/// estética para "app mobile consumer" em vez de ferramenta desktop — ver
/// `spacing.md`, seção "Border-radius".
abstract final class AppRadii {
  /// Superfícies flutuantes — painel do overlay, dropdown, modal — 12px.
  static const panel = Radius.circular(12);

  /// Cards e superfícies internas — 8px.
  static const card = Radius.circular(8);

  /// Botões e campos — 8px.
  static const button = Radius.circular(8);

  /// List items e botões compactos — 6px.
  static const listItem = Radius.circular(6);

  /// Badges de ícone — 6px.
  static const badge = Radius.circular(6);

  /// Badges pequenos dentro do overlay — 4px.
  static const badgeSmall = Radius.circular(4);

  static const panelAll = BorderRadius.all(panel);
  static const cardAll = BorderRadius.all(card);
  static const buttonAll = BorderRadius.all(button);
  static const listItemAll = BorderRadius.all(listItem);
  static const badgeAll = BorderRadius.all(badge);
  static const badgeSmallAll = BorderRadius.all(badgeSmall);
}

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

/// Bordas e sombras compartilhadas.
abstract final class AppBorders {
  /// Borda sutil padrão de 1px.
  static const subtle = BorderSide(color: AppColors.border, width: 1);

  static const all = Border.fromBorderSide(subtle);
  static const bottom = Border(bottom: subtle);
  static const right = Border(right: subtle);

  /// Espessura da aresta que marca a superfície selecionada (ver
  /// `EgSurfaceStyle.selectedEdge`).
  ///
  /// 3px, e não 1 ou 2: o cartão selecionado já tem contorno verde por inteiro,
  /// e em 2px a aresta some dentro dele — o que deveria dizer "a linha começa
  /// aqui" vira um engrossamento sem sentido de um dos lados. Em 3px ela se lê
  /// como peça própria, e continua discreta nos 34px de altura de uma linha de
  /// lista.
  static const selectionEdge = 3.0;
}

abstract final class AppShadows {
  /// Sombra do painel flutuante, em duas camadas.
  ///
  /// - **Ambiente** — `0 24px 60px rgba(0,0,0,0.55)`: a mancha larga que separa
  ///   o painel do que estiver na tela atrás dele.
  /// - **Contato** — `0 2px 10px rgba(0,0,0,0.4)`: a sombra curta logo abaixo da
  ///   peça.
  ///
  /// Uma camada só não resolve as duas coisas: com a ambiente sozinha o painel
  /// paira sem tocar em nada e a borda fica solta no ar; com a de contato
  /// sozinha ele parece colado na tela. É como o macOS sombreia janela, e é o
  /// que faz a peça ter espessura em vez de ser um recorte.
  static const floatingPanel = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 60,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: AppColors.shadowContact,
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  /// Sombra do dropdown da menu bar — a mesma lógica de duas camadas do
  /// [floatingPanel], um degrau mais baixa: `0 20px 50px` de ambiente e
  /// `0 2px 8px` de contato.
  static const dropdown = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 50,
      offset: Offset(0, 20),
    ),
    BoxShadow(
      color: AppColors.shadowContact,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Anel de foco de teclado: 2px ao redor do componente.
  ///
  /// É uma sombra sem blur em vez de uma borda para não empurrar o layout — o
  /// componente não muda de tamanho ao receber foco. Exige que o componente
  /// tenha fundo opaco, senão o retângulo inflado aparece por inteiro.
  static const focusRing = <BoxShadow>[
    BoxShadow(color: AppColors.focusRing, spreadRadius: 2),
  ];
}

/// Durações de animação. Tudo curto e suave — nada de transições longas.
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

  static const curve = Curves.easeOutCubic;
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
    inner: ui.ImageFilter.blur(
      sigmaX: panelBlurSigma,
      sigmaY: panelBlurSigma,
    ),
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

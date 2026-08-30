import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';

/// Superfície base de todo painel do Evergreen.
///
/// Encapsula fundo, borda sutil de 1px, raio, a luz na aresta de cima e a
/// sombra flutuante — a assinatura visual compartilhada pelo overlay do Pin,
/// pelo dropdown da menu bar e pelos cards do Hub.
///
/// São três camadas, e cada uma responde por uma leitura diferente da mesma
/// peça:
///
/// - **A sombra**, por fora, diz a que altura ela está (ver
///   [context.eg.elevations.floatingPanel], duas camadas).
/// - **A borda**, [context.eg.colors.line], desenha o recorte contra o fundo.
/// - **A luz**, [context.eg.colors.edgeLight], corre por dentro da aresta
///   superior e some antes do meio. É o detalhe que separa "vidro" de
///   "retângulo mais claro": no macOS, superfície flutuante sempre pega luz na
///   quina de cima.
class EgPanel extends StatelessWidget {
  const EgPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.gradient,
    this.elevated = true,
    this.vibrant = false,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// O raio e a cor do painel. `null` nos dois quer dizer "os do tema" — e é
  /// assim que o painel encolhe de 12 para 14 e troca de material quando a
  /// aparência muda, sem nenhum chamador saber disso.
  final BorderRadius? borderRadius;
  final Color? color;

  /// Gradiente sutil de superfície. Quando informado, substitui [color].
  /// Ignorado quando [vibrant] é ligado — lá quem manda é o
  /// [context.eg.gradients.panelVibrancy].
  final Gradient? gradient;

  /// Aplica a sombra do painel flutuante. Desligue para painéis embutidos.
  final bool elevated;

  /// Faz do painel um vidro: o que estiver atrás dele é borrado e ressaturado
  /// pelo [AppMaterials.panelVibrancy], e a superfície vira translúcida.
  ///
  /// Só os cinco painéis flutuantes ligam isto. Um `BackdropFilter` recompõe
  /// tudo que está atrás a cada quadro — o preço só se paga em superfície que
  /// aparece por segundos e some, nunca na sidebar do Hub, que fica na tela o
  /// dia inteiro.
  final bool vibrant;

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    // Resolvidos uma vez: o que o chamador não disse, o tema diz.
    final radius = borderRadius ?? context.eg.shapes.panelAll;
    final material = color ?? context.eg.colors.glassPanel;

    final fill = vibrant ? context.eg.gradients.panelVibrancy : gradient;

    Widget surface = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fill == null ? material : null,
        gradient: fill,
        borderRadius: radius,
        border: context.eg.borderAll,
        // No painel de vidro a sombra fica na camada de fora: aqui dentro ela
        // seria recortada pelo `ClipRRect` que segura o blur.
        boxShadow: elevated && !vibrant
            ? context.eg.elevations.floatingPanel
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (vibrant) {
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: AppMaterials.panelVibrancy,
          child: surface,
        ),
      );

      if (elevated) {
        surface = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: context.eg.elevations.floatingPanel,
          ),
          child: surface,
        );
      }
    }

    return CustomPaint(
      foregroundPainter: _EdgeLightPainter(
        radius,
        context.eg.colors.edgeLight,
      ),
      child: surface,
    );
  }
}

/// A luz de 1px na aresta superior, por dentro da borda.
///
/// É um `inset 0 1px 0` com uma correção: em vez de parar seco nas quinas, o
/// traço nasce em [context.eg.colors.edgeLight] no topo e chega a zero na altura
/// do meio, que é o que uma luz de ambiente faz numa peça com espessura. Uma
/// linha reta de ponta a ponta denuncia o retângulo em vez de esconder.
class _EdgeLightPainter extends CustomPainter {
  const _EdgeLightPainter(this.borderRadius, this.highlight);

  /// O raio e a cor do painel. `null` nos dois quer dizer "os do tema" — e é
  final BorderRadius borderRadius;

  /// A cor do fio, resolvida pelo painel: um painter não tem contexto de onde
  /// tirar um tema.
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Meio pixel para dentro: um traço de 1px centrado na borda vazaria metade
    // para fora do recorte.
    final outline = borderRadius.toRRect(rect).deflate(0.5);

    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [
          highlight,
          AppColors.transparent,
        ]),
    );
  }

  @override
  bool shouldRepaint(_EdgeLightPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.highlight != highlight;
}

/// Badge quadrado arredondado que abriga um ícone.
///
/// Usado no ícone de tipo do list item (24px), no cabeçalho do preview (28px)
/// e no ícone do estado vazio (52px).
class EgIconBadge extends StatelessWidget {
  const EgIconBadge({
    super.key,
    required this.child,
    this.size = 24,
    this.color,
    this.borderRadius,
    this.bordered = false,
  });

  final Widget child;
  final double size;
  final Color? color;
  final BorderRadius? borderRadius;

  /// Adiciona a borda sutil — usado no badge grande do estado vazio.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? context.eg.shapes.segmentAll,
        border: bordered ? context.eg.borderAll : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

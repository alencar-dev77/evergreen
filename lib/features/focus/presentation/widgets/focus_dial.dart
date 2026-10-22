import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/design/eg_tokens.dart';

/// O anel do Focus: o tempo dentro do progresso, e não ao lado dele.
///
/// É o **instrumento** do módulo — a peça que o painel existe para mostrar.
/// Antes eram duas coisas soltas, o número grande no alto e uma linha de 2px
/// alguns blocos abaixo: para saber quanto faltava era preciso ler o relógio e
/// depois procurar a linha, e a linha, sozinha lá embaixo, não dizia de quê.
/// No anel a resposta é uma imagem só, à distância que se olha um painel que
/// fica aberto num canto da tela.
///
/// O mesmo anel nos três estados do painel — proposta, contando e concluído —,
/// pelo mesmo motivo que o bloco de texto era um só: o número não pode mudar de
/// lugar quando a tela troca de estado.
///
/// Não anima. Ele avança uma fração de grau por segundo, e animar cada passo
/// custaria quadros num painel que fica aberto o tempo todo — a mesma decisão
/// da linha de progresso que ele substituiu.
class FocusDial extends StatelessWidget {
  const FocusDial({
    super.key,
    required this.value,
    this.filled,
    this.isMuted = false,
    this.semanticLabel,
  });

  /// O número no meio — `18:04` contando, `25 min` ao fim.
  final String value;

  /// Quanto do anel fica aceso, de 0 a 1.
  ///
  /// No Focus é o que **falta**, não o que passou: a pergunta do painel é
  /// "quanto falta", e a resposta é a quantidade de verde — o anel esvazia
  /// como uma ampulheta enquanto a sessão corre. Aceso pelo tempo já cumprido,
  /// o desenho responderia a pergunta certa com o número errado.
  ///
  /// `null` desenha só a pista, que é o estado de partida. A tela de conclusão
  /// passa 1: ali o anel fechado não é tempo restante, é a volta completa.
  final double? filled;

  /// Esmaece o número e o arco. É a pausa: o tempo continua sendo o conteúdo da
  /// tela, mas parado — e isso precisa ser visível sem depender do rótulo.
  final bool isMuted;

  /// O que o leitor de tela diz no lugar do desenho.
  final String? semanticLabel;

  /// Diâmetro. Cabe na largura do painel (380) com folga dos dois lados, e é
  /// grande o bastante para o arco ser lido de longe.
  static const _size = 152.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Center(
        child: SizedBox.square(
          dimension: _size,
          child: CustomPaint(
            painter: _DialPainter(
              filled: filled ?? 0,
              track: eg.colors.line,
              arc: isMuted ? eg.colors.textTertiary : eg.colors.accent,
              // O miolo é a superfície do instrumento, não uma cor a mais: o
              // mesmo verde do arco, quase apagado, para o anel ler como um
              // mostrador e não como um aro solto sobre o vidro.
              fill: eg.colors.accent.withValues(alpha: isMuted ? 0.03 : 0.07),
            ),
            child: Center(
              child: Text(
                value,
                style: eg.text.timerSmall.copyWith(
                  color: isMuted
                      ? eg.colors.textSecondary
                      : eg.colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.filled,
    required this.track,
    required this.arc,
    required this.fill,
  });

  final double filled;
  final Color track;
  final Color arc;
  final Color fill;

  /// Espessura do anel. Fina o bastante para não virar uma rosquinha, grossa o
  /// bastante para o arco ter cor à distância.
  static const _stroke = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2;

    canvas.drawCircle(center, radius - _stroke / 2, Paint()..color = fill);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ring..color = track);

    if (filled <= 0) return;

    // Do topo, no sentido do relógio: é para onde o olho vai num mostrador.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * filled.clamp(0.0, 1.0),
      false,
      ring..color = arc,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.filled != filled ||
      old.arc != arc ||
      old.track != track ||
      old.fill != fill;
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';

/// A marca do Evergreen: um canivete, com a lâmina em qualquer ponto entre
/// recolhida e travada.
///
/// A geometria não é decorativa — ela é o que faz a marca ler como canivete e
/// não como bisturi. O cabo tem o comprimento da lâmina inteira porque é dentro
/// dele que ela se recolhe, e o rebite fica na ponta do cabo porque é ali que o
/// giro acontece. Um desenho em que a lâmina não cabe no próprio cabo pode
/// parecer um canivete parado, mas denuncia-se no primeiro quadro de
/// [openness] intermediário.
///
/// O rebite é um **furo de verdade**, aberto com `BlendMode.clear` sobre uma
/// camada própria, e não um círculo pintado da cor do fundo: a marca aparece
/// sobre o gradiente do Hub, onde "a cor do fundo" muda de pixel para pixel.
class EgBrandMark extends StatelessWidget {
  const EgBrandMark({
    super.key,
    this.size = 96,
    this.openness = 1,
    this.blade = AppColors.greenPrimary,
    this.handle = AppColors.greenShade,
  });

  /// Lado do quadrado que a marca ocupa.
  final double size;

  /// 0 recolhida dentro do cabo, 1 travada — o estado normal do ícone.
  final double openness;

  final Color blade;
  final Color handle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          openness: openness,
          blade: blade,
          handle: handle,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({
    required this.openness,
    required this.blade,
    required this.handle,
  });

  final double openness;
  final Color blade;
  final Color handle;

  /// Os paths são descritos no mesmo espaço 200x200 do desenho de origem.
  static const _viewBox = 200.0;

  /// Ângulo da lâmina recolhida, em graus. Não são 180: um canivete fechado
  /// deixa a ponta um pouco antes do fim do cabo.
  static const _closed = 174.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox);

    // Camada própria para o furo do rebite poder apagar o cabo e a lâmina de
    // uma vez, em vez de cada um tapar o buraco do outro.
    canvas.saveLayer(const Rect.fromLTWH(0, 0, _viewBox, _viewBox), Paint());

    // A montagem inteira na diagonal: um objeto comprido deitado na horizontal
    // deixaria as duas pontas do quadrado vazias.
    canvas
      ..translate(100, 102)
      ..rotate(-36 * math.pi / 180)
      ..scale(0.70);

    // A lâmina primeiro, o cabo por cima: é o cabo que esconde a lâmina
    // fechada, e é ele que cobre a espiga da lâmina aberta. Pintar na ordem
    // inversa deixava a lâmina deitada *sobre* o cabo quando recolhida, que é
    // um canivete que não fecha. O efeito colateral é a melhor parte da cena:
    // ela começa como uma barra sem identidade e vira um canivete.
    final angle = (_closed * (1 - openness)) * math.pi / 180;
    canvas
      ..save()
      ..rotate(angle);
    canvas.drawPath(_blade(), Paint()..color = blade);
    canvas.restore();

    canvas.drawRRect(_handle(), Paint()..color = handle);

    canvas.drawCircle(Offset.zero, 8.5, Paint()..blendMode = BlendMode.clear);

    canvas
      ..restore()
      ..restore();
  }

  /// O cabo: laje arredondada que sai do pivô para um lado só.
  RRect _handle() =>
      RRect.fromLTRBR(-21, -21, 118, 21, const Radius.circular(21));

  /// A lâmina aberta, apontando para -X: espinha reta em cima, fio convexo
  /// embaixo. Fechada, ela gira [_closed] graus e some dentro do cabo.
  Path _blade() => Path()
    ..moveTo(2, -16)
    ..lineTo(-90, -12)
    ..cubicTo(-100, -11, -107, -6, -106, -2)
    ..cubicTo(-80, 6, -40, 13, 2, 16)
    ..close();

  @override
  bool shouldRepaint(_BrandMarkPainter old) =>
      old.openness != openness || old.blade != blade || old.handle != handle;
}

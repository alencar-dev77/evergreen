import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/eg_tokens.dart';

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
///
/// **Este arquivo é a única marca do Evergreen.** O ícone do aplicativo, o da
/// barra de menus e o glifo da barra lateral saem daqui — os `.png` são
/// gerados por `test/tools/brand_assets_test.dart`, que chama [paintBrandMark]
/// nos tamanhos que o macOS pede. Não existe um `.svg` paralelo a manter em dia:
/// o pinheiro tinha um, e foi assim que ele sobreviveu meses depois de a marca
/// já ser outra.
class EgBrandMark extends StatelessWidget {
  const EgBrandMark({
    super.key,
    this.size = 96,
    this.openness = 1,
    this.blade,
    this.handle,
  });

  /// Lado do quadrado que a marca ocupa.
  final double size;

  /// 0 recolhida dentro do cabo, 1 travada — o estado normal do ícone.
  final double openness;

  /// As duas faces da marca. `null` quer dizer "as do tema em vigor" — é assim
  /// que o canivete troca de verde junto com o resto do app, sem ninguém
  /// precisar lembrar de repassar cor.
  final Color? blade;
  final Color? handle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          openness: openness,
          blade: blade ?? context.eg.colors.accent,
          handle: handle ?? context.eg.colors.accentDeep,
        ),
      ),
    );
  }
}

/// Desenha a marca num canvas qualquer, ocupando um quadrado de lado [size].
///
/// Existe separada do widget porque a marca não é só uma tela: ela é também o
/// `.png` do ícone do aplicativo e o da barra de menus, gerados fora da árvore
/// de widgets. Um segundo desenho para esses dois é como o pinheiro sobreviveu
/// à própria aposentadoria — em `.svg`, longe de quem mexia no Dart.
///
/// [blade] e [handle] podem ser a mesma cor: no glifo de 16px da barra lateral
/// e na barra de menus são, e o que separa a lâmina do cabo ali é a silhueta
/// mais o furo do rebite, não o contraste.
void paintBrandMark(
  Canvas canvas,
  double size, {
  double openness = 1,
  required Color blade,
  required Color handle,
}) => _BrandMarkPainter(
  openness: openness,
  blade: blade,
  handle: handle,
).paintInto(canvas, size);

/// Desenha a marca encaixada num quadrado de lado [box], ocupando [cover] dele.
///
/// Encaixada pela **tinta**, e não pelo quadrado do desenho: a marca é comprida
/// e mora na diagonal, então o quadrado dela tem canto vazio em cima e embaixo.
/// Centrada pelo quadrado, ela sai pequena e um pouco fora do meio — foi o
/// primeiro ícone de aplicativo que este desenho produziu, e parecia um
/// canivete perdido dentro da laje.
///
/// É por aqui que passam o ícone do aplicativo, o da barra de menus e o glifo
/// de 16px da barra lateral; a abertura do Hub é a única que não passa, porque
/// lá a marca precisa ocupar sempre o mesmo lugar enquanto a lâmina se move.
void paintBrandMarkFitted(
  Canvas canvas,
  double box, {
  required double cover,
  required Color blade,
  required Color handle,
}) {
  final ink = brandMarkInk(box);
  final scale = box * cover / ink.longestSide;

  canvas.save();
  canvas
    ..translate(
      (box - ink.width * scale) / 2 - ink.left * scale,
      (box - ink.height * scale) / 2 - ink.top * scale,
    )
    ..scale(scale);
  paintBrandMark(canvas, box, blade: blade, handle: handle);
  canvas.restore();
}

/// O retângulo que a marca de fato pinta, dentro do quadrado de lado [size].
///
/// A marca é comprida e mora na diagonal: sobra canto vazio dos dois lados, e
/// quem quer encostá-la na borda de um ícone precisa saber onde ela realmente
/// começa. Medido com a lâmina travada — o estado normal do desenho —, e não
/// com a lâmina em movimento: a mancha muda de tamanho durante o giro, e um
/// enquadramento que a seguisse faria a marca respirar na abertura do Hub.
Rect brandMarkInk(double size) => _BrandMarkPainter.ink(size);

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({
    required this.openness,
    required this.blade,
    required this.handle,
  });

  final double openness;

  /// Aqui as cores já vêm resolvidas: quem aceita nulo é o widget, que tem um
  /// tema à mão. O painter é chamado também de fora da árvore de widgets — o
  /// gerador dos ícones —, e ali não há tema nenhum para adivinhar.
  final Color blade;
  final Color handle;

  /// Os paths são descritos no mesmo espaço 200x200 do desenho de origem.
  static const _viewBox = 200.0;

  /// Ângulo da lâmina recolhida, em graus. Não são 180: um canivete fechado
  /// deixa a ponta um pouco antes do fim do cabo.
  static const _closed = 174.0;

  @override
  void paint(Canvas canvas, Size size) => paintInto(canvas, size.width);

  void paintInto(Canvas canvas, double side) {
    canvas.save();
    canvas.scale(side / _viewBox);

    // Camada própria para o furo do rebite poder apagar o cabo e a lâmina de
    // uma vez, em vez de cada um tapar o buraco do outro.
    canvas.saveLayer(const Rect.fromLTWH(0, 0, _viewBox, _viewBox), Paint());

    // A montagem inteira na diagonal: um objeto comprido deitado na horizontal
    // deixaria as duas pontas do quadrado vazias.
    canvas.transform(_placement().storage);

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

  /// A matriz que põe a montagem na diagonal, no meio do quadrado.
  ///
  /// Escrita uma vez e usada duas: pela pintura e pela medida da tinta. Duas
  /// cópias dela seriam duas chances de o ícone sair enquadrado por um desenho
  /// que não é o que a tela mostra.
  static Matrix4 _placement() => Matrix4.identity()
    ..translateByDouble(100, 102, 0, 1)
    ..rotateZ(-36 * math.pi / 180)
    ..scaleByDouble(0.70, 0.70, 1, 1);

  static Rect ink(double size) {
    final painter = const _BrandMarkPainter(
      openness: 1,
      blade: Color(0xFF000000),
      handle: Color(0xFF000000),
    );
    final shapes = Path()
      ..addPath(painter._blade(), Offset.zero)
      ..addRRect(painter._handle());
    final bounds = shapes.transform(_placement().storage).getBounds();

    final scale = size / _viewBox;
    return Rect.fromLTRB(
      bounds.left * scale,
      bounds.top * scale,
      bounds.right * scale,
      bounds.bottom * scale,
    );
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

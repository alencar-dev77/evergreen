import 'package:flutter/widgets.dart';

/// O canto contínuo do Evergreen.
///
/// O macOS não arredonda com um arco de círculo: a curvatura entra e sai
/// gradualmente, e é isso que faz um canto do sistema parecer macio enquanto um
/// `BorderRadius.circular` do mesmo raio parece uma esquina lixada. Era o
/// sintoma número um do desenho anterior, e é a mudança de maior efeito por
/// linha de código do redesenho inteiro.
///
/// **Onde vale:** raio a partir de [threshold]. Abaixo disso os dois desenhos
/// são indistinguíveis a olho, e o arco circular é mais barato — um
/// `ShapeDecoration` custa um `Path` por quadro, um `BorderRadius` não.
abstract final class EgSquircle {
  /// Abaixo deste raio, canto contínuo e arco circular dão a mesma imagem.
  static const threshold = 14.0;

  /// O fator que aproxima o `ContinuousRectangleBorder` do Flutter da
  /// curvatura da Apple.
  ///
  /// O Flutter mede o parâmetro de outro jeito: passar o raio cru entrega um
  /// canto visivelmente mais fechado que o do sistema. 1,25 é o valor que faz
  /// um cartão de 14 assentar sobre a captura de um cartão do Sonoma.
  static const _continuity = 1.25;

  /// A forma, para quem desenha com `ShapeDecoration`.
  ///
  /// Devolve o retângulo contínuo acima do limiar e o arredondado normal
  /// abaixo dele — quem chama não precisa saber de qual lado está.
  static ShapeBorder shape(double radius, {BorderSide? side}) {
    final border = side ?? BorderSide.none;

    if (radius < threshold) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border,
      );
    }

    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * _continuity),
      side: border,
    );
  }

  /// O raio, para quem ainda desenha com `BoxDecoration` ou precisa recortar.
  ///
  /// Acima do limiar ele já vem com o fator de continuidade aplicado, de modo
  /// que um `ClipRRect` com este raio encoste no `ShapeDecoration` do mesmo
  /// token em vez de destoar dele por um pixel.
  static BorderRadius radius(double value) =>
      BorderRadius.circular(value < threshold ? value : value * _continuity);

  /// A forma de um raio que já veio pronto — o caminho de quem recebeu um
  /// `BorderRadius` do tema e precisa desenhá-lo com `ShapeDecoration`.
  ///
  /// Decide pelo raio já multiplicado, e não pelo original, porque é o número
  /// que chega aqui: um `cardAll` vale 17,5 e não 14.
  static ShapeBorder shapeFor(BorderRadius value, {BorderSide? side}) {
    final border = side ?? BorderSide.none;

    if (value.topLeft.x < threshold * _continuity) {
      return RoundedRectangleBorder(borderRadius: value, side: border);
    }

    return ContinuousRectangleBorder(borderRadius: value, side: border);
  }
}

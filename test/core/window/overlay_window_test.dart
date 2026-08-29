import 'package:evergreen/core/window/overlay_window.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A janela 0 mede 920x800 e o painel é centralizado dentro dela — então centrar
/// a janela num ponto é centrar o painel nesse ponto. É a conta do chacoalhar do
/// Nest, e é geometria de janela: um sinal trocado aqui só apareceria no monitor
/// da direita, com um arquivo na mão.
void main() {
  const windowSize = Size(920, 800);
  const screen = Rect.fromLTWH(0, 0, 1920, 1080);

  group('positionForCursor', () {
    test('põe o centro da janela no cursor', () {
      const cursor = Offset(960, 540);

      final position = OverlayWindow.positionForCursor(cursor, screen);

      expect(position.dx + windowSize.width / 2, 960);
      expect(position.dy + windowSize.height / 2, 540);
    });

    test('não deixa a janela vazar pelo canto superior esquerdo', () {
      final position = OverlayWindow.positionForCursor(
        const Offset(10, 10),
        screen,
      );

      expect(position, Offset.zero);
    });

    test('não deixa a janela vazar pelo canto inferior direito', () {
      final position = OverlayWindow.positionForCursor(
        const Offset(1910, 1070),
        screen,
      );

      expect(position.dx + windowSize.width, screen.right);
      expect(position.dy + windowSize.height, screen.bottom);
    });

    test('respeita a origem de um segundo monitor', () {
      const second = Rect.fromLTWH(1920, 0, 1440, 900);

      final position = OverlayWindow.positionForCursor(
        const Offset(1930, 450),
        second,
      );

      expect(position.dx, second.left);
      expect(position.dy + windowSize.height / 2, 450);
    });

    test('em tela mais baixa que a janela, centraliza no que há', () {
      const short = Rect.fromLTWH(0, 0, 1280, 720);

      final position = OverlayWindow.positionForCursor(
        const Offset(640, 700),
        short,
      );

      expect(position.dy, (short.height - windowSize.height) / 2);
    });
  });
}

@Tags(['assets'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:evergreen/core/design/themes/evergreen_tokens.dart';
import 'package:evergreen/shared/widgets/eg_brand_mark.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gera os `.png` da marca a partir do desenho que está no Dart.
///
/// Sempre na paleta do tema da casa, e não na do tema em vigor: estes arquivos
/// vivem **dentro do bundle**, e o macOS os lê uma vez ao instalar. O ícone do
/// Dock e o da barra de menus não têm como acompanhar uma preferência que muda
/// em tempo de execução — trocá-los pediria mexer no `NSApplication` de dentro
/// do app. Dentro da janela, aí sim, a marca segue o tema como todo o resto.
///
/// Rode com `flutter test --run-skipped -t assets test/tools/brand_assets_test.dart`.
/// Fora da suíte padrão, como os goldens de conferência: isto **escreve** no
/// repositório, e um teste que escreve arquivo não pode rodar a cada `flutter
/// test`.
///
/// Por que um gerador e não sete `.png` desenhados à mão, ou um `.svg` ao lado:
/// o pinheiro era assim, e por isso ele continuou no ícone do aplicativo e na
/// barra de menus meses depois de a marca do Hub já ser o canivete. Com o
/// desenho num lugar só, mexer na lâmina e reexportar são o mesmo gesto — e o
/// que sai daqui é, por construção, o que a abertura do Hub mostra.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Tamanhos que o `Contents.json` do `AppIcon.appiconset` pede.
  const iconSizes = [16, 32, 64, 128, 256, 512, 1024];

  /// A moldura do ícone do macOS, nas proporções do desenho anterior: a laje
  /// não encosta na borda do quadrado (o sistema conta com essa margem para o
  /// realce e a sombra que ele mesmo desenha) e o canto é largo, o do squircle
  /// dos ícones do sistema.
  const inset = 28 / 512;
  const radius = 104 / 512;

  Future<void> write(String path, ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  }

  Future<ui.Image> render(int side, void Function(Canvas canvas) draw) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas);
    return recorder.endRecording().toImage(side, side);
  }

  test('ícone do aplicativo', () async {
    for (final side in iconSizes) {
      final image = await render(side, (canvas) {
        final box = side.toDouble();
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              box * inset,
              box * inset,
              box * (1 - inset * 2),
              box * (1 - inset * 2),
            ),
            Radius.circular(box * radius),
          ),
          Paint()..color = EvergreenTokens.palette.background,
        );

        // 0.62 da laje: o bastante para a marca mandar no ícone, e não tanto
        // que a ponta da lâmina encoste no canto arredondado — que é onde o
        // macOS desenha a sombra dele.
        paintBrandMarkFitted(
          canvas,
          box,
          cover: 0.62,
          blade: EvergreenTokens.palette.accent,
          handle: EvergreenTokens.palette.accentShade,
        );
      });

      await write(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$side.png',
        image,
      );
    }
  });

  test('ícone da barra de menus', () async {
    // Imagem de template do macOS: o sistema ignora a cor e usa só o alfa, para
    // inverter sozinho na barra clara e na escura. Por isso preto chapado, e
    // por isso lâmina e cabo na mesma cor — o que separa os dois aqui é o furo
    // do rebite.
    //
    // 44px é o dobro dos 22 que a barra mostra: o `tray_manager` recebe o
    // arquivo e o macOS o reduz na tela Retina.
    const side = 44;

    final image = await render(side, (canvas) {
      // Mais cheia que a do aplicativo: aqui não há laje em volta, e o que
      // sobra de margem é margem da barra de menus, que o macOS já dá.
      paintBrandMarkFitted(
        canvas,
        side.toDouble(),
        cover: 0.92,
        blade: const Color(0xFF000000),
        handle: const Color(0xFF000000),
      );
    });

    await write('assets/icons/tray_icon.png', image);
  });
}

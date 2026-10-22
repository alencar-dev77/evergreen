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

  Future<ui.Image> render(
    int side,
    void Function(Canvas canvas) draw, {
    int? height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas);
    return recorder.endRecording().toImage(side, height ?? side);
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
          Paint()..color = EvergreenTokens.palette.canvasDeep,
        );

        // 0.62 da laje: o bastante para a marca mandar no ícone, e não tanto
        // que a ponta da lâmina encoste no canto arredondado — que é onde o
        // macOS desenha a sombra dele.
        paintBrandMarkFitted(
          canvas,
          box,
          cover: 0.62,
          blade: EvergreenTokens.palette.accent,
          handle: EvergreenTokens.palette.accentDeep,
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

  test('fundo da janela do instalador', () async {
    // A janela do `.dmg` que o `./release` monta: o Evergreen à esquerda, o
    // atalho de Aplicativos à direita e a seta entre os dois. As posições são
    // as do AppleScript do `release` (`DMG_WIDTH`, `DMG_HEIGHT`, `APP_X`,
    // `APPLICATIONS_X`, `ICONS_Y`), em pontos — mexeu num, mexa no outro.
    //
    // Sem texto: o teste desenha com a fonte de teste, e a frase de "arraste"
    // que o Finder não escreve sairia em quadradinhos. A seta já é a frase.
    //
    // As plaquinhas atrás dos nomes existem porque o Finder escreve o nome do
    // ícone **sempre em preto** quando a pasta tem imagem de fundo — no modo
    // escuro também, e não há opção que mude a cor. Preto sobre o canvas some;
    // sobre o `textSecondary` o contraste passa de 8:1. A altura é a em que o
    // Finder põe o nome com ícone de 128 e texto de 13, medida na tela.
    //
    // Duas resoluções, porque o Finder escolhe pelo nome: `@2x` na tela
    // Retina. O `release` junta as duas num `.tiff` só com o `tiffutil`.
    const window = Size(660, 400);
    const appAt = Offset(170, 190);
    const applicationsAt = Offset(490, 190);

    for (final scale in [1, 2]) {
      final image = await render(
        (window.width * scale).round(),
        height: (window.height * scale).round(),
        (canvas) {
          canvas.scale(scale.toDouble());
          final palette = EvergreenTokens.palette;

          canvas.drawRect(
            Offset.zero & window,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset.zero,
                Offset(0, window.height),
                [palette.canvas, palette.canvasDeep],
              ),
          );

          // Entre as bordas dos dois ícones (128 pt), com folga para não
          // encostar no realce que o Finder desenha no ícone selecionado.
          final start = Offset(appAt.dx + 92, appAt.dy);
          final end = Offset(applicationsAt.dx - 92, applicationsAt.dy);
          final stroke = Paint()
            ..color = palette.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          canvas.drawLine(start, end, stroke);

          for (final center in [appAt, applicationsAt]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(center.dx, center.dy + 84),
                  width: 112,
                  height: 22,
                ),
                const Radius.circular(11),
              ),
              Paint()..color = palette.textSecondary,
            );
          }
          canvas.drawPath(
            Path()
              ..moveTo(end.dx - 18, end.dy - 18)
              ..lineTo(end.dx, end.dy)
              ..lineTo(end.dx - 18, end.dy + 18),
            stroke,
          );
        },
      );

      await write(
        scale == 1
            ? 'macos/packaging/dmg_background.png'
            : 'macos/packaging/dmg_background@2x.png',
        image,
      );
    }
  });
}

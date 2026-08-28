import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrega fontes reais do sistema para os goldens.
///
/// Sem isso a fonte padrão dos testes desenha cada glifo como um quadrado, e a
/// imagem deixa de conferir justamente o que ela existe para conferir. A mono
/// entra pelo mesmo motivo: sem uma mono de verdade os key-caps mediriam errado
/// e esconderiam problemas de largura na barra de dicas.
///
/// Compartilhada pelos arquivos de golden — duas cópias desta lista significam
/// duas imagens desenhadas com fontes diferentes na primeira vez que uma delas
/// mudar.
Future<void> loadGoldenFonts() async {
  const faces = {
    'Inter': [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ],
    'SF Mono': ['/System/Library/Fonts/Supplemental/Andale Mono.ttf'],
    // O tema Apple pede a fonte do sistema (família nula, com estes nomes no
    // fallback). Sob `flutter test` não existe fonte de sistema, e o texto sai
    // como quadrados — registrar os mesmos arquivos sob os nomes que ele
    // procura é o que faz as imagens dele conferirem alguma coisa. No app de
    // verdade quem responde é o macOS.
    'SF Pro Text': [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ],
  };

  for (final entry in faces.entries) {
    final loader = FontLoader(entry.key);
    var loaded = false;

    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      loaded = true;
    }

    if (loaded) await loader.load();
  }
}

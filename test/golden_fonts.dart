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
/// **As fontes são as que o app desenha de fato.** O Inter não vem empacotado,
/// então no Mac quem responde é o SF do sistema (o fallback do tema) — e é ele
/// que entra aqui no lugar do Inter. Era Arial, e os goldens mostravam um app
/// que ninguém via. A `Apple Symbols` entra pelos nomes do fim de cada fallback
/// porque nem o SF nem o SF Mono têm `⌘`, `⌥` e `⇧`: sem ela, toda tecla da
/// barra de dicas virava um quadrado. Esses prints também são os da
/// apresentação de boas-vindas (`assets/onboarding/`).
///
/// Compartilhada pelos arquivos de golden — duas cópias desta lista significam
/// duas imagens desenhadas com fontes diferentes na primeira vez que uma delas
/// mudar.
Future<void> loadGoldenFonts() async {
  const faces = {
    'Inter': ['/System/Library/Fonts/SFNS.ttf'],
    'SF Mono': ['/System/Library/Fonts/SFNSMono.ttf'],
    'Helvetica Neue': ['/System/Library/Fonts/Apple Symbols.ttf'],
    'Menlo': ['/System/Library/Fonts/Apple Symbols.ttf'],
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

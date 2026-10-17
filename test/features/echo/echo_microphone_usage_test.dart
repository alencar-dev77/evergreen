import 'dart:io';

import 'package:evergreen/features/echo/models/echo_audio_retention.dart';
import 'package:flutter_test/flutter_test.dart';

/// O texto que o macOS mostra ao pedir o microfone é uma promessa de
/// privacidade, e ele mora num `.plist` que nenhum código lê. Já prometeu
/// apagar o áudio ao fim da transcrição meses depois de o Echo passar a
/// guardá-lo — este teste é o que liga o texto à regra que o cumpre.
void main() {
  final plist = File('macos/Runner/Info.plist').readAsStringSync();
  final text = RegExp(
    r'<key>NSMicrophoneUsageDescription</key>\s*<string>([^<]*)</string>',
  ).firstMatch(plist)!.group(1)!;

  test('o pedido do microfone diz quanto tempo o áudio fica', () {
    expect(text, contains('${EchoAudioRetention.days} dias'));
  });

  test('e não promete apagar o áudio ao fim da transcrição', () {
    expect(text, isNot(contains('assim que a transcrição')));
  });
}

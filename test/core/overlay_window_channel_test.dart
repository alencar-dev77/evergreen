import 'package:evergreen/core/window/overlay_window_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('overlay_window');

  /// Põe um lado nativo de mentira no lugar, com a resposta que o teste quiser.
  List<String> mockNative({Object? Function()? answer}) {
    final calls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return answer?.call();
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    return calls;
  }

  test('exibe pelo canal nativo e confirma', () async {
    final calls = mockNative();

    expect(await OverlayWindowChannel.show(), isTrue);
    expect(calls, ['show']);
  });

  test('sem lado nativo, avisa em vez de estourar', () async {
    // Nenhum handler registrado: é o que o ambiente de teste — e uma build sem
    // o canal — devolvem. Quem chama precisa poder cair no caminho antigo.
    expect(await OverlayWindowChannel.show(), isFalse);
  });

  test('erro do lado nativo também avisa', () async {
    mockNative(
      answer: () => throw PlatformException(code: 'no_overlay_window'),
    );

    expect(await OverlayWindowChannel.show(), isFalse);
  });
}

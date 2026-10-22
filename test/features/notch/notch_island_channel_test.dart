import 'package:evergreen/features/notch/data/notch_island_channel.dart';
import 'package:evergreen/features/notch/models/notch_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// O que sobe da ilha do notch para o Dart: os botões e o módulo que ela está
/// mostrando — esse, para a barra de menus não repetir o relógio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('notch_island');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late NotchIslandChannel island;

  Future<void> fromNative(String method, Map<String, Object?> arguments) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );

  setUp(() => island = NotchIslandChannel()..listen());

  tearDown(() {
    island.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'avisa o módulo que a ilha passou a mostrar, e quando ela some',
    () async {
      final shown = <NotchModule?>[];
      island.onShown.listen(shown.add);

      await fromNative('onShown', {'module': 'echo'});
      await fromNative('onShown', {'module': null});
      await pumpEventQueue();

      expect(shown, [NotchModule.echo, null]);
    },
  );

  test('os botões continuam chegando', () async {
    final events = <NotchIslandEvent>[];
    island.onAction.listen(events.add);

    await fromNative('onAction', {'module': 'focus', 'action': 'pause'});
    await pumpEventQueue();

    expect(events.single.module, NotchModule.focus);
    expect(events.single.action, 'pause');
  });

  test('pergunta o que a ilha mostra; sem lado nativo, nada', () async {
    expect(await island.shown(), isNull);

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'shown' ? 'focus' : null,
    );
    expect(await island.shown(), NotchModule.focus);
  });
}

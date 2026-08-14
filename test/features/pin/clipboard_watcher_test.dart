import 'package:evergreen/features/pin/data/clipboard_watcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pasteboard_watcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> nativeCalls;
  late ClipboardWatcher watcher;

  /// Simula o lado nativo avisando que a área de transferência mudou.
  Future<void> emitFromNative(String content) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onCopy', content)),
      (_) {},
    );
  }

  setUp(() {
    nativeCalls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    watcher = ClipboardWatcher();
  });

  tearDown(() {
    watcher.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('start liga a captura no lado nativo uma única vez', () async {
    await watcher.start();
    await watcher.start();

    expect(watcher.isRunning, isTrue);
    expect(nativeCalls.map((call) => call.method), ['start']);
  });

  test('emite o conteúdo que o nativo avisa', () async {
    await watcher.start();

    final emitted = <String>[];
    watcher.onCopy.listen(emitted.add);

    await emitFromNative('chave pix');
    await pumpEventQueue();

    expect(emitted, ['chave pix']);
  });

  test('emite de novo quando o mesmo conteúdo é copiado outra vez', () async {
    // O bug da issue #14: comparando conteúdo, a segunda cópia era engolida e
    // o item não subia para o topo da lista. Quem decide agora é o changeCount
    // do pasteboard, do lado nativo — aqui, o segundo aviso.
    await watcher.start();

    final emitted = <String>[];
    watcher.onCopy.listen(emitted.add);

    await emitFromNative('git status');
    await emitFromNative('git status');
    await pumpEventQueue();

    expect(emitted, ['git status', 'git status']);
  });

  test('ignora aviso vazio ou só com espaços', () async {
    await watcher.start();

    final emitted = <String>[];
    watcher.onCopy.listen(emitted.add);

    await emitFromNative('   \n  ');
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });

  test('acknowledge manda o conteúdo escrito pelo próprio Pin', () async {
    await watcher.start();
    await watcher.acknowledge('conteúdo recopiado');

    expect(nativeCalls.last.method, 'acknowledge');
    expect(nativeCalls.last.arguments, 'conteúdo recopiado');
  });

  test('stop desliga a captura', () async {
    await watcher.start();
    await watcher.stop();

    expect(watcher.isRunning, isFalse);
    expect(nativeCalls.map((call) => call.method), ['start', 'stop']);
  });

  test('sem lado nativo, start não quebra e a captura fica desligada', () async {
    messenger.setMockMethodCallHandler(channel, null);

    await watcher.start();

    expect(watcher.isRunning, isFalse);
  });
}

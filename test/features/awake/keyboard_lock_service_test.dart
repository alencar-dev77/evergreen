import 'package:evergreen/features/awake/data/keyboard_lock_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// O canal de verdade, com o lado nativo imitado: a tradução das respostas e o
/// "desbloquear" que nunca deixa o lado de cá preso.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('keyboard_lock');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('cada motivo do nativo vira a recusa certa', () async {
    for (final (reason, refusal) in [
      ('accessibility', KeyboardLockRefusal.accessibility),
      ('secure_input', KeyboardLockRefusal.secureInput),
      ('unavailable', KeyboardLockRefusal.unavailable),
    ]) {
      answer((_) => reason);
      final service = NativeKeyboardLockService();

      expect(await service.lock(), refusal);
      expect(service.isLocked, isFalse);
    }
  });

  test('sem motivo, bloqueou', () async {
    answer((_) => null);
    final service = NativeKeyboardLockService();

    expect(await service.lock(), isNull);
    expect(service.isLocked, isTrue);
  });

  test('o desbloqueio que falha no canal solta o lado de cá', () async {
    answer((call) {
      if (call.method == 'unlock') throw PlatformException(code: 'x');
      return null;
    });
    final service = NativeKeyboardLockService();
    await service.lock();

    await service.unlock();

    expect(service.isLocked, isFalse);
  });

  test('desbloquear chama o nativo mesmo sem achar que bloqueou', () async {
    final calls = <String>[];
    answer((call) {
      calls.add(call.method);
      return null;
    });

    await NativeKeyboardLockService().unlock();

    expect(calls, ['unlock']);
  });

  test('sem lado nativo, não bloqueia', () async {
    final service = NativeKeyboardLockService();

    expect(await service.lock(), KeyboardLockRefusal.unavailable);
  });
}

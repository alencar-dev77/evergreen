import 'package:evergreen/core/system/keyboard_state_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// O assert de teclado dessincronizado, do jeito que o framework o levanta.
AssertionError _desyncAssert() => AssertionError(
      'A KeyUpEvent is dispatched, but the state shows that the physical key '
      'is not pressed.',
    );

void main() {
  test('reconhece os dois asserts de teclado dessincronizado', () {
    expect(
      KeyboardStateGuard.isDesync(
        AssertionError(
          'A KeyDownEvent is dispatched, but the state shows that the physical '
          'key is already pressed.',
        ),
      ),
      isTrue,
    );

    expect(
      KeyboardStateGuard.isDesync(
        AssertionError(
          'A KeyUpEvent is dispatched, but the state shows that the physical '
          'key is not pressed.',
        ),
      ),
      isTrue,
    );
  });

  test('não engole nada além disso', () {
    expect(KeyboardStateGuard.isDesync(AssertionError('outro assert')), isFalse);
    expect(KeyboardStateGuard.isDesync(StateError('erro de verdade')), isFalse);
    expect(KeyboardStateGuard.isDesync(Exception('boom')), isFalse);
  });

  group('install', () {
    late FlutterExceptionHandler? original;

    setUp(() => original = FlutterError.onError);
    tearDown(() {
      FlutterError.onError = original;
      PlatformDispatcher.instance.onError = null;
    });

    test('o assert de teclado não chega ao handler anterior', () {
      final reported = <Object>[];
      FlutterError.onError = (details) => reported.add(details.exception);

      KeyboardStateGuard.install();

      FlutterError.onError!(FlutterErrorDetails(exception: _desyncAssert()));
      expect(reported, isEmpty);

      // O caminho do erro não tratado responde "eu cuido disso".
      expect(
        PlatformDispatcher.instance.onError!(_desyncAssert(), StackTrace.empty),
        isTrue,
      );
    });

    test('todo o resto continua sendo reportado', () {
      final reported = <Object>[];
      FlutterError.onError = (details) => reported.add(details.exception);

      KeyboardStateGuard.install();

      final other = StateError('erro de verdade');
      FlutterError.onError!(FlutterErrorDetails(exception: other));

      expect(reported, [other]);
      expect(
        PlatformDispatcher.instance.onError!(other, StackTrace.empty),
        isFalse,
      );
    });
  });
}

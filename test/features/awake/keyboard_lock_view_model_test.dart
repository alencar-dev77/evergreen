import 'dart:async';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/awake/data/keyboard_lock_service.dart';
import 'package:evergreen/features/awake/models/keyboard_lock_duration.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/keyboard_lock_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_keyboard_lock_service.dart';

/// Dentro de `testWidgets`, como o Awake: só ali o relógio é falso, e um prazo
/// de dez minutos não espera dez minutos.
void main() {
  late FakeKeyboardLockService lock;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    lock = FakeKeyboardLockService();
  });

  ProviderContainer containerFor(WidgetTester tester) {
    final container = ProviderContainer(
      overrides: [
        keyboardLockServiceProvider.overrideWithValue(lock),
        sharedPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(() => tester.binding.clock.now()),
      ],
    );

    addTearDown(container.dispose);
    return container;
  }

  testWidgets('sem escolha gravada, o bloqueio é de um minuto', (tester) async {
    final container = containerFor(tester);

    expect(
      container.read(keyboardLockViewModelProvider).duration,
      KeyboardLockDuration.minute1,
    );
  });

  testWidgets('bloqueia pelo prazo e devolve o teclado sozinho', (
    tester,
  ) async {
    final container = containerFor(tester);
    final viewModel = container.read(keyboardLockViewModelProvider.notifier);

    await viewModel.lock();
    expect(lock.isLocked, isTrue);
    expect(container.read(keyboardLockViewModelProvider).display, '01:00');

    await tester.pump(const Duration(seconds: 20));
    expect(container.read(keyboardLockViewModelProvider).display, '00:40');

    await tester.pump(const Duration(seconds: 41));
    expect(lock.isLocked, isFalse);
    expect(container.read(keyboardLockViewModelProvider).isLocked, isFalse);
  });

  testWidgets('o prazo vem das preferências, relidas na hora de bloquear', (
    tester,
  ) async {
    final container = containerFor(tester);
    final viewModel = container.read(keyboardLockViewModelProvider.notifier);
    // Gravado por fora, como o Hub faria de outro engine.
    await preferences.setString('awake.keyboard_lock_duration', 'minutes5');

    await viewModel.lock();

    final state = container.read(keyboardLockViewModelProvider);
    expect(state.duration, KeyboardLockDuration.minutes5);
    expect(state.display, '05:00');
    await viewModel.unlock();
  });

  testWidgets('"Sempre" não tem prazo: só desbloqueia à mão', (tester) async {
    await preferences.setString('awake.keyboard_lock_duration', 'indefinite');
    final container = containerFor(tester);
    final viewModel = container.read(keyboardLockViewModelProvider.notifier);

    await viewModel.lock();
    await tester.pump(const Duration(hours: 1));

    expect(lock.isLocked, isTrue);
    expect(container.read(keyboardLockViewModelProvider).display, '∞');

    await viewModel.unlock();
    expect(lock.isLocked, isFalse);
  });

  testWidgets('recusado, não bloqueia e diz por quê', (tester) async {
    lock.refusal = KeyboardLockRefusal.accessibility;
    final container = containerFor(tester);
    final viewModel = container.read(keyboardLockViewModelProvider.notifier);

    await viewModel.lock();

    final state = container.read(keyboardLockViewModelProvider);
    expect(state.isLocked, isFalse);
    expect(state.refusalMessage, contains('Acessibilidade'));

    // Abrir o painel de novo esquece a recusa.
    await viewModel.prepareForOpen();
    expect(container.read(keyboardLockViewModelProvider).refusal, isNull);
  });

  testWidgets('desbloquear com o bloqueio em voo não deixa o teclado preso', (
    tester,
  ) async {
    final container = containerFor(tester);
    final viewModel = container.read(keyboardLockViewModelProvider.notifier);
    lock.gate = Completer<void>();

    final locking = viewModel.lock();
    await tester.pump();
    // O painel fechou antes de o nativo responder.
    await viewModel.unlock();
    lock.gate!.complete();
    await locking;

    expect(lock.isLocked, isFalse);
    expect(container.read(keyboardLockViewModelProvider).isLocked, isFalse);
  });

  testWidgets('dois pedidos juntos bloqueiam uma vez só', (tester) async {
    final container = containerFor(tester);
    final viewModel = container.read(keyboardLockViewModelProvider.notifier);
    lock.gate = Completer<void>();

    final first = viewModel.lock();
    final second = viewModel.lock();
    await tester.pump();
    lock.gate!.complete();
    await Future.wait([first, second]);

    expect(lock.lockCalls, 1);
    await viewModel.unlock();
  });

  testWidgets(
    'se o macOS para de entregar as teclas, desbloqueia e diz por quê',
    (tester) async {
      await preferences.setString('awake.keyboard_lock_duration', 'indefinite');
      final container = containerFor(tester);
      final viewModel = container.read(keyboardLockViewModelProvider.notifier);

      await viewModel.lock();
      lock.holding = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      final state = container.read(keyboardLockViewModelProvider);
      expect(state.isLocked, isFalse);
      expect(state.refusalMessage, contains('campo de senha'));
    },
  );
}

import 'dart:async';

import 'package:evergreen/features/awake/data/keyboard_lock_service.dart';

/// Bloqueio de mentira — o de verdade engoliria o teclado de quem roda a
/// suíte.
class FakeKeyboardLockService implements KeyboardLockService {
  /// O que o "sistema" responde ao próximo pedido; `null` bloqueia.
  KeyboardLockRefusal? refusal;

  bool _locked = false;

  @override
  bool get isLocked => _locked;

  @override
  Future<KeyboardLockRefusal?> lock() async {
    lockCalls++;
    await gate?.future;
    if (refusal != null) return refusal;

    _locked = true;
    return null;
  }

  /// Segura a resposta do próximo `lock` até o teste soltar — é o que expõe a
  /// corrida entre um bloqueio em voo e um desbloqueio.
  Completer<void>? gate;

  /// Faz o "sistema" parar de entregar teclas ao bloqueio.
  bool holding = true;

  int lockCalls = 0;

  @override
  Future<void> unlock() async => _locked = false;

  @override
  Future<bool> isHolding() async => _locked && holding;
}

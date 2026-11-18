import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/awake_settings_repository.dart';
import '../../data/keyboard_lock_service.dart';
import 'keyboard_lock_state.dart';

final keyboardLockViewModelProvider =
    NotifierProvider<KeyboardLockViewModel, KeyboardLockState>(
      KeyboardLockViewModel.new,
    );

/// Bloqueia o teclado pelo prazo das preferências do Awake.
///
/// Vive no engine da janela 0, como a trava do Awake. Ao contrário dela, não
/// grava nada: o bloqueio não é um período do dia, são alguns minutos sem teclado, e o
/// Track não tem o que dizer dele.
///
/// É independente da trava — dá para bloquear o teclado com a tela sendo
/// mantida acesa, e uma não mexe na outra.
class KeyboardLockViewModel extends Notifier<KeyboardLockState> {
  late final AwakeSettingsRepository _settings;
  late final KeyboardLockService _lock;
  late final DateTime Function() _now;

  Timer? _ticker;

  /// Instante em que o teclado volta sozinho. A contagem sai dele a cada
  /// tique, como no Awake, para uma suspensão do Mac não congelar o prazo.
  DateTime? _endsAt;

  /// Sobe a cada `unlock`. O `lock` que termina depois de uma subida foi
  /// desfeito enquanto esperava o disco ou o nativo — o painel fechou, outro
  /// painel abriu — e solta o que acabou de prender, em vez de bloquear um
  /// teclado que ninguém está vendo.
  int _generation = 0;

  /// Um `lock` em voo: o `t` e o clique na linha juntos não podem bloquear
  /// duas vezes nem deixar um segundo relógio órfão.
  bool _locking = false;

  static const _tick = Duration(seconds: 1);

  @override
  KeyboardLockState build() {
    _settings = ref.watch(awakeSettingsRepositoryProvider);
    _lock = ref.watch(keyboardLockServiceProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(() {
      _stopTicker();
      // O teclado é do processo, não do provider.
      unawaited(_lock.unlock());
    });

    return KeyboardLockState(duration: _settings.load().keyboardLockDuration);
  }

  /// Relê o prazo antes de o painel aparecer — ele é escolhido no Hub, outro
  /// engine — e esquece a recusa anterior. Bloqueado, nada muda: trocar o
  /// prazo de quem já bloqueou seria mexer no que está acontecendo.
  Future<void> prepareForOpen() async {
    if (state.isLocked) return;

    await _settings.reload();
    state = state.copyWith(
      duration: _settings.load().keyboardLockDuration,
      clearRefusal: true,
    );
  }

  Future<void> toggle() => state.isLocked ? unlock() : lock();

  /// Bloqueia pelo prazo das preferências. Recusado, o motivo fica no estado
  /// para o painel dizer por que não.
  Future<void> lock() async {
    if (state.isLocked || _locking) return;

    _locking = true;
    final generation = _generation;
    try {
      await _settings.reload();
      final duration = _settings.load().keyboardLockDuration;

      final refusal = await _lock.lock();
      if (generation != _generation) {
        await _lock.unlock();
        return;
      }
      if (refusal != null) {
        state = state.copyWith(duration: duration, refusal: refusal);
        return;
      }

      final total = duration.duration;
      _stopTicker();
      _endsAt = total == null ? null : _now().add(total);
      state = KeyboardLockState(
        duration: duration,
        isLocked: true,
        remaining: total,
      );
      // O relógio roda também em "Sempre": sem prazo a contar, ainda há o
      // macOS a conferir — ver [_onTick].
      _ticker = Timer.periodic(_tick, (_) => unawaited(_onTick()));
    } finally {
      _locking = false;
    }
  }

  Future<void> unlock({KeyboardLockRefusal? because}) async {
    _generation++;
    _stopTicker();
    await _lock.unlock();
    if (!state.isLocked) return;

    state = state.copyWith(
      isLocked: false,
      clearRemaining: true,
      refusal: because,
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
  }

  Future<void> _onTick() async {
    // Um campo de senha que ganhou o foco no meio do bloqueio faz o macOS
    // parar de entregar teclas a ele: o painel desbloqueia e diz por quê, em
    // vez de mostrar "bloqueado" com as teclas chegando aos apps.
    if (!await _lock.isHolding()) {
      if (state.isLocked) {
        await unlock(because: KeyboardLockRefusal.secureInput);
      }
      return;
    }

    final endsAt = _endsAt;
    if (endsAt == null) return;

    final remaining = endsAt.difference(_now());
    if (remaining <= Duration.zero) {
      await unlock();
      return;
    }

    state = state.copyWith(remaining: remaining);
  }
}

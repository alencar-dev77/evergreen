import 'package:flutter/services.dart';

import '../../../core/diagnostics/app_log.dart';

/// Por que o teclado não foi bloqueado.
enum KeyboardLockRefusal {
  /// Falta a permissão de Acessibilidade — a mesma do colar automático do Pin.
  accessibility,

  /// Um campo de senha (ou o "Secure Keyboard Entry" do Terminal) está com a
  /// entrada segura ligada, e nesse estado o macOS não entrega tecla a ninguém.
  secureInput,

  /// O sistema não deu o tap, ou não há lado nativo (em teste).
  unavailable,
}

/// Bloqueia o teclado do Mac inteiro: nenhuma tecla chega a app nenhum.
///
/// Interface pelo mesmo motivo da [SleepAssertionService]: o lado nativo fica
/// atrás de uma fronteira, e o prazo do bloqueio é verificado em teste sem
/// tocar no fluxo de eventos da sessão.
abstract interface class KeyboardLockService {
  bool get isLocked;

  /// Bloqueia. Devolve `null` quando bloqueou, ou o motivo de não ter
  /// bloqueado.
  Future<KeyboardLockRefusal?> lock();

  Future<void> unlock();

  /// O bloqueio continua engolindo as teclas.
  ///
  /// `false` quando o macOS parou de entregar teclas ao bloqueio no meio do
  /// caminho — um campo de senha que ganhou o foco liga a entrada segura, e
  /// nela tecla nenhuma passa por ele. O painel não pode continuar dizendo
  /// "bloqueado" com as teclas chegando aos apps.
  Future<bool> isHolding();
}

/// Implementação real, sobre o canal `keyboard_lock` do Runner
/// (`KeyboardLockChannel.swift`).
///
/// O bloqueio vale enquanto o processo viver: encerrar o Evergreen devolve o
/// teclado, porque o tap morre com ele.
class NativeKeyboardLockService implements KeyboardLockService {
  NativeKeyboardLockService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'keyboard_lock';

  final MethodChannel _channel;

  bool _locked = false;

  @override
  bool get isLocked => _locked;

  @override
  Future<KeyboardLockRefusal?> lock() async {
    if (_locked) return null;

    try {
      final reason = await _channel.invokeMethod<String>('lock');
      final refusal = switch (reason) {
        null => null,
        'accessibility' => KeyboardLockRefusal.accessibility,
        'secure_input' => KeyboardLockRefusal.secureInput,
        _ => KeyboardLockRefusal.unavailable,
      };
      _locked = refusal == null;
      return refusal;
    } on MissingPluginException {
      return KeyboardLockRefusal.unavailable;
    } on PlatformException catch (error) {
      AppLog.channelError(_channelName, 'lock', error);
      return KeyboardLockRefusal.unavailable;
    }
  }

  /// Chama o nativo mesmo sem achar que está bloqueado: um `lock` em voo pode
  /// ter bloqueado do lado de lá antes de o de cá saber, e o nativo é
  /// idempotente.
  @override
  Future<void> unlock() async {
    // Solto do lado de cá antes de perguntar: um canal que falhou não pode
    // deixar o painel dizendo "bloqueado" com o teclado de volta.
    _locked = false;
    try {
      await _channel.invokeMethod<void>('unlock');
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      AppLog.channelError(_channelName, 'unlock', error);
    }
  }

  @override
  Future<bool> isHolding() async {
    if (!_locked) return false;

    try {
      return await _channel.invokeMethod<bool>('isHolding') ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (error) {
      AppLog.channelError(_channelName, 'isHolding', error);
      return true;
    }
  }
}

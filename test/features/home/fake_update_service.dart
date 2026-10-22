import 'dart:async';

import 'package:evergreen/core/system/update_service.dart';

/// O atualizador em memória: o de verdade fala com o Sparkle por um canal
/// nativo, e no relógio falso do teste de widget a resposta nunca chega.
class FakeUpdateService implements UpdateService {
  FakeUpdateService([this.current = const UpdateState()]);

  UpdateState current;
  int checks = 0;
  int installs = 0;

  final _changes = StreamController<UpdateState>.broadcast();

  /// Faz de conta que o lado nativo avisou uma mudança.
  void emit(UpdateState next) {
    current = next;
    _changes.add(next);
  }

  @override
  Future<UpdateState> state() async => current;

  @override
  Future<UpdateState> setAutomaticChecks(bool enabled) async =>
      current = current.copyWith(automaticChecks: enabled);

  @override
  Future<UpdateState> checkNow() async {
    checks++;
    return current;
  }

  @override
  Future<UpdateState> install() async {
    installs++;
    return current;
  }

  @override
  Stream<UpdateState> get changes => _changes.stream;

  @override
  Stream<void> get installRequests => const Stream.empty();

  @override
  Future<void> proceedInstall() async {}

  @override
  Future<UpdateState> waitForMeeting() async => current;
}

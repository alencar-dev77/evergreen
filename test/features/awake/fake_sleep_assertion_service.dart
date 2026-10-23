import 'package:evergreen/features/awake/data/awake_session_repository.dart';
import 'package:evergreen/features/awake/data/sleep_assertion_service.dart';
import 'package:evergreen/features/awake/models/awake_mode.dart';
import 'package:evergreen/features/awake/models/awake_session.dart';

/// Trava de mentira, para o teste ver o que o IOKit veria.
class FakeSleepAssertionService implements SleepAssertionService {
  AwakeMode? _mode;

  /// Quantas vezes a trava foi ligada — é o que distingue "continua ligada" de
  /// "foi religada" quando a duração muda no meio do caminho.
  int enableCount = 0;

  /// Faz o "sistema" recusar a trava, como o canal nativo que falhou: o modo
  /// pedido não pega e a trava continua solta.
  bool refuse = false;

  @override
  bool get isEnabled => _mode != null;

  @override
  AwakeMode? get mode => _mode;

  @override
  Future<void> enable(AwakeMode mode) async {
    if (_mode == mode || refuse) return;

    _mode = mode;
    enableCount++;
  }

  @override
  Future<void> disable() async => _mode = null;
}

/// Os períodos do Awake, em memória.
class FakeAwakeSessionRepository implements AwakeSessionRepository {
  final sessions = <AwakeSession>[];

  @override
  void insert(AwakeSession session) => sessions.add(session);
}

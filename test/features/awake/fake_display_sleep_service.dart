import 'package:evergreen/features/awake/data/display_sleep_service.dart';

/// Trava de tela de mentira, para o teste ver o que o IOKit veria.
class FakeDisplaySleepService implements DisplaySleepService {
  bool _isEnabled = false;

  /// Quantas vezes a trava foi ligada — é o que distingue "continua ligada" de
  /// "foi religada" quando a duração muda no meio do caminho.
  int enableCount = 0;

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> enable() async {
    if (_isEnabled) return;

    _isEnabled = true;
    enableCount++;
  }

  @override
  Future<void> disable() async => _isEnabled = false;
}

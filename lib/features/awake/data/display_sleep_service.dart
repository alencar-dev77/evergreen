import 'package:wakelock_plus/wakelock_plus.dart';

/// Impede o display de dormir enquanto estiver ligado.
///
/// Interface própria por dois motivos: manter a dependência externa atrás de
/// uma fronteira (como qualquer repositório do projeto) e poder verificar o
/// cronômetro do Awake em teste sem tocar no IOKit.
abstract interface class DisplaySleepService {
  /// `true` se a trava está ativa neste instante.
  bool get isEnabled;

  Future<void> enable();

  Future<void> disable();
}

/// Implementação real, sobre o `wakelock_plus`.
///
/// No macOS o pacote registra um `IOPMAssertionCreateWithName` do tipo
/// `kIOPMAssertionTypeNoDisplaySleep` — a mesma trava que o Caffeine e o
/// Amphetamine usam, e a razão de não termos escrito canal nativo próprio: o
/// código Swift equivalente já existe dentro do pacote.
///
/// A trava vale enquanto o processo viver; encerrar o Evergreen a libera,
/// mesmo que o Awake tenha ficado ligado "sem limite".
class WakelockDisplaySleepService implements DisplaySleepService {
  bool _isEnabled = false;

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> enable() async {
    if (_isEnabled) return;

    await WakelockPlus.enable();
    _isEnabled = true;
  }

  @override
  Future<void> disable() async {
    if (!_isEnabled) return;

    await WakelockPlus.disable();
    _isEnabled = false;
  }
}

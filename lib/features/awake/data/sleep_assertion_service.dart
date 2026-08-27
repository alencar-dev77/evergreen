import 'package:flutter/services.dart';

import '../models/awake_mode.dart';

/// Impede o Mac de dormir enquanto estiver ligado.
///
/// Interface própria por dois motivos: manter o lado nativo atrás de uma
/// fronteira (como qualquer repositório do projeto) e poder verificar o
/// cronômetro do Awake em teste sem tocar no IOKit.
abstract interface class SleepAssertionService {
  /// `true` se a trava está ativa neste instante.
  bool get isEnabled;

  /// O que está sendo segurado agora, ou `null` com a trava solta.
  AwakeMode? get mode;

  /// Segura o Mac acordado no modo pedido.
  ///
  /// Chamar com um modo diferente do que já está valendo troca a trava — é uma
  /// assertion por processo, sempre.
  Future<void> enable(AwakeMode mode);

  Future<void> disable();
}

/// Implementação real, sobre o canal `sleep_assertion` do Runner.
///
/// O `wakelock_plus` cobria metade disto — ele registra um
/// `kIOPMAssertionTypeNoDisplaySleep`, a mesma trava do Caffeine — e nenhuma
/// versão dele alcança a outra metade: manter o **sistema** acordado com a tela
/// apagada é outro tipo de assertion, e o pacote não expõe escolha. Com o Swift
/// já sendo necessário para um dos modos, ter dois mecanismos vivos para "não
/// deixar dormir" seria pior que escrever os dois no mesmo lugar — duas
/// assertions do mesmo processo, e nenhum dos dois lados sabendo da outra.
///
/// A trava vale enquanto o processo viver; encerrar o Evergreen a libera, mesmo
/// que o Awake tenha ficado ligado "sem limite".
class NativeSleepAssertionService implements SleepAssertionService {
  NativeSleepAssertionService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'sleep_assertion';

  final MethodChannel _channel;

  AwakeMode? _mode;

  @override
  bool get isEnabled => _mode != null;

  @override
  AwakeMode? get mode => _mode;

  @override
  Future<void> enable(AwakeMode mode) async {
    if (_mode == mode) return;

    // Sem soltar a anterior primeiro: o lado nativo troca a assertion no lugar,
    // e soltar aqui abriria uma janela de alguns milissegundos em que o Mac
    // podia suspender no meio de uma troca de modo.
    if (await _invoke('enable', mode.name)) _mode = mode;
  }

  @override
  Future<void> disable() async {
    if (_mode == null) return;

    await _invoke('disable');
    _mode = null;
  }

  /// `false` quando não há lado nativo — em teste, ou em qualquer plataforma
  /// que não seja o macOS.
  Future<bool> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

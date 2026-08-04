import 'package:flutter/foundation.dart';

/// Filtra um `assert` conhecido do Flutter provocado pelos atalhos globais.
///
/// Quando `⌘⇧C`, `⌘⇧F` ou `⌘⇧,` disparam, o macOS entrega a combinação ao
/// atalho global e leva o foco para outra janela — a janela que estava em foco
/// nunca recebe o "soltou" das modificadoras. O framework segue achando que o
/// Shift está pressionado e, no próximo evento sintetizado ao reaver o foco,
/// bate de frente com o próprio registro:
///
/// > A KeyDownEvent is dispatched, but the state shows that the physical key is
/// > already pressed.
///
/// É bug conhecido do Flutter no desktop, e é **só um `assert`**: em release o
/// framework simplesmente sobrescreve o estado e a vida segue. Em debug, porém,
/// ele sobe como erro não tratado e para o app no depurador a cada troca de
/// janela por atalho.
///
/// Por que filtrar em vez de corrigir o estado: qualquer tentativa de limpar as
/// teclas pressionadas troca este assert pelo espelho dele ("a tecla não está
/// pressionada") no primeiro `keyUp` que chegar depois. O desencontro é da
/// contabilidade do embedder, não do app — e mexer nela criaria um problema
/// novo em vez de resolver este.
abstract final class KeyboardStateGuard {
  /// Trecho estável da mensagem dos dois asserts irmãos (tecla "já
  /// pressionada" e tecla "não pressionada").
  static const _signature = 'the state shows that the physical key';

  /// Liga o filtro. Deve rodar em cada engine, antes do `runApp`.
  ///
  /// São **dois** caminhos porque o Flutter entrega teclado por dois canais: o
  /// de `KeyData` sobe como erro não tratado do isolate, e o de mensagem bruta
  /// é capturado e reportado pelo `FlutterError`. O mesmo desencontro aparece
  /// em um ou no outro conforme por onde a tecla chegou.
  ///
  /// Só este assert é engolido; qualquer outro erro segue para o comportamento
  /// padrão do Flutter, que continua imprimindo e quebrando como antes.
  static void install() {
    PlatformDispatcher.instance.onError = (error, stack) => isDesync(error);

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (isDesync(details.exception)) return;
      previous?.call(details);
    };
  }

  /// O erro é o desencontro de teclado descrito acima?
  static bool isDesync(Object error) {
    if (error is! AssertionError) return false;

    return '${error.message}'.contains(_signature);
  }
}

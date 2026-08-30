import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

/// Quem avisa a janela 0 de que as preferências de módulo mudaram.
///
/// É uma interface, e não uma classe concreta, pela mesma razão do
/// `NestFileService`: teste de widget roda no relógio falso do binding, e nele
/// a resposta de um canal **nunca chega**. A tela que grava um atalho espera o
/// aviso voltar antes de dizer que está à escuta, então com o canal de verdade
/// o teste trava esperando para sempre — sem erro e sem mensagem. A tela é
/// verificada contra uma imitação em memória; o canal de verdade é assunto do
/// [ModuleSettingsHost], do outro lado.
abstract interface class ModuleSettingsNotifier {
  /// As preferências mudaram: releia o disco e ponha o mundo de acordo.
  Future<void> reapply();

  /// Tire (ou devolva) os atalhos globais do sistema enquanto a tela grava um
  /// novo.
  ///
  /// Precisa atravessar o canal mesmo o `hotkey_manager` existindo nos dois
  /// engines: o registro é do lado nativo e é por engine, e o Hub desregistrar
  /// "os atalhos dele" não tiraria do sistema os que a janela 0 registrou.
  Future<void> setSuspended({required bool suspended});
}

/// O aviso indo pelo canal de janela — a implementação de verdade.
class ChannelModuleSettingsNotifier implements ModuleSettingsNotifier {
  const ChannelModuleSettingsNotifier();

  @override
  Future<void> reapply() => _send('reapply');

  @override
  Future<void> setSuspended({required bool suspended}) =>
      _send('suspend', suspended);

  Future<void> _send(String method, [Object? arguments]) async {
    // Quando quem pede **é** a janela 0, não há canal nenhum a atravessar.
    // Acontece na abertura do app, antes de o Hub existir.
    final local = ModuleSettingsHost.localHandler;
    if (local != null) {
      await local(method, arguments);
      return;
    }

    try {
      await ModuleSettingsHost.channel.invokeMethod<void>(method, arguments);
    } on WindowChannelException {
      // A janela 0 é quem hospeda o canal e ela nunca morre antes do Hub — mas
      // "nunca" não é uma garantia que valha uma exceção subindo até a tela: o
      // pior caso é o ajuste valer só no próximo lançamento.
    } on MissingPluginException {
      // Idem, sem lado nativo.
    }
  }
}

/// O lado que atende: registra o canal na janela 0.
///
/// O interruptor de um módulo e o gravador de atalho vivem na tela de
/// preferências, que é o Hub — uma sub-janela, com o próprio engine e a própria
/// cópia em memória do `shared_preferences`. Os atalhos globais, o ícone da
/// barra de menus e os serviços de fundo vivem na janela 0. Escrever no disco
/// não avisa ninguém: sem esta ponte, desligar o Echo só teria efeito no
/// lançamento seguinte, e a pessoa ficaria olhando um interruptor desligado com
/// o módulo respondendo ao atalho normalmente.
///
/// Unidirecional e registrado uma vez só — o mesmo arranjo (e as mesmas razões)
/// do `EchoSummaryHost`. O que muda é o sentido do que trafega: aqui não volta
/// resultado nenhum, só o aviso de que o disco mudou. Quem lê o disco é sempre
/// o outro lado.
abstract final class ModuleSettingsHost {
  static const channel = WindowMethodChannel(
    'module_settings',
    mode: ChannelMode.unidirectional,
  );

  /// O atendente deste engine, quando ele é a janela 0. Ver
  /// [ChannelModuleSettingsNotifier._send].
  static Future<void> Function(String method, Object? arguments)?
  _localHandler;

  static Future<void> Function(String method, Object? arguments)?
  get localHandler => _localHandler;

  /// Liga este engine como o que atende. Só a janela 0 chama isto.
  static Future<void> register({
    required Future<void> Function() onReapply,
    required Future<void> Function({required bool suspended}) onSuspendChanged,
  }) async {
    Future<void> dispatch(String method, Object? arguments) async {
      switch (method) {
        case 'reapply':
          await onReapply();
        case 'suspend':
          await onSuspendChanged(suspended: arguments! as bool);
        default:
          throw MissingPluginException('module_settings: $method');
      }
    }

    _localHandler = dispatch;

    try {
      await channel.setMethodCallHandler(
        (call) async => dispatch(call.method, call.arguments),
      );
    } on WindowChannelException {
      // Sem canal, o Hub continua gravando no disco e a janela 0 adota tudo no
      // lançamento seguinte. É pior que instantâneo, e muito melhor que este
      // engine não subir.
    } on MissingPluginException {
      // Em teste não há lado nativo — e o atendente local acima já resolve.
    }
  }

  /// Desfaz o [register]. Existe para o teste, que reusa o processo entre casos
  /// e não pode herdar o atendente de um caso anterior.
  static void reset() => _localHandler = null;
}

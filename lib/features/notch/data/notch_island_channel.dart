import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/design/tokens/eg_palette.dart';
import '../models/notch_activity.dart';
import '../models/notch_settings.dart';

/// Um botão da ilha apertado: qual módulo, e o quê.
@immutable
class NotchIslandEvent {
  const NotchIslandEvent(this.module, this.action);

  final NotchModule module;

  /// Um de `NotchAction.pause`, `resume`, `stop` ou `open`.
  final String action;
}

/// A conversa com a ilha do notch (`macos/Runner/NotchIsland.swift`).
///
/// A ilha é uma janela nativa sem engine — ver o arquivo Swift para o porquê
/// da exceção à regra da janela 0. Daqui saem o que está rodando, as cores e
/// quem está ligado no notch; de lá voltam os botões.
///
/// Como o `NestChannel`, nada aqui lança: sem lado nativo — em teste, fora do
/// macOS — cada método responde o vazio dele, e o vazio de "tem notch?" é
/// "não". O Evergreen sem a ilha é o Evergreen de antes.
class NotchIslandChannel {
  NotchIslandChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'notch_island';

  final MethodChannel _channel;

  final _events = StreamController<NotchIslandEvent>.broadcast();

  /// Os botões da ilha. Só a janela 0 chama [listen] — é ela quem guarda a
  /// reunião e o cronômetro.
  Stream<NotchIslandEvent> get onAction => _events.stream;

  void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onAction') return;

      final arguments = call.arguments as Map<Object?, Object?>?;
      final module = NotchModule.fromId(arguments?['module'] as String?);
      final action = arguments?['action'] as String?;

      if (module == null || action == null || _events.isClosed) return;
      _events.add(NotchIslandEvent(module, action));
    });
  }

  /// Este Mac tem recorte agora? Muda com a tampa: fechada, com um monitor
  /// externo, o recorte some.
  Future<bool> hasNotch() async => await _invoke<bool>('hasNotch') ?? false;

  /// Liga ou desliga um módulo **como vitrine** — o Echo e o Focus. O Nest,
  /// que usa o notch como porta, passa pelo `NestChannel.setNotchEnabled`.
  Future<void> setEnabled(NotchModule module, {required bool enabled}) =>
      _invoke<void>('setEnabled', {'module': module.id, 'enabled': enabled});

  /// Manda as cores dos tokens. Uma vez, na abertura.
  Future<void> configure(EgPalette palette) => _invoke<void>('configure', {
    'notch': palette.notch.toARGB32(),
    'textPrimary': palette.textPrimary.toARGB32(),
    'textSecondary': palette.textSecondary.toARGB32(),
    'textTertiary': palette.textTertiary.toARGB32(),
    'accent': palette.accent.toARGB32(),
    'tide': palette.tide.toARGB32(),
    'error': palette.error.toARGB32(),
    'control': palette.control.toARGB32(),
  });

  /// Deixa a ilha quieta — sem abrir, sem receber o mouse — enquanto a pilha
  /// do Nest está aberta embaixo dela.
  Future<void> setQuiet({required bool quiet}) =>
      _invoke<void>('setQuiet', {'quiet': quiet});

  /// O que está rodando, em ordem de prioridade. Lista vazia esconde a ilha.
  Future<void> update(List<NotchActivity> activities) =>
      _invoke<void>('update', {
        'activities': [for (final activity in activities) activity.toMap()],
      });

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Sem lado nativo: em teste, ou fora do macOS.
      return null;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _events.close();
  }
}

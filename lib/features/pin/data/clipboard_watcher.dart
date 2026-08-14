import 'dart:async';

import 'package:flutter/services.dart';

/// Observa a área de transferência do sistema e emite cada nova cópia.
///
/// Quem observa é o lado nativo (`PasteboardWatcherChannel`, em
/// `macos/Runner/MainFlutterWindow.swift`), que acompanha o `changeCount` do
/// `NSPasteboard` — um inteiro que o sistema incrementa a cada escrita. Esta
/// classe só liga, desliga e repassa o que chega.
///
/// A implementação anterior era um `Timer` em Dart lendo o conteúdo a cada
/// 600ms e comparando com o anterior. Conteúdo, porém, não é evento: copiar
/// duas vezes a mesma coisa não mudava a string, então o item não subia para o
/// topo da lista — a cópia simplesmente não existia para o Pin. É a razão de
/// esta ser a única parte do módulo que não é Flutter puro; a decisão está em
/// `docs/Ideis projeto/captura-de-clipboard-nativa.md`.
class ClipboardWatcher {
  ClipboardWatcher({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'pasteboard_watcher';

  final MethodChannel _channel;
  final _controller = StreamController<String>.broadcast();

  bool _isRunning = false;

  /// Emite o conteúdo sempre que a área de transferência muda.
  Stream<String> get onCopy => _controller.stream;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    _channel.setMethodCallHandler(_handleNativeCall);

    if (!await _invoke('start')) _isRunning = false;
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    await _invoke('stop');
  }

  /// Marca um conteúdo como já conhecido, sem emiti-lo.
  ///
  /// Usado quando o próprio Pin escreve na área de transferência (ao recopiar
  /// um item): sem isso, a captura leria a escrita de volta e reordenaria a
  /// lista como se fosse uma cópia nova do usuário.
  ///
  /// Chamar **depois** de a escrita ter terminado — é o pasteboard já com o
  /// conteúdo novo que o lado nativo confere antes de engolir o evento.
  Future<void> acknowledge(String content) => _invoke('acknowledge', content);

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onCopy') return;

    final content = call.arguments as String?;
    if (content == null || content.trim().isEmpty) return;

    if (!_controller.isClosed) _controller.add(content);
  }

  /// `false` quando não há lado nativo — em teste, ou em qualquer plataforma
  /// que não seja o macOS. A captura é do Pin, não do app inteiro: sem ela o
  /// histórico para de crescer, e nada mais deixa de funcionar.
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

  void dispose() {
    unawaited(stop());
    _channel.setMethodCallHandler(null);
    _controller.close();
  }
}

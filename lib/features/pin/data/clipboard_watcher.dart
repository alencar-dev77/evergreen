import 'dart:async';

import 'package:flutter/services.dart';

/// Observa a área de transferência do sistema e emite cada novo conteúdo.
///
/// O macOS não notifica mudanças de pasteboard para apps em background, então
/// fazemos polling. O intervalo de 600ms é imperceptível para o usuário e o
/// custo por ciclo é uma leitura de string — irrelevante para a bateria.
class ClipboardWatcher {
  ClipboardWatcher({Duration? interval})
      : _interval = interval ?? const Duration(milliseconds: 600);

  final Duration _interval;
  final _controller = StreamController<String>.broadcast();

  Timer? _timer;
  String? _lastSeen;

  /// Emite o conteúdo sempre que a área de transferência muda.
  Stream<String> get onCopy => _controller.stream;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    if (isRunning) return;
    _timer = Timer.periodic(_interval, (_) => _poll());
    unawaited(_poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Marca um conteúdo como já conhecido, sem emiti-lo.
  ///
  /// Usado quando o próprio Pin escreve na área de transferência (ao recopiar
  /// um item): sem isso, o polling leria a escrita de volta e reordenaria a
  /// lista como se fosse uma cópia nova do usuário.
  void acknowledge(String content) => _lastSeen = content;

  Future<void> _poll() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final content = data?.text;

    if (content == null || content.trim().isEmpty) return;
    if (content == _lastSeen) return;

    _lastSeen = content;
    if (!_controller.isClosed) _controller.add(content);
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'local_model.dart';

/// Uma resposta do servidor do LM Studio, já lida.
@immutable
class LmStudioResponse {
  const LmStudioResponse(this.status, this.json);

  final int status;

  /// O corpo decodificado, ou `null` quando não era JSON.
  final Object? json;

  bool get isOk => status >= 200 && status < 300;
}

/// O servidor não atendeu: desligado, ou nem instalado.
class LmStudioUnreachable implements Exception {
  const LmStudioUnreachable();
}

/// A conversa HTTP com o servidor do LM Studio.
///
/// Interface pelo motivo do `NestFileService`: no relógio falso do teste de
/// widget a resposta de um socket nunca chega, e a tela que espera por ela
/// trava sem erro nenhum. A tela e o portão são verificados contra uma
/// imitação; o socket de verdade é o [DartLmStudioHttp].
abstract interface class LmStudioHttp {
  Future<LmStudioResponse> get(String path, {required Duration timeout});

  Future<LmStudioResponse> post(
    String path,
    Map<String, Object?> body, {
    required Duration timeout,
    LocalModelCancellation? cancellation,
  });
}

/// O socket de verdade — preso a `127.0.0.1:1234`.
///
/// **Não há campo de endereço, e é de propósito.** O que passa por aqui é a
/// transcrição de uma reunião; um endereço digitado errado a mandaria para
/// fora da máquina. A porta é a padrão do LM Studio, e quem a mudou lá muda de
/// volta.
class DartLmStudioHttp implements LmStudioHttp {
  DartLmStudioHttp() : _client = HttpClient() {
    // Conectar em `localhost` com o servidor desligado é recusa imediata; o
    // prazo só pesa se algo segurar a porta sem responder.
    _client.connectionTimeout = const Duration(seconds: 2);
  }

  static const host = '127.0.0.1';
  static const port = 1234;

  final HttpClient _client;

  void close() => _client.close(force: true);

  @override
  Future<LmStudioResponse> get(String path, {required Duration timeout}) =>
      _send('GET', path, null, timeout, null);

  @override
  Future<LmStudioResponse> post(
    String path,
    Map<String, Object?> body, {
    required Duration timeout,
    LocalModelCancellation? cancellation,
  }) => _send('POST', path, body, timeout, cancellation);

  Future<LmStudioResponse> _send(
    String method,
    String path,
    Map<String, Object?>? body,
    Duration timeout,
    LocalModelCancellation? cancellation,
  ) async {
    HttpClientRequest? request;
    StreamSubscription<void>? onCancel;

    Future<LmStudioResponse> exchange() async {
      request = await _client.open(method, host, port, path);
      if (cancellation != null) {
        if (cancellation.isCancelled) request!.abort();
        onCancel = cancellation.whenCancelled.asStream().listen(
          (_) => request?.abort(),
        );
      }
      if (body != null) {
        request!.headers.contentType = ContentType.json;
        request!.write(jsonEncode(body));
      }

      final response = await request!.close();
      final text = await response.transform(utf8.decoder).join();

      Object? json;
      try {
        json = text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        json = null;
      }

      return LmStudioResponse(response.statusCode, json);
    }

    try {
      return await exchange().timeout(timeout);
    } on TimeoutException {
      request?.abort();
      throw const LocalModelException(
        LocalModelException.timeout,
        'O LM Studio não respondeu a tempo.',
      );
    } on SocketException {
      if (cancellation?.isCancelled ?? false) rethrow;
      throw const LmStudioUnreachable();
    } finally {
      await onCancel?.cancel();
    }
  }
}

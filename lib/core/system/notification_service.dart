import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Um botão de uma notificação — "Começar pausa", "Mais 1 h".
@immutable
class EgNotificationAction {
  const EgNotificationAction(this.id, this.title);

  final String id;
  final String title;
}

/// Uma notificação local do Evergreen.
///
/// [id] é o assunto, não o envio: postar de novo com o mesmo id **substitui** a
/// anterior no Centro de Notificações. É o que impede o fim de cada sessão do
/// dia de empilhar um aviso velho do mesmo cronômetro.
@immutable
class EgNotification {
  const EgNotification({
    required this.id,
    required this.thread,
    required this.title,
    this.subtitle = '',
    this.body = '',
    this.sound = false,
    this.imagePath,
    this.actions = const [],
  });

  final String id;

  /// Agrupa as notificações do mesmo módulo no Centro de Notificações.
  final String thread;

  final String title;
  final String subtitle;
  final String body;

  /// Som do sistema. Desligado por padrão: o Focus já toca o alerta dele, e um
  /// segundo som no mesmo instante seria eco.
  final bool sound;

  /// PNG mostrado ao lado do texto — e grande, quando a pessoa expande.
  final String? imagePath;

  final List<EgNotificationAction> actions;
}

/// O que a pessoa fez com uma notificação: clicou nela ([action] nulo) ou num
/// dos botões.
@immutable
class EgNotificationResponse {
  const EgNotificationResponse(this.id, this.action);

  final String id;
  final String? action;
}

/// Quem posta notificações e escuta o clique nelas.
///
/// Interface pelo motivo de sempre: no relógio falso do teste de widget a
/// resposta do canal nunca chega.
abstract interface class NotificationService {
  /// `false` quando não foi mostrada — permissão negada, ou sem lado nativo.
  Future<bool> post(EgNotification notification);

  Stream<EgNotificationResponse> get responses;
}

/// Implementação sobre o canal `notifications` do Runner — ver
/// `NotificationChannel.swift`. Só a janela 0 tem o lado nativo dele.
class ChannelNotificationService implements NotificationService {
  ChannelNotificationService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('notifications') {
    _channel.setMethodCallHandler(_handle);
  }

  final MethodChannel _channel;
  final _responses = StreamController<EgNotificationResponse>.broadcast();

  @override
  Stream<EgNotificationResponse> get responses => _responses.stream;

  @override
  Future<bool> post(EgNotification notification) async {
    try {
      final shown = await _channel.invokeMethod<bool>('post', {
        'id': notification.id,
        'thread': notification.thread,
        'title': notification.title,
        'subtitle': notification.subtitle,
        'body': notification.body,
        'sound': notification.sound,
        'image': ?notification.imagePath,
        'actions': [
          for (final action in notification.actions)
            {'id': action.id, 'title': action.title},
        ],
      });
      return shown ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'onResponse') return;

    final args = call.arguments as Map<Object?, Object?>;
    final id = args['id'];
    if (id is! String) return;

    _responses.add(EgNotificationResponse(id, args['action'] as String?));
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_responses.close());
  }
}

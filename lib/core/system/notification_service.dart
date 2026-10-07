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

  /// O som de notificação do sistema — o mesmo que o Ajustes do macOS liga e
  /// desliga em "Reproduzir som para notificação". Desligado por padrão: quem
  /// avisa de algo que a pessoa não pediu (o resumo da semana) decide ligar.
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

  /// Agenda [notification] no sistema para [at]. Mesmo id substitui o que
  /// estava agendado — é assim que um lembrete muda de hora.
  Future<bool> schedule(EgNotification notification, DateTime at);

  /// Tira do sistema o que estava agendado ou já entregue com estes ids.
  Future<void> cancel(List<String> ids);

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
  Future<bool> post(EgNotification notification) => _post(notification);

  @override
  Future<bool> schedule(EgNotification notification, DateTime at) =>
      _post(notification, at: at);

  @override
  Future<void> cancel(List<String> ids) async {
    if (ids.isEmpty) return;

    try {
      await _channel.invokeMethod<void>('cancel', ids);
    } on MissingPluginException {
      // Sem lado nativo (teste, ou o Hub): não há o que cancelar.
    } on PlatformException {
      // O sistema recusou: o pior caso é um lembrete que já não vale tocar, e
      // quem o recebe cai num cartão que não existe mais — o clique não faz
      // nada.
    }
  }

  Future<bool> _post(EgNotification notification, {DateTime? at}) async {
    try {
      final shown = await _channel.invokeMethod<bool>('post', {
        'id': notification.id,
        'thread': notification.thread,
        'title': notification.title,
        'subtitle': notification.subtitle,
        'body': notification.body,
        'sound': notification.sound,
        'image': ?notification.imagePath,
        'at': ?at?.millisecondsSinceEpoch,
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

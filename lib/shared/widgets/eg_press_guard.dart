import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';

/// O que um botão chama ao ser apertado.
///
/// Pode devolver um `Future`, e é esse o ponto: devolvendo, o botão sabe
/// quando a ação acabou. Uma função que não devolve nada continua servindo —
/// `void Function()` é um [EgPressCallback] —, e aí a guarda é só a do duplo
/// clique.
typedef EgPressCallback = FutureOr<void> Function();

/// A guarda contra o segundo disparo, num lugar só para todo botão.
///
/// Dois cliques seguidos num botão faziam o trabalho duas vezes: dois backups,
/// dois pedidos de "Resumir", duas janelas de "Mostrar no Finder". A guarda
/// tem dois modos, e quem escolhe é a própria ação:
///
/// - **a ação devolve um `Future`**: o botão não aceita outro toque até ele
///   terminar — com sucesso ou com erro —, e passados [AppDurations.pressFeedback]
///   o rótulo dá lugar ao spinner. A ação rápida acaba antes disso e não pisca,
///   e a que está esperando a resposta de um diálogo também não ganha spinner
///   ([_showWorking]);
/// - **a ação termina na hora**: o botão ignora o toque seguinte por
///   [AppDurations.pressGuard], que é a janela do duplo clique.
///
/// O erro de uma ação não é engolido aqui: ele segue para a zona, como seguia
/// quando quem chamava fazia `unawaited`, e chega ao `ErrorCapture`.
mixin EgPressGuard<T extends StatefulWidget> on State<T> {
  bool _busy = false;
  bool _working = false;
  Timer? _feedback;
  Timer? _cooldown;

  /// A ação que o botão disparou ainda não terminou, e já faz tempo bastante
  /// para mostrar isso.
  bool get isWorking => _working;

  /// Chama `action`, a menos que a anterior ainda esteja de pé.
  void guardedPress(EgPressCallback action) {
    if (_busy) return;
    _busy = true;

    final FutureOr<void> result;
    try {
      result = action();
    } catch (_) {
      _release();
      rethrow;
    }

    if (result is Future<void>) {
      _feedback = Timer(AppDurations.pressFeedback, _showWorking);
      unawaited(result.whenComplete(_release));
    } else {
      _cooldown = Timer(AppDurations.pressGuard, _release);
    }
  }

  /// Troca o rótulo pelo spinner — menos enquanto houver um diálogo por cima.
  ///
  /// Uma ação que pergunta antes ("Apagar tudo?") devolve um `Future` que só
  /// termina quando a pessoa responde. Esperar a resposta não é trabalho: o
  /// spinner girando atrás da pergunta diria que o app está ocupado com algo
  /// que ele nem começou. Enquanto a rota do botão não é a de cima, a guarda
  /// só torna a olhar; o trabalho que vem depois da resposta, se demorar,
  /// ganha o spinner como qualquer outro.
  void _showWorking() {
    if (!mounted || !_busy) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _feedback = Timer(AppDurations.pressFeedback, _showWorking);
      return;
    }

    setState(() => _working = true);
  }

  void _release() {
    _feedback?.cancel();
    _cooldown?.cancel();
    _feedback = null;
    _cooldown = null;
    _busy = false;
    if (_working && mounted) setState(() => _working = false);
    _working = false;
  }

  @override
  void dispose() {
    _feedback?.cancel();
    _cooldown?.cancel();
    super.dispose();
  }
}

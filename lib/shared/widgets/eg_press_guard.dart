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
///   [AppDurations.pressGuard], que é a janela do duplo clique — e a que
///   devolve um `Future` também nunca solta antes dela.
///
/// Enquanto trabalha, o botão continua focável e anunciado como habilitado:
/// é a guarda que ignora o toque, e não o botão que some do teclado. Era o
/// que tirava o anel de foco de quem apertou Enter.
///
/// O erro de uma ação não é engolido aqui: ele segue para a zona, como seguia
/// quando quem chamava fazia `unawaited`, e chega ao `ErrorCapture`.
mixin EgPressGuard<T extends StatefulWidget> on State<T> {
  bool _busy = false;
  bool _working = false;
  bool _pending = false;
  bool _cooling = false;
  Timer? _feedback;
  Timer? _cooldown;
  ModalRoute<Object?>? _route;

  /// A ação que o botão disparou ainda não terminou, e já faz tempo bastante
  /// para mostrar isso.
  bool get isWorking => _working;

  /// A rota do botão, lida aqui e não de dentro do relógio do spinner.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  /// Chama `action`, a menos que a anterior ainda esteja de pé.
  ///
  /// O botão só volta quando as duas coisas acontecem: a ação terminou **e**
  /// passou a janela do duplo clique. Soltar só no fim da ação deixava
  /// passar o duplo clique de toda função `async` que termina em poucos
  /// milissegundos — o "Desligar" do Awake vira "Manter a tela acesa" no
  /// mesmo lugar, e o segundo clique religava a trava.
  ///
  /// `repeatable` dispensa a janela, para o botão que se aperta várias vezes
  /// de propósito: pular 10 s, a semana anterior.
  void guardedPress(EgPressCallback action, {bool repeatable = false}) {
    if (_busy) return;
    _busy = true;
    _pending = true;
    _cooling = !repeatable;

    if (_cooling) {
      _cooldown = Timer(AppDurations.pressGuard, () {
        _cooling = false;
        _settle();
      });
    }

    final FutureOr<void> result;
    try {
      result = action();
    } catch (_) {
      _pending = false;
      _settle();
      rethrow;
    }

    if (result is Future<void>) {
      _feedback = Timer(AppDurations.pressFeedback, _showWorking);
      unawaited(
        result.whenComplete(() {
          _pending = false;
          _settle();
        }),
      );
    } else {
      _pending = false;
      _settle();
    }
  }

  /// Troca o rótulo pelo spinner — menos enquanto houver um diálogo por cima.
  ///
  /// Uma ação que pergunta antes ("Apagar tudo?") devolve um `Future` que só
  /// termina quando a pessoa responde. Esperar a resposta não é trabalho: o
  /// spinner girando atrás da pergunta diria que o app está ocupado com algo
  /// que ele nem começou. Enquanto a rota do botão não é a de cima, a guarda
  /// só torna a olhar; o trabalho que vem depois da resposta, se demorar,
  /// ganha o spinner como qualquer outro. Um alerta do sistema (a permissão
  /// do microfone) não é rota do Flutter, e por isso quem o pede não devolve
  /// o `Future` ao botão.
  void _showWorking() {
    if (!mounted || !_pending) return;

    final route = _route;
    if (route != null && !route.isCurrent) {
      _feedback = Timer(AppDurations.pressFeedback, _showWorking);
      return;
    }

    setState(() => _working = true);
  }

  /// Solta o botão quando a ação acabou e a janela passou.
  void _settle() {
    if (!_pending) {
      _feedback?.cancel();
      _feedback = null;
      if (_working && mounted) setState(() => _working = false);
      _working = false;
    }
    if (_pending || _cooling) return;

    _cooldown?.cancel();
    _cooldown = null;
    _busy = false;
  }

  @override
  void dispose() {
    _feedback?.cancel();
    _cooldown?.cancel();
    super.dispose();
  }
}

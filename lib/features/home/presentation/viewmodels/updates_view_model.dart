import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/update_service.dart';

final updatesViewModelProvider =
    AsyncNotifierProvider<UpdatesViewModel, UpdateState>(UpdatesViewModel.new);

/// A atualização vista do Hub: a seção da tela do aplicativo, a bolinha do
/// botão "Aplicativo" e a tela de novidades.
///
/// A preferência não mora no `AppSettings`: quem decide se a procura sai é o
/// Sparkle, e a dele é a única cópia — ver `UpdaterChannel.swift`.
///
/// **O Hub pergunta, não é avisado.** Quem o lado nativo avisa é a janela 0,
/// o único engine que nunca morre; aqui o estado é relido de tempos em tempos
/// — de meio em meio segundo enquanto algo anda (procurando, baixando), e de
/// meio em meio minuto no resto, que é o que faz a bolinha acender com o Hub
/// aberto quando a procura diária acha versão nova.
class UpdatesViewModel extends AsyncNotifier<UpdateState> {
  UpdateService get _service => ref.read(updateServiceProvider);

  Timer? _poll;

  static const busyInterval = Duration(milliseconds: 500);
  static const idleInterval = Duration(seconds: 30);

  @override
  Future<UpdateState> build() async {
    ref.onDispose(() => _poll?.cancel());

    final current = await ref.watch(updateServiceProvider).state();
    _schedule(current);
    return current;
  }

  Future<void> setAutomaticChecks(bool enabled) async {
    _apply(await _service.setAutomaticChecks(enabled));
  }

  /// Procura agora. O resultado ("está em dia", a versão nova) chega pelas
  /// releituras seguintes.
  Future<void> checkNow() async {
    _apply(await _service.checkNow());
  }

  /// Baixa, instala e reabre. Daqui em diante o app fecha sozinho.
  Future<void> install() async {
    _apply(await _service.install());
  }

  Future<void> refresh() async {
    _apply(await _service.state());
  }

  void _apply(UpdateState next) {
    if (!ref.mounted) return;
    state = AsyncData(next);
    _schedule(next);
  }

  void _schedule(UpdateState current) {
    _poll?.cancel();
    if (!current.available) return;

    final active =
        current.phase == UpdatePhase.checking || current.phase.isBusy;
    _poll = Timer(active ? busyInterval : idleInterval, () {
      if (ref.mounted) unawaited(refresh());
    });
  }
}

/// A tela de novidades está na frente do Hub?
///
/// À parte do estado do atualizador porque é uma decisão de tela: quem a abre
/// é o item do menu da barra, a bolinha ou o "Ver novidades", e quem a fecha é
/// o "Agora não" — a versão continua anunciada.
final updatePresentationProvider =
    NotifierProvider<UpdatePresentationViewModel, bool>(
      UpdatePresentationViewModel.new,
    );

class UpdatePresentationViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;

  void close() => state = false;
}

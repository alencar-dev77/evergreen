import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../models/notch_settings.dart';

/// Este Mac tem recorte agora?
///
/// É o que decide se as linhas do notch aparecem nas telas dos módulos: em Mac
/// sem recorte elas não existem, e a tela fica exatamente como era. Perguntado
/// uma vez por Hub aberto — a tampa que fecha no meio de uma visita às
/// preferências não é um caso que mereça um relógio.
final hasNotchProvider = FutureProvider<bool>(
  (ref) => ref.watch(notchIslandChannelProvider).hasNotch(),
);

final notchSettingsViewModelProvider =
    NotifierProvider<NotchSettingsViewModel, NotchSettings>(
      NotchSettingsViewModel.new,
    );

/// O que cada módulo faz no notch, com escrita imediata.
///
/// Mexer no interruptor grava **e** avisa o lado nativo na hora, do próprio
/// Hub — quem desenha a ilha e quem vigia o arraste vivem fora de qualquer
/// engine, e o Hub alcança os dois tão bem quanto a janela 0. É o arranjo do
/// chacoalhar do Nest.
class NotchSettingsViewModel extends Notifier<NotchSettings> {
  @override
  NotchSettings build() => ref.watch(notchSettingsRepositoryProvider).load();

  Future<void> setEnabled(NotchModule module, {required bool enabled}) async {
    state = state.copyWith(module, enabled: enabled);
    await ref
        .read(notchSettingsRepositoryProvider)
        .save(module, enabled: enabled);

    switch (module) {
      case NotchModule.nest:
        await ref.read(nestChannelProvider).setNotchEnabled(enabled: enabled);
      case NotchModule.echo:
      case NotchModule.focus:
        await ref
            .read(notchIslandChannelProvider)
            .setEnabled(module, enabled: enabled);
    }
  }
}

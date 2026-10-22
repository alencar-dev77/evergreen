import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/eg_settings_row.dart';
import '../../models/notch_settings.dart';
import '../viewmodels/notch_settings_view_model.dart';

/// O interruptor do notch na tela de um módulo.
///
/// Uma linha só para os três módulos, como a `GlobalShortcutSection`: o que
/// muda entre eles é o texto, e o caminho até o disco e até o lado nativo é o
/// mesmo.
///
/// **Quem decide se ela aparece é a tela**, com [isAvailable]: o cartão desenha
/// os divisores pela posição de cada filho, e uma linha que se apagasse
/// sozinha deixaria um divisor solto embaixo da anterior.
class NotchToggleRow extends ConsumerWidget {
  const NotchToggleRow({
    super.key,
    required this.module,
    required this.label,
    required this.description,
  });

  final NotchModule module;
  final String label;
  final String description;

  /// Há recorte nesta tela? Sem ele, a linha não entra na tela — e a tela fica
  /// como era antes de o notch existir.
  static bool isAvailable(WidgetRef ref) =>
      ref.watch(hasNotchProvider).value ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      notchSettingsViewModelProvider.select(
        (settings) => settings.isEnabled(module),
      ),
    );

    return EgSettingsRow.toggle(
      label: label,
      description: description,
      value: enabled,
      onChanged: (value) => unawaited(
        ref
            .read(notchSettingsViewModelProvider.notifier)
            .setEnabled(module, enabled: value),
      ),
    );
  }
}

import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../models/awake_duration.dart';
import '../../models/awake_mode.dart';
import '../viewmodels/awake_settings_view_model.dart';

/// Tela do Awake dentro do Hub.
///
/// As duas preferências daqui são as que **não** mudam de uma vez para outra: o
/// que a trava segura e com qual prazo o painel abre. O que muda toda vez é a
/// duração escolhida na hora, e essa vive no painel, junto do botão que liga.
class AwakeSettingsView extends ConsumerWidget {
  const AwakeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(awakeSettingsViewModelProvider);
    final viewModel = ref.read(awakeSettingsViewModelProvider.notifier);

    return EgSettingsPage(
      children: [
        EgSettingsCard(
          title: 'Geral',
          children: [
            EgSettingsRow(
              label: 'Manter acordado',
              description:
                  'Tela: nada apaga enquanto a trava valer. Sistema: a tela '
                  'apaga, mas o Mac não suspende.',
              trailing: EgSegmentedControl<AwakeMode>(
                value: settings.mode,
                options: AwakeMode.options,
                labelOf: (option) => option.label,
                onChanged: viewModel.setMode,
              ),
            ),
            EgSettingsRow(
              label: 'Duração padrão',
              description:
                  'O que o painel propõe. Dá para trocar na hora de ligar.',
              trailing: EgSegmentedControl<AwakeDuration>(
                value: settings.defaultDuration,
                options: AwakeDuration.options,
                labelOf: (option) => option.label,
                onChanged: viewModel.setDefaultDuration,
              ),
            ),
          ],
        ),
        GlobalShortcutSection(slot: GlobalShortcutSlot.awake),
      ],
    );
  }
}

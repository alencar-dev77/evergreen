import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/system/global_shortcut_service.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../models/awake_duration.dart';
import '../viewmodels/awake_settings_view_model.dart';

/// Tela do Awake dentro do Hub.
///
/// O módulo tem uma preferência só, e é assim que deve ser: o que muda de uma
/// vez para outra é a duração, e essa escolha vive no painel, junto do botão
/// que liga. Aqui fica apenas com qual delas o painel abre.
class AwakeSettingsView extends ConsumerWidget {
  const AwakeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(awakeSettingsViewModelProvider);
    final viewModel = ref.read(awakeSettingsViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgSettingsSection(
          title: 'Geral',
          children: [
            EgSettingsRow(
              label: 'Duração padrão',
              description:
                  'Por quanto tempo o painel propõe manter a tela acesa. Dá '
                  'para trocar na hora de ligar.',
              showDivider: false,
              trailing: EgSegmentedControl<AwakeDuration>(
                value: settings.defaultDuration,
                options: AwakeDuration.options,
                labelOf: (option) => option.label,
                onChanged: viewModel.setDefaultDuration,
              ),
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Atalho global',
          children: [
            EgSettingsRow(
              label: 'Abrir Awake',
              description: 'Funciona com qualquer aplicativo em foco.',
              showDivider: false,
              trailing: const EgShortcutDisplay(
                keys: GlobalShortcutService.awakeShortcutKeys,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

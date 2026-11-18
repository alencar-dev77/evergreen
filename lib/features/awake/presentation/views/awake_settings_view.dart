import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../pin/presentation/viewmodels/accessibility_permission_view_model.dart';
import '../../models/awake_duration.dart';
import '../../models/awake_mode.dart';
import '../../models/keyboard_lock_duration.dart';
import '../viewmodels/awake_settings_view_model.dart';

/// Tela do Awake dentro do Hub.
///
/// As preferências daqui são as que **não** mudam de uma vez para outra: o que
/// a trava segura, com qual prazo o painel abre e por quanto tempo o teclado
/// fica bloqueado. O que muda toda vez é a duração escolhida na hora, e essa
/// vive no painel, junto do botão que liga.
class AwakeSettingsView extends ConsumerStatefulWidget {
  const AwakeSettingsView({super.key});

  @override
  ConsumerState<AwakeSettingsView> createState() => _AwakeSettingsViewState();
}

class _AwakeSettingsViewState extends ConsumerState<AwakeSettingsView> {
  /// A Acessibilidade é concedida fora do Evergreen e pode ser tirada pelo
  /// sistema sem aviso — voltar a esta tela é o momento de perguntar de novo.
  @override
  void initState() {
    super.initState();
    ref.read(accessibilityPermissionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(awakeSettingsViewModelProvider);
    final viewModel = ref.read(awakeSettingsViewModelProvider.notifier);
    final hasPermission = ref.watch(accessibilityPermissionProvider);

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
        EgSettingsCard(
          title: 'Bloquear o teclado',
          children: [
            EgSettingsRow(
              label: 'Tempo do bloqueio',
              description:
                  'Nenhuma tecla chega aos apps até o tempo acabar. O mouse e '
                  'o trackpad continuam funcionando, e clicar fora do painel '
                  'desbloqueia antes.',
              trailing: EgSegmentedControl<KeyboardLockDuration>(
                value: settings.keyboardLockDuration,
                options: KeyboardLockDuration.options,
                labelOf: (option) => option.label,
                onChanged: viewModel.setKeyboardLockDuration,
              ),
            ),
            // Só quando falta: com a permissão dada, um aviso permanente vira
            // ruído que ninguém mais lê.
            if (!hasPermission)
              EgSettingsRow(
                label: 'Permissão de Acessibilidade',
                description:
                    'Sem ela, o macOS não deixa o Evergreen bloquear o '
                    'teclado.',
                trailing: EgButton.secondary(
                  label: 'Permitir',
                  onPressed: ref
                      .read(accessibilityPermissionProvider.notifier)
                      .request,
                ),
              ),
          ],
        ),
        GlobalShortcutSection(slot: GlobalShortcutSlot.awake),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_info.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/system/global_shortcut_service.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../viewmodels/app_settings_view_model.dart';

/// Preferências do Evergreen como aplicativo.
///
/// Existe porque, com dois módulos, "iniciar com o macOS" e "abrir minimizado"
/// já não cabiam na tela do Pin — elas nunca foram do Pin, moravam lá por ele
/// ter sido o primeiro. Aqui também fica o atalho que abre esta janela, que não
/// tinha onde ser ensinado.
class AppSettingsView extends ConsumerWidget {
  const AppSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsViewModelProvider);
    final viewModel = ref.read(appSettingsViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgSettingsSection(
          title: 'Geral',
          children: [
            EgSettingsRow.toggle(
              label: 'Iniciar com o macOS',
              description: 'O Evergreen sobe junto com o sistema.',
              value: settings.launchAtLogin,
              onChanged: viewModel.setLaunchAtLogin,
            ),
            EgSettingsRow.toggle(
              label: 'Abrir minimizado',
              description: 'Fica só na barra de menus, sem abrir janelas.',
              value: settings.startMinimized,
              onChanged: viewModel.setStartMinimized,
              showDivider: false,
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Atalho global',
          children: [
            EgSettingsRow(
              label: 'Abrir preferências',
              description: 'Traz esta janela para a frente de qualquer lugar.',
              showDivider: false,
              trailing: const EgShortcutDisplay(
                keys: GlobalShortcutService.hubShortcutKeys,
              ),
            ),
          ],
        ),
        const EgSettingsSection(
          title: 'Sobre',
          children: [_AboutLine()],
        ),
      ],
    );
  }
}

class _AboutLine extends StatelessWidget {
  const _AboutLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        'Evergreen ${AppInfo.versionLabel}\n'
        'Todos os dados ficam nesta máquina. Nada é enviado para a internet.',
        style: AppTypography.captionSmall,
      ),
    );
  }
}

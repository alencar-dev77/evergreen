import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/system/global_shortcut_service.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../models/pin_settings.dart';
import '../viewmodels/pin_settings_view_model.dart';

/// Configurações do módulo Pin, exibidas dentro do Hub.
class PinSettingsView extends ConsumerWidget {
  const PinSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pinSettingsViewModelProvider);
    final viewModel = ref.read(pinSettingsViewModelProvider.notifier);

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
            ),
            EgSettingsRow.toggle(
              label: 'Colar automaticamente',
              description:
                  'Ao escolher um item, cola direto no app anterior (⌘V). '
                  'Requer permissão de Acessibilidade do macOS.',
              value: settings.autoPaste,
              onChanged: viewModel.setAutoPaste,
              showDivider: false,
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Atalho global',
          children: [
            EgSettingsRow(
              label: 'Abrir Pin',
              description: 'Funciona com qualquer aplicativo em foco.',
              showDivider: false,
              trailing: const EgShortcutDisplay(
                keys: GlobalShortcutService.pinShortcutKeys,
              ),
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Histórico',
          children: [
            EgSettingsRow(
              label: 'Itens mantidos',
              description: 'Itens fixados nunca são removidos.',
              trailing: EgSegmentedControl<int>(
                value: settings.historyLimit,
                options: PinSettings.historyLimitOptions,
                labelOf: (option) => '$option',
                onChanged: viewModel.setHistoryLimit,
              ),
            ),
            EgSettingsRow(
              label: 'Limpar histórico',
              description: 'Remove todos os itens não fixados.',
              showDivider: false,
              trailing: EgButton.destructive(
                label: 'Limpar',
                onPressed: () => _clearHistory(context, ref),
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

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmClear(context);
    if (!confirmed) return;

    ref.read(clipboardRepositoryProvider).clearAll();
  }

  /// Apagar o histórico é irreversível — a única ação do Pin que pede
  /// confirmação.
  Future<bool> _confirmClear(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Todos os itens não fixados serão removidos. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

class _AboutLine extends StatelessWidget {
  const _AboutLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        'Evergreen v0.1.0 · Pin\nTodos os dados ficam nesta máquina. Nada é enviado para a internet.',
        style: AppTypography.captionSmall,
      ),
    );
  }
}

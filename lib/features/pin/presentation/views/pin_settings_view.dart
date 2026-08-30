import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../models/pin_settings.dart';
import '../viewmodels/accessibility_permission_view_model.dart';
import '../viewmodels/pin_settings_view_model.dart';

/// Configurações do módulo Pin, exibidas dentro do Hub.
class PinSettingsView extends ConsumerStatefulWidget {
  const PinSettingsView({super.key});

  @override
  ConsumerState<PinSettingsView> createState() => _PinSettingsViewState();
}

class _PinSettingsViewState extends ConsumerState<PinSettingsView> {
  /// Pergunta ao sistema a cada abertura da tela.
  ///
  /// A permissão é concedida fora do Evergreen, nos Ajustes do macOS, e pode
  /// ser retirada pelo próprio sistema sem aviso — voltar a esta tela é
  /// exatamente o momento em que a resposta guardada não vale mais nada.
  @override
  void initState() {
    super.initState();
    ref.read(accessibilityPermissionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(pinSettingsViewModelProvider);
    final viewModel = ref.read(pinSettingsViewModelProvider.notifier);
    final hasPermission = ref.watch(accessibilityPermissionProvider);

    // Só quando há um problema real: com o auto-colar desligado a permissão não
    // faz falta nenhuma, e um aviso permanente vira ruído que ninguém mais lê.
    final needsPermission = settings.autoPaste && !hasPermission;

    return EgSettingsPage(
      children: [
        EgSettingsSection(
          title: 'Geral',
          children: [
            EgSettingsRow.toggle(
              label: 'Colar automaticamente',
              description:
                  'Ao escolher um item, cola direto no app anterior (⌘V). '
                  'Requer a permissão de Acessibilidade.',
              value: settings.autoPaste,
              onChanged: viewModel.setAutoPaste,
              showDivider: needsPermission,
            ),
            if (needsPermission)
              EgSettingsRow(
                label: 'Permissão de Acessibilidade',
                description:
                    'Sem a permissão, o item é copiado mas não colado.',
                showDivider: false,
                trailing: EgButton.secondary(
                  label: 'Permitir',
                  onPressed: ref
                      .read(accessibilityPermissionProvider.notifier)
                      .request,
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
        GlobalShortcutSection(slot: GlobalShortcutSlot.pin),
      ],
    );
  }

  /// Apagar o histórico é irreversível — a única ação do Pin que pede
  /// confirmação.
  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Limpar histórico?',
      message:
          'Todos os itens não fixados serão removidos. Não dá para desfazer.',
      confirmLabel: 'Limpar',
    );
    if (!confirmed) return;

    ref.read(clipboardRepositoryProvider).clearAll();
  }
}

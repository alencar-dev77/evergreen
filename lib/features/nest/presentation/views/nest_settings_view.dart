import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../models/nest_settings.dart';
import '../../models/nest_transfer_mode.dart';
import '../viewmodels/nest_settings_view_model.dart';
import '../widgets/nest_destination_list.dart';

/// Tela do Nest dentro do Hub.
///
/// A ordem é a das telas de preferência do aplicativo: o que ele faz (o modo e
/// o chacoalhar), as pastas para onde ele manda, e o atalho global por
/// último. Não há lista de "o que aconteceu" no topo porque o histórico do
/// módulo é do Track — o que a prateleira carregou hoje é a contagem do dia
/// reconstruído, não uma lista de arquivos que o Evergreen não guarda.
class NestSettingsView extends ConsumerWidget {
  const NestSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(nestSettingsViewModelProvider);
    final viewModel = ref.read(nestSettingsViewModelProvider.notifier);

    return EgSettingsPage(
      children: [
        EgSettingsCard(
          title: 'Geral',
          children: [
            EgSettingsRow.toggle(
              label: 'Chacoalhar para chamar a prateleira',
              description:
                  'Sacuda o mouse no meio de um arraste e a prateleira vem '
                  'até o cursor.',
              value: settings.useShake,
              onChanged: (value) =>
                  unawaited(viewModel.setUseShake(enabled: value)),
            ),
            EgSettingsRow(
              label: 'Ao enviar para uma pasta',
              description:
                  'Copiar deixa o original onde está; mover leva junto. '
                  'Segurar ⌥ ao enviar faz o contrário.',
              trailing: EgSegmentedControl<NestTransferMode>(
                value: settings.defaultMode,
                options: NestTransferMode.options,
                labelOf: (option) => option.label,
                onChanged: (mode) => unawaited(viewModel.setDefaultMode(mode)),
              ),
            ),
          ],
        ),
        EgSettingsCard(
          title: 'Pastas de destino',
          children: [
            if (settings.destinations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Sem pasta aqui, a prateleira guarda arquivos e não tem '
                  'para onde mandá-los. As cadastradas viram ⌘1, ⌘2, ⌘3.',
                  style: context.eg.text.caption,
                ),
              )
            else
              NestDestinationList(
                destinations: settings.destinations,
                onRename: (index, alias) =>
                    unawaited(viewModel.renameDestination(index, alias)),
                onRemove: (index) =>
                    unawaited(viewModel.removeDestination(index)),
              ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: EgButton.secondary(
                label: 'Adicionar pasta…',
                onPressed: settings.isFull
                    ? null
                    : () => unawaited(viewModel.addDestination()),
              ),
            ),
            if (settings.isFull) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Máximo de ${NestSettings.maxDestinations} — o que o '
                'teclado alcança sem procurar.',
                style: context.eg.text.caption,
              ),
            ],
          ],
        ),
        GlobalShortcutSection(slot: GlobalShortcutSlot.nest),
      ],
    );
  }
}

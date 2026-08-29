import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/system/global_shortcut_service.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../models/nest_settings.dart';
import '../../models/nest_transfer_mode.dart';
import '../viewmodels/nest_settings_view_model.dart';
import '../widgets/nest_destination_list.dart';

/// Tela do Nest dentro do Hub.
///
/// A ordem é a das telas de preferência do aplicativo: o que ele faz (o modo e
/// o recorte da tela), as pastas para onde ele manda, e o atalho global por
/// último. Não há lista de "o que aconteceu" no topo porque o histórico do
/// módulo é do Track — o que a prateleira carregou hoje é a contagem do dia
/// reconstruído, não uma lista de arquivos que o Evergreen não guarda.
class NestSettingsView extends ConsumerWidget {
  const NestSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(nestSettingsViewModelProvider);
    final viewModel = ref.read(nestSettingsViewModelProvider.notifier);

    // Enquanto a pergunta não voltou, a linha não aparece: um controle que
    // nasce e some depois de meio segundo é pior que um que nunca esteve lá.
    final hasNotch = ref.watch(nestHasNotchProvider).value ?? false;

    return EgSettingsPage(
      children: [
        EgSettingsSection(
          title: 'Geral',
          children: [
            if (hasNotch)
              EgSettingsRow.toggle(
                label: 'Receber arquivos pelo recorte da tela',
                description:
                    'Arraste qualquer arquivo até o recorte no topo e solte. A '
                    'prateleira abre com ele dentro, sem atalho nenhum.',
                value: settings.useNotch,
                onChanged: (value) =>
                    unawaited(viewModel.setUseNotch(enabled: value)),
              ),
            EgSettingsRow(
              label: 'Ao enviar para uma pasta',
              description:
                  'Copiar deixa o original onde está; mover leva junto. '
                  'Segurar ⌥ na hora de enviar faz o contrário do que estiver '
                  'escolhido aqui.',
              showDivider: false,
              trailing: EgSegmentedControl<NestTransferMode>(
                value: settings.defaultMode,
                options: NestTransferMode.options,
                labelOf: (option) => option.label,
                onChanged: (mode) => unawaited(viewModel.setDefaultMode(mode)),
              ),
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Pastas de destino',
          children: [
            if (settings.destinations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Sem nenhuma pasta aqui, a prateleira guarda arquivos mas não '
                  'tem para onde mandá-los. Cadastre as pastas que você usa '
                  'toda semana — elas viram ⌘1, ⌘2, ⌘3 dentro do painel.',
                  style: context.eg.text.captionSmall,
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
                'São ${NestSettings.maxDestinations} pastas no máximo — o '
                'tanto que o teclado alcança sem procurar.',
                style: context.eg.text.captionSmall,
              ),
            ],
          ],
        ),
        EgSettingsSection(
          title: 'Atalho global',
          children: [
            EgSettingsRow(
              label: 'Abrir Nest',
              description: 'Funciona com qualquer aplicativo em foco.',
              showDivider: false,
              trailing: const EgShortcutDisplay(
                keys: GlobalShortcutService.nestShortcutKeys,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

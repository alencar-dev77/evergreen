import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/eg_tokens.dart';
import '../../../../core/local_model/lm_studio_local_model.dart';
import '../../../../core/local_model/local_model.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../viewmodels/app_settings_view_model.dart';
import '../viewmodels/local_model_view_model.dart';

/// Quem escreve o resumo das reuniões e o parágrafo do dia.
///
/// Na tela do aplicativo, e não na do Echo, porque o Track também usa. Duas
/// partes: a origem, sempre; e, com o LM Studio, o que o servidor diz — os
/// modelos que ele tem, ou por que não há nenhum para mostrar.
class LocalModelSection extends ConsumerWidget {
  const LocalModelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
      appSettingsViewModelProvider.select((settings) => settings.localModel),
    );
    final status = ref.watch(localModelViewModelProvider);

    return EgSettingsCard(
      title: 'Modelo local',
      children: [
        EgSettingsRow(
          label: 'Quem escreve',
          description: 'O resumo das reuniões e o parágrafo do dia.',
          trailing: EgSegmentedControl<LocalModelSource>(
            value: choice.source,
            options: LocalModelSource.values,
            labelOf: (source) => switch (source) {
              LocalModelSource.apple => LocalModelChoice.appleName,
              LocalModelSource.lmStudio => 'LM Studio',
            },
            onChanged: (source) => unawaited(
              ref
                  .read(appSettingsViewModelProvider.notifier)
                  .setLocalModelSource(source),
            ),
          ),
        ),
        if (choice.source == LocalModelSource.lmStudio)
          ..._lmStudio(context, ref, choice, status),
      ],
    );
  }

  List<Widget> _lmStudio(
    BuildContext context,
    WidgetRef ref,
    LocalModelChoice choice,
    LocalModelStatus status,
  ) {
    final viewModel = ref.read(localModelViewModelProvider.notifier);

    return switch (status.server) {
      LmStudioServerState.idle || LmStudioServerState.checking => [
        const EgSettingsRow(
          label: 'LM Studio',
          description: 'Procurando o servidor…',
          trailing: SizedBox.shrink(),
        ),
      ],
      LmStudioServerState.notInstalled => [
        const EgSettingsRow(
          label: 'LM Studio não encontrado',
          description: 'Instale o LM Studio e baixe um modelo nele.',
          trailing: SizedBox.shrink(),
        ),
      ],
      // O Evergreen nunca liga o servidor sozinho: abrir o processo de outro
      // programa é coisa que só acontece quando a pessoa clica.
      LmStudioServerState.offline => [
        EgSettingsRow(
          label: 'Servidor do LM Studio desligado',
          description: 'Sem ele, o resumo e o parágrafo do dia não saem.',
          trailing: EgButton.secondary(
            label: 'Ligar',
            isLoading: status.isStarting,
            onPressed: () => unawaited(viewModel.startServer()),
          ),
        ),
      ],
      LmStudioServerState.online when status.models.isEmpty => [
        const EgSettingsRow(
          label: 'Nenhum modelo baixado',
          description: 'Baixe um modelo no LM Studio para ele aparecer aqui.',
          trailing: SizedBox.shrink(),
        ),
      ],
      LmStudioServerState.online => [
        for (final model in status.models)
          _ModelRow(
            model: model,
            isChosen: model.key == choice.modelId,
            onChoose: () => unawaited(viewModel.choose(model)),
          ),
      ],
    };
  }
}

/// Um modelo do LM Studio: o nome, quanto ele lê, e se está na memória.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.isChosen,
    required this.onChoose,
  });

  final LmStudioModel model;
  final bool isChosen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgSettingsRow(
      label: model.displayName,
      description: describe(model),
      // O escolhido diz isso em texto, no lugar do botão: um "Usar" desligado
      // ao lado do modelo que já está em uso seria um controle que não faz
      // nada.
      trailing: isChosen
          ? Text(
              'Em uso',
              style: eg.text.caption.copyWith(color: eg.colors.textTertiary),
            )
          : EgButton.secondary(
              label: 'Usar',
              compact: true,
              onPressed: onChoose,
            ),
    );
  }

  /// "Lê até 262 mil tokens · na memória".
  static String? describe(LmStudioModel model) {
    final context = model.maxContextLength;
    final parts = [
      if (context != null) 'Lê até ${(context / 1000).round()} mil tokens',
      if (model.isLoaded) 'na memória',
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }
}

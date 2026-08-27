import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/app_info.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/storage/backup_service.dart';
import '../../../../core/system/global_shortcut_service.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../viewmodels/app_settings_view_model.dart';
import '../viewmodels/backup_view_model.dart';
import '../widgets/backup_list.dart';

/// Preferências do Evergreen como aplicativo.
///
/// Existe porque, com dois módulos, "iniciar com o macOS" e "abrir minimizado"
/// já não cabiam na tela do Pin — elas nunca foram do Pin, moravam lá por ele
/// ter sido o primeiro. Aqui também fica o atalho que abre esta janela, que não
/// tinha onde ser ensinado, e o backup, que é do banco inteiro e portanto de
/// nenhum módulo em particular.
class AppSettingsView extends ConsumerStatefulWidget {
  const AppSettingsView({super.key});

  @override
  ConsumerState<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends ConsumerState<AppSettingsView> {
  @override
  void initState() {
    super.initState();

    // O backup automático roda no engine da janela flutuante, que não avisa
    // este aqui. Reler a pasta ao abrir a tela é o que faz o backup de ontem
    // aparecer na lista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(backupViewModelProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        _BackupSection(
          isAutomatic: settings.automaticBackup,
          onAutomaticChanged: viewModel.setAutomaticBackup,
        ),
        const _RestoreSection(),
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

/// Fazer o backup — o automático e o de agora — e onde ele fica.
class _BackupSection extends ConsumerWidget {
  const _BackupSection({
    required this.isAutomatic,
    required this.onAutomaticChanged,
  });

  final bool isAutomatic;
  final ValueChanged<bool> onAutomaticChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupViewModelProvider);
    final viewModel = ref.read(backupViewModelProvider.notifier);
    final latest = state.latest;
    // Pelo relógio da aplicação, e não pelo `DateTime.now()` de dentro do
    // `RelativeTime`: é o mesmo motivo do cronômetro do Focus — sem esta
    // costura não dá para verificar "há 8 dias" sem esperar oito dias.
    final now = ref.watch(clockProvider)();

    return EgSettingsSection(
      title: 'Backup',
      children: [
        EgSettingsRow.toggle(
          label: 'Backup semanal automático',
          description: 'Uma cópia do banco por semana, guardada nesta máquina. '
              'Ficam as ${BackupService.maxBackups} mais recentes; as antigas '
              'saem sozinhas.',
          value: isAutomatic,
          onChanged: onAutomaticChanged,
        ),
        EgSettingsRow(
          label: 'Fazer um backup agora',
          description: latest == null
              ? 'Nenhum backup ainda.'
              : 'Último backup: '
                  '${RelativeTime.format(latest.createdAt, now: now)}.',
          trailing: EgButton.secondary(
            label: 'Fazer backup',
            onPressed: viewModel.createNow,
          ),
        ),
        EgSettingsRow(
          label: 'Pasta dos backups',
          // O caminho na tela porque a pergunta "onde isso foi parar" não pode
          // depender de abrir o Finder para descobrir.
          description: state.directoryLabel,
          showDivider: false,
          trailing: EgButton.secondary(
            label: 'Mostrar no Finder',
            onPressed: () => unawaited(viewModel.reveal()),
          ),
        ),
      ],
    );
  }
}

/// Escolher um backup e pôr o conteúdo dele de volta.
class _RestoreSection extends ConsumerWidget {
  const _RestoreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupViewModelProvider);
    final viewModel = ref.read(backupViewModelProvider.notifier);

    return EgSettingsSection(
      title: 'Restaurar',
      children: [
        if (state.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'Nenhum backup na pasta ainda. Um arquivo .db colocado lá também '
              'aparece aqui — é assim que se traz o backup de outra máquina.',
              style: AppTypography.captionSmall,
            ),
          )
        else ...[
          BackupList(
            backups: state.backups,
            selectedPath: state.selectedPath,
            now: ref.watch(clockProvider)(),
            onSelect: viewModel.select,
          ),
          const SizedBox(height: AppSpacing.sm),
          EgSettingsRow(
            label: 'Restaurar o backup escolhido',
            description:
                'Troca tudo o que está no Evergreen pelo conteúdo do backup. '
                'O estado de agora vira antes uma cópia "antes de restaurar" '
                'na lista, então dá para voltar.',
            showDivider: false,
            trailing: EgButton.secondary(
              label: 'Restaurar',
              // Sem nada escolhido não há o que restaurar: o botão fica
              // apagado em vez de sumir, para que a ação continue visível.
              onPressed: state.selected == null
                  ? null
                  : () => unawaited(_restore(context, ref)),
            ),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            state.message!,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  /// Restaurar apaga tudo de uma vez — pede confirmação, como o "Limpar
  /// histórico" do Pin e do Focus. É a única pergunta de sim ou não da tela, e
  /// pergunta de sim ou não é exatamente o que um modal faz bem.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final backup = ref.read(backupViewModelProvider).selected;
    if (backup == null) return;

    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Restaurar este backup?',
      message: 'O histórico do Pin, as sessões do Focus, as anotações do Leaf '
          'e as reuniões do Echo passam a ser os do backup. O estado de agora '
          'é guardado antes de qualquer coisa, e volta para a lista como '
          '"antes de restaurar".',
      confirmLabel: 'Restaurar',
    );
    if (!confirmed) return;

    ref.read(backupViewModelProvider.notifier).restoreSelected();
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

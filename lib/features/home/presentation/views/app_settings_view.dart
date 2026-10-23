import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/storage/backup_service.dart';
import '../../../../core/storage/disk_usage_service.dart';
import '../../../../core/system/global_shortcut_slot.dart';
import '../../../../core/system/update_service.dart';
import '../../../../shared/utils/byte_size.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_pill.dart';
import '../../../../shared/widgets/eg_shortcut_grid.dart';
import '../../models/evergreen_module.dart';
import '../viewmodels/app_settings_view_model.dart';
import '../viewmodels/module_settings_view_model.dart';
import '../widgets/global_shortcut_section.dart';
import '../widgets/local_model_section.dart';
import '../viewmodels/backup_view_model.dart';
import '../viewmodels/diagnostics_view_model.dart';
import '../viewmodels/hub_detail_view_model.dart';
import '../viewmodels/updates_view_model.dart';
import '../viewmodels/disk_usage_view_model.dart';
import '../widgets/backup_list.dart';
import '../widgets/uninstall_section.dart';
import '../../../../core/design/eg_tokens.dart';

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
  late final TextEditingController _name;
  final _nameFocus = FocusNode(debugLabel: 'app-user-name');

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(
      text: ref.read(appSettingsViewModelProvider).userName,
    );
    // Guarda ao sair do campo, por qualquer caminho — a mesma regra do apelido
    // do Pin e dos campos do Echo.
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) return;
      ref.read(appSettingsViewModelProvider.notifier).setUserName(_name.text);
    });

    // O backup automático roda no engine da janela flutuante, que não avisa
    // este aqui. Reler a pasta ao abrir a tela é o que faz o backup de ontem
    // aparecer na lista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(backupViewModelProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsViewModelProvider);
    final viewModel = ref.read(appSettingsViewModelProvider.notifier);

    // Sem nome, a pergunta abre a tela; com nome, ela vira uma linha comum
    // dentro de "Geral". É a mesma pergunta nos dois casos — o que muda é
    // quanto ela pesa: no primeiro dia ela é a única coisa que o Evergreen tem
    // a perguntar, e depois é só mais um campo que se pode corrigir.
    final hasName = settings.userName.isNotEmpty;

    return EgSettingsPage(
      footer: const _AboutLine(),
      children: [
        if (!hasName)
          EgSettingsCard(
            title: 'Como você se chama',
            children: [_nameField(autofocus: true)],
          ),
        EgSettingsCard(
          title: 'Sistema',
          children: [
            if (hasName) _nameField(autofocus: false),
            // As duas da partida ficam juntas, nesta ordem: uma decide **se** o
            // Evergreen sobe, a outra decide **como** ele sobe. Separadas pelo
            // atalho, a segunda parecia responder a outra pergunta.
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
            // O atalho do Hub mora aqui dentro, e não numa seção própria: uma
            // seção inteira para uma pergunta é o que fazia esta tela ter mais
            // títulos do que respostas.
            const GlobalShortcutSection(
              slot: GlobalShortcutSlot.hub,
              bare: true,
            ),
          ],
        ),
        // Logo depois de "Sistema": é a outra pergunta sobre como o Evergreen
        // funciona, e não sobre o que ele guarda — que é do disco para baixo.
        const LocalModelSection(),
        const _ShortcutMapCard(),
        const _DiskUsageSection(),
        _BackupSection(
          isAutomatic: settings.automaticBackup,
          onAutomaticChanged: viewModel.setAutomaticBackup,
        ),
        const _RestoreSection(),
        const _DiagnosticsSection(),
        const _UpdatesSection(),
        const _AboutSection(),
        const UninstallSection(),
      ],
    );
  }

  /// O campo do nome, o mesmo nos dois lugares em que ele aparece.
  ///
  /// A descrição muda com o estado porque a pergunta muda: no primeiro dia é
  /// preciso dizer para que serve, e depois já se sabe.
  Widget _nameField({required bool autofocus}) {
    return EgSettingsRow.field(
      label: 'Seu nome',
      description: autofocus
          ? 'O resumo da reunião e o parágrafo do dia passam a chamar você '
                'pelo nome. Fica nesta máquina, e dá para deixar em branco.'
          : 'Como o resumo e a transcrição chamam você.',
      field: EgTextField(
        controller: _name,
        focusNode: _nameFocus,
        autofocus: autofocus,
        hintText: 'Seu primeiro nome',
      ),
    );
  }
}

/// Quanto o Evergreen ocupa no disco, e onde.
///
/// Logo acima do backup porque é ele, junto com o áudio das reuniões, que faz
/// o número crescer — e é ali embaixo que se decide quantos backups ficam.
class _DiskUsageSection extends ConsumerWidget {
  const _DiskUsageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(diskUsageViewModelProvider);
    final viewModel = ref.read(diskUsageViewModelProvider.notifier);

    return EgSettingsCard(
      title: 'Espaço em disco',
      children: [
        EgSettingsRow(
          label: 'Ocupado pelo Evergreen',
          description: usage == null ? 'Medindo…' : _breakdown(usage),
          trailing: Text(
            usage == null ? '—' : ByteSize.compact(usage.total),
            style: context.eg.text.bodyStrong,
          ),
        ),
        EgSettingsRow(
          label: 'Pasta do aplicativo',
          description: viewModel.directoryLabel,
          trailing: EgButton.secondary(
            label: 'Mostrar no Finder',
            onPressed: () => unawaited(viewModel.reveal()),
          ),
        ),
      ],
    );
  }

  /// As partes que existem, na ordem de quem costuma pesar mais. Parte vazia
  /// some: "Exportações 0 B" responde uma pergunta que ninguém fez.
  static String _breakdown(DiskUsage usage) {
    final parts = [
      ('Banco', usage.database),
      ('Áudio das reuniões', usage.meetings),
      ('Backups', usage.backups),
      ('Exportações', usage.exports),
    ];

    final present = [
      for (final (label, bytes) in parts)
        if (bytes > 0) '$label ${ByteSize.compact(bytes)}',
    ];

    return present.isEmpty ? 'Nada guardado ainda.' : present.join(' · ');
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

    return EgSettingsCard(
      title: 'Backup',
      children: [
        EgSettingsRow.toggle(
          label: 'Backup semanal automático',
          description:
              'Uma cópia por semana, nesta máquina. Ficam as '
              '${BackupService.maxBackups} mais recentes. O áudio das '
              'reuniões não entra.',
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

    return EgSettingsCard(
      title: 'Restaurar',
      children: [
        if (state.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'A pasta está vazia. Um arquivo .db posto nela também aparece '
              'aqui: é assim que se traz o de outra máquina.',
              style: context.eg.text.caption,
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
                'Troca tudo pelo conteúdo do backup. O estado de agora vira '
                'a cópia "antes de restaurar".',
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
            style: context.eg.text.caption.copyWith(
              color: context.eg.colors.textSecondary,
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
      message:
          'Histórico, sessões, anotações e reuniões passam a ser os do '
          'backup. O estado de agora volta para a lista como "antes de '
          'restaurar".',
      confirmLabel: 'Restaurar',
    );
    if (!confirmed) return;

    ref.read(backupViewModelProvider.notifier).restoreSelected();
  }
}

/// O que levar quando o Evergreen falha: um texto para colar numa issue e as
/// duas pastas de onde o resto vem.
///
/// Por último porque é onde se vai num dia ruim, e não toda semana. A
/// descrição diz o que **não** vai junto: quem cola isso num lugar público
/// precisa saber, antes de colar, que a área de transferência dele não está
/// ali.
class _DiagnosticsSection extends ConsumerWidget {
  const _DiagnosticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copied = ref.watch(diagnosticsViewModelProvider);
    final viewModel = ref.read(diagnosticsViewModelProvider.notifier);

    return EgSettingsCard(
      title: 'Diagnóstico',
      children: [
        EgSettingsRow(
          label: 'Copiar diagnóstico',
          description: copied
              ? 'Diagnóstico copiado.'
              : 'Versão, sistema, módulos, permissões e o fim do registro. '
                    'Nada do que você copiou, anotou ou gravou vai junto.',
          trailing: EgButton.secondary(
            label: 'Copiar',
            onPressed: () => unawaited(viewModel.copy()),
          ),
        ),
        EgSettingsRow(
          label: 'Registro de erros',
          description: viewModel.logLabel,
          trailing: EgButton.secondary(
            label: 'Mostrar no Finder',
            onPressed: () => unawaited(viewModel.revealLog()),
          ),
        ),
        EgSettingsRow(
          label: 'Falhas do macOS',
          description:
              'Os relatórios que o sistema guarda quando um app fecha '
              'sozinho, em ${viewModel.crashReportsLabel}.',
          trailing: EgButton.secondary(
            label: 'Mostrar no Finder',
            onPressed: () => unawaited(viewModel.revealCrashReports()),
          ),
        ),
      ],
    );
  }
}

/// Se o Evergreen procura versão nova, e o "procurar agora".
///
/// Logo antes do "Sobre", porque é a outra pergunta sobre o Evergreen como
/// software. A preferência é do Sparkle, não do `AppSettings` — ver
/// `UpdatesViewModel`. Numa build de desenvolvimento a seção diz que esta
/// cópia não se atualiza, em vez de sumir: sumida, a falta dela pareceria
/// esquecimento.
class _UpdatesSection extends ConsumerWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(updatesViewModelProvider).value;
    final viewModel = ref.read(updatesViewModelProvider.notifier);
    final now = ref.watch(clockProvider)();

    // Ainda perguntando ao lado nativo: nada a mostrar por um quadro.
    if (updates == null) return const SizedBox.shrink();

    if (!updates.available) {
      return const EgSettingsCard(
        title: 'Atualizações',
        children: [
          EgSettingsRow(
            label: 'Esta cópia não se atualiza sozinha',
            description:
                'É uma build de desenvolvimento. A versão publicada procura '
                'versão nova no GitHub.',
            trailing: SizedBox.shrink(),
          ),
        ],
      );
    }

    final version = updates.hasUpdate ? updates.version : null;

    return EgSettingsCard(
      title: 'Atualizações',
      children: [
        EgSettingsRow.toggle(
          label: 'Procurar atualizações automaticamente',
          description:
              'Uma vez por dia o Evergreen pergunta ao GitHub se há versão '
              'nova. A pergunta não leva nada seu.',
          value: updates.automaticChecks,
          onChanged: (enabled) =>
              unawaited(viewModel.setAutomaticChecks(enabled)),
        ),
        if (version != null)
          EgSettingsRow(
            label: 'Versão $version disponível',
            description:
                'Veja o que mudou e atualize — o Evergreen fecha, '
                'instala e abre de novo.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A mesma bolinha do botão "Aplicativo": quem a seguiu até
                // aqui reconhece onde ela dava.
                EgStatusDot(color: context.eg.colors.accent),
                const SizedBox(width: AppSpacing.sm),
                EgButton(
                  label: 'Ver novidades',
                  onPressed: () =>
                      ref.read(updatePresentationProvider.notifier).open(),
                ),
              ],
            ),
          )
        else
          EgSettingsRow(
            label: 'Procurar agora',
            description: _checkDescription(updates, now),
            trailing: EgButton.secondary(
              label: 'Procurar',
              isLoading: updates.phase == UpdatePhase.checking,
              onPressed: updates.canCheck
                  ? () => unawaited(viewModel.checkNow())
                  : null,
            ),
          ),
      ],
    );
  }

  /// O que a última procura disse — ou quando ela foi.
  static String _checkDescription(UpdateState updates, DateTime now) {
    if (updates.phase == UpdatePhase.checking) return 'Procurando…';
    // O resultado só fica enquanto for o da procura mais recente — ver
    // `UpdateState.hasFreshResult`.
    if (updates.hasFreshResult) {
      if (updates.phase == UpdatePhase.upToDate) {
        return 'Você está na versão mais nova.';
      }
      if (updates.phase == UpdatePhase.error) {
        return 'A última tentativa não deu certo. Tente de novo mais tarde.';
      }
    }

    return switch (updates.lastCheck) {
      null => 'Ainda não procurou.',
      final last => 'Última procura: ${RelativeTime.format(last, now: now)}.',
    };
  }
}

/// O que o Evergreen é, como software: a licença dele e a de quem ele usa.
///
/// Logo acima do desinstalar, que é a ação destrutiva e fecha a tela. As
/// licenças abrem na região de leitura, como uma reunião do Echo.
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(appDetailProvider) == AppDetail.licenses;

    return EgSettingsCard(
      title: 'Sobre',
      children: [
        EgSettingsRow(
          label: 'Licenças',
          description:
              'O Evergreen é código aberto, sob a GPL-3.0. Aqui também estão '
              'as licenças dos componentes que ele usa.',
          trailing: EgButton.secondary(
            label: isOpen ? 'Fechar' : 'Ver',
            onPressed: () =>
                ref.read(appDetailProvider.notifier).toggle(AppDetail.licenses),
          ),
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
      // A versão saiu daqui: ela subiu para o cabeçalho da tela, e dizer o
      // mesmo número duas vezes na mesma janela não confirma nada — só ocupa
      // a linha em que caberia a promessa da casa.
      child: Row(
        children: [
          Expanded(
            child: Text(
              // O que é seu, e não "nada": a procura por versão nova e o
              // download do modelo de vozes saem do app, e a promessa não pode
              // ir além da PRIVACY.md — que é o que ela diz.
              'seus dados ficam neste Mac · sem conta · sem sync',
              style: context.eg.text.monoSmall.copyWith(
                color: context.eg.colors.textQuaternary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Todas as teclas do app num lugar só.
///
/// A barra lateral já mostra a de cada módulo, mas uma por linha, espalhada
/// pela altura da janela — para responder "qual era mesmo o do Nest?" é
/// preciso varrer sete linhas em três grupos. Aqui elas se leem de uma vez.
///
/// Módulo desligado continua na grade, apagado: some daqui seria esconder que
/// a tecla dele **segue reservada**, e a pessoa tentaria usá-la noutro módulo
/// só para ouvir que o atalho já é de alguém.
class _ShortcutMapCard extends ConsumerWidget {
  const _ShortcutMapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(moduleSettingsViewModelProvider);

    return EgSettingsCard(
      title: 'Todos os atalhos num lugar',
      children: [
        EgShortcutGrid(
          entries: [
            for (final module in EvergreenModule.values)
              if (module.shortcutSlot case final slot?)
                EgShortcutEntry(
                  icon: module.icon,
                  label: module.name,
                  keys: settings.bindingFor(slot).caps,
                  isMuted: !settings.isEnabled(module),
                ),
            EgShortcutEntry(
              icon: EgIconData.evergreen,
              label: 'Aplicativo',
              keys: settings.bindingFor(GlobalShortcutSlot.hub).caps,
            ),
          ],
        ),
      ],
    );
  }
}

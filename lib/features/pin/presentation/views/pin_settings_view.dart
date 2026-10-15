import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../models/pin_settings.dart';
import '../../models/tax_id.dart';
import '../viewmodels/pin_generator_view_model.dart';
import '../viewmodels/pin_type_counts_view_model.dart';
import '../../../../shared/widgets/eg_toggle_pill.dart';
import '../../models/clipboard_item_type.dart';
import '../viewmodels/accessibility_permission_view_model.dart';
import '../viewmodels/pin_settings_view_model.dart';

/// Configurações do módulo Pin, exibidas dentro do Hub.
class PinSettingsView extends ConsumerStatefulWidget {
  const PinSettingsView({super.key, this.tab});

  /// A aba aberta, decidida pelo cabeçalho da tela. `null` mostra tudo — é o
  /// caminho de quem monta esta tela fora do Hub, como o teste faz.
  final String? tab;

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
    // A captura acontece no engine da janela flutuante; a contagem daqui só
    // fica em dia se este engine perguntar ao banco ao abrir a tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pinTypeCountsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(pinSettingsViewModelProvider);
    final viewModel = ref.read(pinSettingsViewModelProvider.notifier);
    final hasPermission = ref.watch(accessibilityPermissionProvider);

    // Só quando há um problema real: com o auto-colar desligado a permissão não
    // faz falta nenhuma, e um aviso permanente vira ruído que ninguém mais lê.
    final needsPermission = settings.autoPaste && !hasPermission;

    final tab = widget.tab;
    final showAll = tab == null;

    if (tab == 'Tipos') {
      return const EgSettingsPage(children: [_TypesCard()]);
    }

    if (tab == 'Gerador') {
      return const EgSettingsPage(children: [_GeneratorCard()]);
    }

    return EgSettingsPage(
      children: [
        EgSettingsCard(
          title: 'Geral',
          children: [
            EgSettingsRow.toggle(
              label: 'Colar automaticamente',
              description:
                  'Ao escolher um item, cola direto no app anterior (⌘V). '
                  'Requer a permissão de Acessibilidade.',
              value: settings.autoPaste,
              onChanged: viewModel.setAutoPaste,
            ),
            if (needsPermission)
              EgSettingsRow(
                label: 'Permissão de Acessibilidade',
                description:
                    'Sem a permissão, o item é copiado mas não colado.',
                trailing: EgButton.secondary(
                  label: 'Permitir',
                  onPressed: ref
                      .read(accessibilityPermissionProvider.notifier)
                      .request,
                ),
              ),
          ],
        ),
        EgSettingsCard(
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
          ],
        ),
        if (showAll) ...[const _TypesCard(), const _GeneratorCard()],
        // Cartão próprio, e com o tom do que ele faz: apagar não é mais um
        // ajuste do histórico, é o fim dele. Como última linha de um cartão de
        // preferências, a ação sem volta ficava com a mesma cara da linha que
        // escolhe quantos itens guardar.
        EgSettingsCard(
          title: 'Sem volta',
          tone: EgCardTone.destructive,
          children: [
            EgSettingsRow(
              label: 'Apagar histórico',
              description: 'Remove todos os itens não fixados.',
              trailing: EgButton.destructive(
                label: 'Apagar',
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
      title: 'Apagar histórico?',
      message:
          'Todos os itens não fixados serão removidos. Não dá para desfazer.',
      confirmLabel: 'Apagar',
    );
    if (!confirmed) return;

    ref.read(clipboardRepositoryProvider).clearAll();
    // As imagens das linhas que saíram, agora — e não só na próxima abertura
    // do Evergreen.
    ref.read(pinImageJanitorProvider).sweep();
  }
}

/// A bancada de documentos falsos, dentro das preferências do Pin.
///
/// Não é um ajuste, é uma ferramenta — e é por isso que ela tem cartão próprio
/// em vez de virar mais uma linha entre "itens mantidos" e "colar
/// automaticamente". O número em mono tabular ocupa a linha inteira porque é o
/// que se veio buscar; o resto do cartão é o que decide qual número é esse.
class _GeneratorCard extends ConsumerWidget {
  const _GeneratorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eg = context.eg;
    final state = ref.watch(pinGeneratorViewModelProvider);
    final viewModel = ref.read(pinGeneratorViewModelProvider.notifier);

    return EgSettingsCard(
      title: 'Gerador de documentos',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Documentos falsos, válidos no dígito verificador.',
                    style: eg.text.footnote.copyWith(
                      color: eg.colors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                EgSegmentedControl<TaxIdKind>(
                  value: state.kind,
                  options: TaxIdKind.values,
                  labelOf: (kind) => kind.label,
                  onChanged: viewModel.setKind,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // O número numa linha só para ele: em mono, catorze caracteres não
            // dividem a linha com dois botões dentro de uma coluna de cartão —
            // e um CPF quebrado ao meio deixa de ser um CPF.
            SelectableText(
              state.value,
              maxLines: 1,
              style: eg.text.mono.copyWith(
                fontSize: 20,
                color: eg.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                EgButton.secondary(
                  label: 'Outro',
                  onPressed: viewModel.regenerate,
                ),
                const SizedBox(width: AppSpacing.sm),
                EgButton(
                  label: 'Copiar',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: state.value)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Quais tipos o Pin guarda, com quantos de cada um já existem.
///
/// **Desligar deixa passar, não esconde.** O que não entra no banco não sai
/// por backup, por restauração nem por um bug de filtro — e num gerenciador de
/// área de transferência essa é a única distinção que importa. O que já foi
/// guardado continua onde está: apagar o passado é outra ação, e ela tem o
/// cartão dela.
class _TypesCard extends ConsumerWidget {
  const _TypesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pinSettingsViewModelProvider);
    final viewModel = ref.read(pinSettingsViewModelProvider.notifier);
    final counts = ref.watch(pinTypeCountsProvider);

    return EgSettingsCard(
      title: 'Tipos que entram',
      children: [
        EgTogglePillGrid(
          children: [
            for (final type in ClipboardItemType.values)
              EgTogglePill(
                label: type.filterLabel,
                isOn: settings.captures(type),
                count: counts[type],
                onChanged: (value) =>
                    viewModel.setTypeCaptured(type, captured: value),
              ),
          ],
        ),
      ],
    );
  }
}

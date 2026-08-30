import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/global_shortcut_slot.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_pill.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_status_strip.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import '../../models/leaf_note.dart';
import '../viewmodels/leaf_view_model.dart';

/// A tela do Leaf no Hub.
///
/// **Curta de propósito, e ela assume isso.** A parede não aparece aqui: ela é
/// o painel, e repetir os nove cartões no Hub seria a mesma coisa desenhada
/// duas vezes, em dois lugares que discordariam no dia em que um deles mudasse.
/// Saiu também a lista de teclas que ocupava metade da tela — o rodapé do
/// painel já ensina cada uma delas, no momento em que elas servem para algo.
///
/// O que sobra é o que só o Hub sabe fazer: dizer quanto da parede está em uso
/// e oferecer o que não cabe num painel de teclado — esvaziar tudo, com
/// pergunta, e trocar a tecla que abre.
///
/// Uma tela curta não é uma tela pobre: é o módulo dizendo que não pede nada.
/// Não preencher com nada.
class LeafSettingsView extends ConsumerStatefulWidget {
  const LeafSettingsView({super.key});

  @override
  ConsumerState<LeafSettingsView> createState() => _LeafSettingsViewState();
}

class _LeafSettingsViewState extends ConsumerState<LeafSettingsView> {
  @override
  void initState() {
    super.initState();
    // A parede é escrita no engine da janela flutuante; este é o do Hub, que
    // só descobre o que existe indo ao disco. É a mesma releitura que o Track
    // faz ao abrir, e pelo mesmo motivo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(leafViewModelProvider.notifier).prepareForOpen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(leafViewModelProvider).notes;

    return EgSettingsPage(
      banner: _strip(notes),
      children: [
        EgSettingsCard(
          title: 'Sem volta',
          tone: EgCardTone.destructive,
          children: [
            EgSettingsRow(
              label: 'Esvaziar a parede',
              description: notes.isEmpty
                  ? 'A parede já está vazia.'
                  : 'Remove as ${notes.length} de uma vez, sem desfazer.',
              trailing: EgButton.destructive(
                label: 'Esvaziar',
                onPressed: notes.isEmpty ? null : () => _clear(context),
              ),
            ),
          ],
        ),
        GlobalShortcutSection(slot: GlobalShortcutSlot.leaf),
      ],
    );
  }

  /// O que está na parede agora, numa linha — a única coisa que o Hub tem a
  /// dizer sobre um módulo que se opera inteiro pelo teclado.
  Widget _strip(List<LeafNote> notes) {
    final used = notes.length;

    if (used == 0) {
      return const EgStatusStrip(
        label: 'Parede vazia',
        detail: 'o primeiro cartão nasce ao digitar',
        tone: EgPillTone.neutral,
        shortcut: ['⌘', '⇧', 'D'],
      );
    }

    final last = notes
        .map((note) => note.changedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return EgStatusStrip(
      label: 'Em uso',
      value: '$used de ${LeafNote.maxNotes}',
      detail: 'última edição ${RelativeTime.format(last)}',
      shortcut: const ['⌘', '⇧', 'D'],
    );
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Esvaziar a parede?',
      message: 'Todas as anotações serão removidas. Não dá para desfazer.',
      confirmLabel: 'Esvaziar',
    );

    if (!confirmed) return;

    ref.read(leafRepositoryProvider).clearAll();
    if (mounted) ref.read(leafViewModelProvider.notifier).prepareForOpen();
  }
}

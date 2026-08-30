import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../models/leaf_note.dart';

/// Tela do Leaf dentro do Hub.
///
/// O módulo não tem preferência nenhuma para oferecer, e isso é a decisão, não
/// a falta dela: o limite de nove é o produto, e o tamanho da anotação é o que
/// cabe no cartão. O que sobra para esta tela é ensinar as teclas do painel —
/// que são mais do que a barra de dicas consegue mostrar de uma vez — e o botão
/// de esvaziar a parede.
class LeafSettingsView extends ConsumerWidget {
  const LeafSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EgSettingsPage(
      children: [
        EgSettingsSection(
          title: 'Dentro do painel',
          children: [
            const EgSettingsRow(
              label: 'Nova anotação',
              description:
                  'Abre um cartão na primeira vaga livre. Com as nove '
                  'ocupadas, jogue uma fora antes.',
              trailing: EgShortcutDisplay(keys: ['⌘', '+']),
            ),
            const EgSettingsRow(
              label: 'Quebrar linha',
              description:
                  'No cartão, o Enter sozinho guarda a anotação.',
              trailing: EgShortcutDisplay(keys: ['⇧', '⏎']),
            ),
            const EgSettingsRow(
              label: 'Copiar uma anotação',
              description:
                  'O número do cartão é a tecla que o copia. Copiar fecha a '
                  'parede, como no Pin.',
              trailing: EgShortcutDisplay(keys: ['⌘', '1–9']),
            ),
            const EgSettingsRow(
              label: 'Apagar a selecionada',
              description:
                  'As seguintes sobem uma vaga e a parede encolhe: nunca '
                  'fica buraco no meio.',
              showDivider: false,
              trailing: EgShortcutDisplay(keys: ['⌘', '⌫']),
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Parede',
          children: [
            EgSettingsRow(
              label: 'Esvaziar a parede',
              description:
                  'Remove as ${LeafNote.maxNotes} anotações de uma vez.',
              showDivider: false,
              trailing: EgButton.destructive(
                label: 'Esvaziar',
                onPressed: () => _clear(context, ref),
              ),
            ),
          ],
        ),
        GlobalShortcutSection(slot: GlobalShortcutSlot.leaf),
      ],
    );
  }

  /// Esvaziar é irreversível — mesma confirmação do "limpar histórico" do Pin.
  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Esvaziar a parede?',
      message: 'Todas as anotações serão removidas. Não dá para desfazer.',
      confirmLabel: 'Esvaziar',
    );
    if (!confirmed) return;

    ref.read(leafRepositoryProvider).clearAll();
  }
}

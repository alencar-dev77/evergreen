import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../../models/clipboard_item.dart';
import '../../../../core/design/eg_tokens.dart';

/// Coluna de preview do item selecionado.
///
/// Mostra o conteúdo integral (a lista só mostra a primeira linha), deixa dar
/// um apelido ao item e concentra as ações que exigem confirmação visual:
/// recopiar, fixar e excluir.
class PinPreviewPane extends StatelessWidget {
  const PinPreviewPane({
    super.key,
    required this.item,
    required this.aliasController,
    required this.aliasFocusNode,
    required this.onAliasSubmitted,
    required this.onCopy,
    required this.onTogglePin,
    required this.onDelete,
  });

  final ClipboardItem item;

  /// Campo do apelido. Controller e foco vivem na view do overlay, que precisa
  /// deles para saber quando trocar o mapa de atalhos e a barra de dicas.
  final TextEditingController aliasController;
  final FocusNode aliasFocusNode;
  final ValueChanged<String> onAliasSubmitted;

  final VoidCallback onCopy;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: AppSpacing.lg),
          _aliasField(context),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _contentCard(context)),
          const SizedBox(height: AppSpacing.xl),
          _actions(),
        ],
      ),
    );
  }

  /// O apelido fica logo abaixo do cabeçalho, colado no que ele nomeia: é
  /// identidade do item, como o tipo e a hora, e não uma ação sobre ele.
  ///
  /// Vazio na maior parte dos itens — e é assim que ele se anuncia, com o
  /// placeholder dizendo para que serve. Um campo escondido atrás de hover
  /// nunca seria descoberto por quem abre o preview justamente para entender o
  /// que dá para fazer ali.
  Widget _aliasField(BuildContext context) {
    return EgTextField(
      controller: aliasController,
      focusNode: aliasFocusNode,
      hintText: 'Apelido para achar depois',
      onSubmitted: onAliasSubmitted,
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        EgIconBadge(
          size: AppBadgeSizes.sm,
          borderRadius: context.eg.shapes.segmentAll,
          child: EgIcon(item.type.icon, size: AppIconSizes.sm),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${item.type.label} · copiado ${RelativeTime.format(item.copiedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.eg.text.overline,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        EgIconButton(
          icon: EgIconData.star,
          tooltip: item.isPinned ? 'Desafixar (⌘P)' : 'Fixar (⌘P)',
          size: AppBadgeSizes.sm,
          iconSize: AppIconSizes.xs,
          color: item.isPinned
              ? context.eg.colors.accent
              : context.eg.colors.textSecondary,
          hoverColor: context.eg.colors.accentLight,
          onPressed: onTogglePin,
        ),
      ],
    );
  }

  Widget _contentCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.eg.colors.surface,
        borderRadius: context.eg.shapes.controlAll,
        border: context.eg.borderAll,
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          item.content,
          style: context.eg.text.bodyCompact.copyWith(height: 1.6),
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: EgButton(label: 'Copiar', onPressed: onCopy, expand: true),
        ),
        const SizedBox(width: AppSpacing.md),
        EgButton.destructive(label: 'Excluir', onPressed: onDelete),
      ],
    );
  }
}

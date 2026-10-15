import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../../models/clipboard_item.dart';
import '../../models/pin_image.dart';
import '../../../../shared/utils/byte_size.dart';
import 'pin_image_view.dart';
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
    this.canCopy = true,
  });

  /// Há o que copiar — `false` numa imagem cujo arquivo não está mais no
  /// disco. O botão verde que não entrega seria uma promessa vazia; excluir
  /// continua valendo.
  final bool canCopy;

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
            '${item.type.label} · ${item.type.copied} '
            '${RelativeTime.format(item.copiedAt)}',
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
    final image = item.image;
    if (image != null) return _imageCard(context, image);

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

  /// A imagem no lugar do texto, cabendo no cartão, e embaixo de onde ela
  /// veio: o caminho, quando foi do Finder; o site, quando o navegador o
  /// informou; e sempre o tamanho dela.
  ///
  /// A origem é selecionável, como o texto de um item: o caminho é o que se
  /// cola no Terminal ou no "Ir para a pasta" do Finder.
  Widget _imageCard(BuildContext context, PinImage image) {
    final meta = context.eg.text.footnote.copyWith(
      color: context.eg.colors.textTertiary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            // O mesmo respiro do cartão de texto: andar pelos itens com o
            // `Tab` aberto não pode fazer a borda de dentro pular.
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.eg.colors.surface,
              borderRadius: context.eg.shapes.controlAll,
              border: context.eg.borderAll,
            ),
            child: PinImageView.full(image: image),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Sem teto de linhas: o `SelectableText` não põe reticências, ele
        // rola por dentro — e o fim do caminho, que é o nome do arquivo,
        // sumiria sem aviso. A imagem, que é `Expanded`, cede a altura.
        if (image.path != null) SelectableText(image.path!, style: meta),
        if (image.source != null) SelectableText(image.source!, style: meta),
        Text(
          '${image.dimensions} · ${ByteSize.compact(image.byteSize)}',
          style: meta,
        ),
      ],
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: EgButton(
            label: 'Copiar',
            onPressed: canCopy ? onCopy : null,
            expand: true,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        EgButton.destructive(label: 'Excluir', onPressed: onDelete),
      ],
    );
  }
}

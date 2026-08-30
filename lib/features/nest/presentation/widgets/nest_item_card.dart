import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/utils/byte_size.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/nest_item.dart';

/// Uma linha da prateleira: miniatura, nome e o que ele é.
///
/// A miniatura é a razão de a linha ser mais alta que a do Pin (44px contra
/// 34): sem ela, dez arquivos com nomes parecidos são dez linhas de texto
/// iguais, e a prateleira só serve se der para reconhecer o que está nela de
/// relance. Enquanto o QuickLook não responde, o lugar é ocupado pelo glifo —
/// nunca por um vazio que depois pula de tamanho.
class NestItemCard extends StatelessWidget {
  const NestItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    this.onTap,
    this.onRemove,
  });

  final NestItem item;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Tira a linha da prateleira. O arquivo não é tocado.
  final VoidCallback? onRemove;

  /// Altura da linha, fixa como em toda lista do aplicativo.
  static const height = 44.0;

  /// Lado da miniatura. Quadrada porque o que cai aqui não tem proporção
  /// previsível — um retrato e uma captura de tela larga precisam ocupar a
  /// mesma coluna, senão os nomes deixam de se alinhar.
  static const _thumbnail = 28.0;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      semanticLabel: _semanticLabel,
      selected: isSelected ? true : null,
      // Fundido, como a linha do Pin — e diferente da linha do Echo, que
      // precisa deixar a estrela alcançável. O botão de remover daqui só existe
      // sob o ponteiro do mouse: ele nunca chega à árvore de acessibilidade, e
      // quem não usa mouse tira o item com o `⌫` que a barra de dicas ensina.
      builder: (context, state) => EgSurface(
        state: state,
        isSelected: isSelected,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox.square(
              dimension: _thumbnail,
              child: _preview(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _label(context)),
            const SizedBox(width: AppSpacing.sm),
            // A ação secundária só aparece sob o mouse — a lista em repouso
            // fica com os nomes e nada mais.
            if (state.isHovered && onRemove != null)
              EgIconButton(
                icon: EgIconData.close,
                tooltip: 'Tirar ${item.name} da prateleira',
                size: AppBadgeSizes.sm,
                iconSize: AppIconSizes.xs,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  /// A miniatura, ou o glifo enquanto ela não chega.
  Widget _preview(BuildContext context) {
    final thumbnail = item.thumbnail;

    if (thumbnail != null && !item.isMissing) {
      return ClipRRect(
        borderRadius: context.eg.shapes.rowAll,
        child: Image.memory(
          thumbnail,
          fit: BoxFit.contain,
          // O quadro anterior continua na tela enquanto o novo decodifica: sem
          // isso, cada degrau do QuickLook pisca um branco no lugar da imagem.
          gaplessPlayback: true,
        ),
      );
    }

    return Center(
      child: EgIcon(
        item.isDirectory ? EgIconData.folder : EgIconData.document,
        size: AppIconSizes.md,
        color: item.isMissing
            ? context.eg.colors.textTertiary
            : context.eg.colors.textSecondary,
      ),
    );
  }

  Widget _label(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: context.eg.text.bodyEmphasis.copyWith(
            color: item.isMissing
                ? context.eg.colors.textTertiary
                : context.eg.colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.hairline),
        Text(
          _detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: context.eg.text.footnote.copyWith(
            color: context.eg.colors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// A linha de baixo diz o que o arquivo é — e, quando ele sumiu, por que a
  /// linha está apagada. O erro ocupa o lugar do tamanho em vez de aparecer ao
  /// lado dele: o tamanho de um arquivo que não está mais lá não interessa a
  /// ninguém.
  String get _detail {
    if (item.isMissing) return 'não está mais no lugar';
    if (item.isDirectory) return 'Pasta';

    return ByteSize.compact(item.sizeInBytes);
  }

  /// A linha inteira numa frase.
  ///
  /// A miniatura é uma imagem sem texto, e o estado de "sumiu" é uma cor mais
  /// apagada: lida crua, a lista sairia como uma sequência de nomes de arquivo
  /// sem nada que diga qual deles não vai a lugar nenhum.
  String get _semanticLabel => '${item.name}, $_detail';
}

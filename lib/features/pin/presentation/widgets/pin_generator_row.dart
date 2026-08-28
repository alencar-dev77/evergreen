import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/clipboard_item_type.dart';
import '../../models/tax_id.dart';
import 'pin_list_item.dart';
import '../../../../core/design/eg_tokens.dart';

/// A linha "Gerar CPF" — ou "Gerar CNPJ" —, no topo da lista enquanto o filtro
/// daquele documento está ativo.
///
/// Uma linha só para os dois documentos, e não uma por documento: o que muda
/// entre eles é o rótulo, o ícone e a conta que produziu o número, e nada disso
/// é anatomia. Duas classes iguais menos por três palavras se desencontrariam
/// no primeiro ajuste de altura.
///
/// É o único lugar do Pin em que o painel **escreve** conteúdo em vez de
/// devolver o que passou pela área de transferência — e por isso ela se parece
/// com uma linha da lista em tudo (mesma altura, mesma coluna de ícone, mesma
/// matriz de estados), menos no que faz: não tem preview, não se fixa e não se
/// apaga. O que ela tem é um número, e duas maneiras de usá-lo.
///
/// **Clicar copia e fecha**, ao contrário das linhas de item, onde o clique
/// abre o preview. A regra existe para quem chega pelo mouse poder olhar o
/// conteúdo antes de decidir; aqui o conteúdo inteiro já está escrito na linha,
/// e não há um "dentro" para abrir. O botão à direita sorteia outro sem sair.
class PinGeneratorRow extends StatelessWidget {
  const PinGeneratorRow({
    super.key,
    required this.taxId,
    required this.kind,
    required this.isSelected,
    required this.onCopy,
    required this.onRegenerate,
    this.compact = false,
  });

  /// O documento sorteado, já pontuado.
  final String taxId;

  /// Qual documento é — decide o rótulo e o ícone da linha.
  final TaxIdKind kind;

  final bool isSelected;

  /// Copia o número e fecha o painel — o mesmo que o Enter faz.
  final VoidCallback onCopy;

  /// Sorteia outro, sem fechar — o mesmo que o `⌘G` faz.
  final VoidCallback onRegenerate;

  /// Coluna estreita exibida ao lado do preview.
  final bool compact;

  /// A mesma coluna de ícone da linha de item, para os títulos alinharem.
  static const _iconColumn = 18.0;
  static const _compactIconColumn = 16.0;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onCopy,
      semanticLabel: 'Gerar ${kind.label}, $taxId',
      selected: isSelected ? true : null,
      // O botão de sortear é outro clicável aqui dentro: fundir a linha inteira
      // numa etiqueta só o engoliria junto, e quem navega por leitor de tela
      // ficaria sem alcance para ele — mesmo caso da estrela do Echo.
      mergeDescendants: false,
      builder: (context, state) {
        return EgSurface(
          state: state,
          isSelected: isSelected,
          height: PinListItem.height,
          padding: EdgeInsets.only(
            left: compact ? AppSpacing.sm : AppSpacing.md,
            right: AppSpacing.xxs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? _compactIconColumn : _iconColumn,
                child: EgIcon(
                  // O mesmo ícone da pílula e do badge daquele tipo: a linha
                  // que gera um CNPJ não pode se anunciar com o cartão do CPF.
                  kind.itemType.icon,
                  size: compact ? AppIconSizes.xs : AppIconSizes.md,
                  color: isSelected
                      ? context.eg.colors.textPrimary
                      : context.eg.colors.textSecondary,
                ),
              ),
              SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
              Expanded(child: _label(context)),
              _RegenerateButton(onTap: onRegenerate, kind: kind),
            ],
          ),
        );
      },
    );
  }

  /// "Gerar CPF" à frente e o número atrás, no mesmo parágrafo — a anatomia do
  /// apelido na linha de item, pelo mesmo motivo: o corte por ellipsis come
  /// primeiro o número, e o que a linha é continua legível na coluna estreita.
  ///
  /// O número vai em mono porque é para ser conferido dígito a dígito.
  Widget _label(BuildContext context) {
    if (compact) {
      return Text(
        'Gerar ${kind.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: context.eg.text.bodyCompactEmphasis,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Gerar ${kind.label}'),
          TextSpan(
            text: '   $taxId',
            style: context.eg.text.monoSmall.copyWith(
              color: context.eg.colors.textTertiary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: context.eg.text.bodyCompactEmphasis,
    );
  }
}

/// O alvo de "sortear outro" dentro da linha.
///
/// Escrito aqui, e não com o [EgIconButton] compartilhado, porque aquele tem
/// 36px de lado e a linha inteira tem 34: o botão não caberia sem esticar a
/// lista, que rola por soma de alturas conhecidas.
class _RegenerateButton extends StatelessWidget {
  const _RegenerateButton({required this.onTap, required this.kind});

  final VoidCallback onTap;
  final TaxIdKind kind;

  static const _size = 26.0;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      semanticLabel: 'Sortear outro ${kind.label}',
      builder: (context, state) {
        return EgSurface(
          state: state,
          style: context.eg.surfaces.ghost,
          width: _size,
          height: _size,
          alignment: Alignment.center,
          borderRadius: context.eg.shapes.smallAll,
          child: EgIcon(
            EgIconData.shuffle,
            size: AppIconSizes.xs,
            color: state.isHovered
                ? context.eg.colors.textPrimary
                : context.eg.colors.textTertiary,
          ),
        );
      },
    );
  }
}

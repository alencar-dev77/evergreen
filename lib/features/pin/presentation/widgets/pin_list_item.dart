import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/clipboard_item.dart';
import '../../models/pin_quick_shortcut.dart';
import '../../models/pin_search.dart';
import '../../../../core/design/eg_tokens.dart';

/// Uma linha da lista do overlay: ícone de tipo, título e um metadado à direita.
///
/// Densidade compacta (34px de altura), como no Maccy — o objetivo é caber o
/// máximo de itens sem que a lista pareça apertada. A altura é fixa e pública
/// porque a lista rola por cálculo de offset, não por medição de widget.
class PinListItem extends StatelessWidget {
  const PinListItem({
    super.key,
    required this.item,
    required this.isSelected,
    this.query = '',
    this.shortcut,
    this.onTap,
    this.compact = false,
  });

  final ClipboardItem item;
  final bool isSelected;

  /// O que está digitado na busca, para grifar na linha o que casou.
  ///
  /// A linha recalcula os trechos a partir do texto que ela já tem na mão, em
  /// vez de recebê-los pelo estado: são duas strings curtas por linha visível, e
  /// o caminho contrário obrigaria a carregar os trechos de todos os itens do
  /// histórico até aqui. A conta em si é do domínio (`PinSearch`) — o widget só
  /// pergunta onde grifar.
  final String query;

  /// Atalho de cópia rápida do item, quando ele tem um.
  final PinQuickShortcut? shortcut;

  final VoidCallback? onTap;

  /// Variante usada na coluna estreita, quando o preview está aberto.
  final bool compact;

  /// Altura da linha em qualquer um dos dois modos.
  static const height = 34.0;

  /// Coluna fixa do ícone de tipo — o glifo mais o respiro que alinha todos os
  /// títulos no mesmo x, em cada um dos dois modos.
  static const _iconColumn = 18.0;
  static const _compactIconColumn = 16.0;

  @override
  Widget build(BuildContext context) {
    // Sem duplo clique para copiar: o clique simples abre o preview, e o painel
    // muda de largura ao abrir. O segundo toque cairia numa linha que já saiu de
    // baixo do cursor — ou, pior, no botão de excluir do preview que acabou de
    // aparecer ali. Copiar pelo mouse é o botão "Copiar" do preview; pelo
    // teclado, o Enter.
    return EgHoverable(
      onTap: onTap,
      semanticLabel: _semanticLabel,
      selected: isSelected ? true : null,
      builder: (context, state) {
        // Selecionado ganha a cor de destaque em baixa opacidade e a aresta
        // accent à esquerda — distinto do hover neutro, para que a posição do
        // teclado nunca se confunda com o mouse só passando por cima. Quem
        // resolve isso é a matriz de estado compartilhada
        // (`context.eg.surfaces.row`), a mesma da sidebar e do segmented control.
        return EgSurface(
          state: state,
          isSelected: isSelected,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Row(
            children: [
              // Ícone de tipo alinhado numa coluna fixa, sem o chip de fundo: o
              // glifo já distingue texto/link/comando de relance, e um container
              // cinza por linha só somaria ruído. Recua no repouso e acompanha o
              // texto quando a linha está selecionada.
              SizedBox(
                width: compact ? _compactIconColumn : _iconColumn,
                child: EgIcon(
                  item.type.icon,
                  size: compact ? AppIconSizes.xs : AppIconSizes.md,
                  color: isSelected
                      ? context.eg.colors.textPrimary
                      : context.eg.colors.textSecondary,
                ),
              ),
              SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
              Expanded(child: _label(context)),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.sm),
                _trailing(context),
              ],
            ],
          ),
        );
      },
    );
  }

  /// A linha inteira numa frase, para quem não vê a tela.
  ///
  /// Precisa existir escrita porque **nada** do que distingue uma linha da
  /// outra é texto: o tipo é um glifo desenhado, o estado de fixado é a posição
  /// no grupo, a seleção é uma cor de fundo com uma aresta, e o atalho é um
  /// badge de dois caracteres. Lida crua, a lista sai como uma sequência de
  /// conteúdos sem nada em volta — e é justamente o em volta que faz escolher.
  ///
  /// A ordem é a da decisão: primeiro o que é (o apelido, ou o conteúdo quando
  /// não há apelido), depois o que ele guarda, e só então tipo, fixado e
  /// atalho. O horário fica de fora — ele está na tela para dar contexto de
  /// relance, e numa frase falada viraria cauda em toda linha.
  String get _semanticLabel {
    final parts = <String>[
      if (item.hasAlias) '${item.alias!.trim()}: ${item.title}' else item.title,
      item.type.label,
      if (item.isPinned) 'fixado',
      // O atalho vai por extenso: `⌥2` lido caractere a caractere não ensina
      // nada, e ensinar o atalho é a razão de o badge existir.
      if (shortcut != null)
        'atalho ${shortcut!.group == PinShortcutGroup.pinned ? 'Option' : 'Command'} '
            '${shortcut!.number}',
    ];

    return parts.join(', ');
  }

  /// Texto da linha: o apelido à frente e, atrás dele, o começo do conteúdo em
  /// segundo plano.
  ///
  /// Os dois num parágrafo só, e não em dois `Text` lado a lado: assim o corte
  /// por ellipsis come primeiro o conteúdo, que é o que sobra de contexto, e
  /// nunca o apelido — que é o nome pelo qual a pessoa procura a linha. O
  /// contraste de peso e tamanho já separa um do outro, sem precisar de
  /// divisor. Na coluna estreita ao lado do preview só cabe o apelido.
  Widget _label(BuildContext context) {
    if (!item.hasAlias || compact) {
      return Text.rich(
        TextSpan(children: _highlighted(context, item.displayTitle)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: context.eg.text.bodyEmphasis,
      );
    }

    final secondary = context.eg.text.footnote.copyWith(
      color: context.eg.colors.textTertiary,
    );

    return Text.rich(
      TextSpan(
        children: [
          ..._highlighted(context, item.displayTitle),
          TextSpan(text: '   ', style: secondary),
          ..._highlighted(context, item.title, style: secondary),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: context.eg.text.bodyEmphasis,
    );
  }

  /// Quebra [text] em trechos, acendendo o que a busca casou.
  ///
  /// Só cor, sem peso nem fundo: o grifo aparece em várias linhas ao mesmo
  /// tempo, e um destaque mais forte que isso viraria a lista inteira num
  /// mosaico. Não é estado — é uma anotação sobre por que a linha está ali —,
  /// então a regra de "estado nunca só por cor" do `accessibility.md` não se
  /// aplica: o que a linha é, e não onde ela casou, quem conta é o rótulo
  /// semântico dela.
  List<InlineSpan> _highlighted(
    BuildContext context,
    String text, {
    TextStyle? style,
  }) {
    final spans = PinSearch.spans(text, query);
    if (spans.isEmpty) return [TextSpan(text: text, style: style)];

    final highlight = (style ?? const TextStyle()).copyWith(
      color: context.eg.colors.accent,
    );

    final result = <InlineSpan>[];
    var cursor = 0;

    for (final span in spans) {
      if (span.start > cursor) {
        result.add(
          TextSpan(text: text.substring(cursor, span.start), style: style),
        );
      }

      result.add(
        TextSpan(text: text.substring(span.start, span.end), style: highlight),
      );
      cursor = span.end;
    }

    if (cursor < text.length) {
      result.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return result;
  }

  /// À direita da linha vai o metadado mais útil daquele item: o atalho, quando
  /// ele existe (ensina algo que o texto não diz), e o horário quando não —
  /// nunca os dois, para a linha não virar uma tabela.
  Widget _trailing(BuildContext context) {
    final shortcut = this.shortcut;
    if (shortcut != null) {
      return _ShortcutBadge(label: shortcut.label, isActive: isSelected);
    }

    return Text(
      RelativeTime.format(item.copiedAt),
      maxLines: 1,
      softWrap: false,
      style: context.eg.text.footnote.copyWith(
        color: context.eg.colors.textTertiary,
      ),
    );
  }
}

/// Badge discreto com o atalho do item (`⌘1`, `⌥2`).
///
/// Fica sem contorno de propósito: ele aparece em várias linhas ao mesmo tempo
/// e um chip completo por linha competiria com o conteúdo. Ganha destaque
/// apenas na linha selecionada.
class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: AppDurations.fast,
      curve: AppDurations.curve,
      style: context.eg.text.monoSmall.copyWith(
        // Recuado, mas ainda legível: em `border` o badge some no fundo do
        // painel e deixa de ensinar o atalho, que é a razão de ele existir.
        color: isActive
            ? context.eg.colors.textSecondary
            : context.eg.colors.textTertiary,
      ),
      child: Text(label),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/clipboard_item.dart';
import '../viewmodels/pin_overlay_state.dart';
import 'pin_generator_row.dart';
import 'pin_list_item.dart';

/// Lista de resultados do overlay, agrupada em "Fixados" e "Recentes".
///
/// Mantém o item selecionado sempre visível ao navegar pelo teclado, que é a
/// forma principal de usar o Pin.
///
/// Rola por cálculo de offset em vez de `Scrollable.ensureVisible`: com o
/// histórico no limite (500 itens) só as linhas visíveis existem como widget,
/// então não há um `GlobalKey` por item para medir. A altura de cada linha é
/// conhecida de antemão — daí o offset sair de uma soma, não de um layout.
class PinResultList extends StatefulWidget {
  const PinResultList({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onCopyGenerated,
    required this.onRegenerateTaxId,
    this.compact = false,
  });

  final PinOverlayState state;

  /// Clique na linha: seleciona e abre o preview.
  final ValueChanged<ClipboardItem> onSelect;

  /// Clique na linha do gerador: copia o CPF sorteado e fecha.
  final VoidCallback onCopyGenerated;

  /// Sorteia outro CPF sem fechar.
  final VoidCallback onRegenerateTaxId;

  /// Coluna estreita exibida ao lado do preview.
  final bool compact;

  @override
  State<PinResultList> createState() => _PinResultListState();
}

class _PinResultListState extends State<PinResultList> {
  final _scrollController = ScrollController();

  /// Linhas visíveis — cabeçalhos de grupo e itens na ordem em que aparecem.
  List<_ListRow> _rows = const [];

  static const _paddingTop = AppSpacing.md;
  static const _paddingBottom = AppSpacing.lg;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
  }

  @override
  void didUpdateWidget(PinResultList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A *presença* da linha do gerador muda as linhas; o número que ela mostra
    // não — esse chega pelo `itemBuilder`, a cada build.
    if (!identical(oldWidget.state.results, widget.state.results) ||
        oldWidget.state.hasGenerator != widget.state.hasGenerator) {
      _rows = _buildRows();
    }

    if (oldWidget.state.selectedIndex != widget.state.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Percorre os resultados uma vez e insere um cabeçalho quando o grupo muda.
  ///
  /// Assim o índice de cada linha na lista de resultados sai do próprio laço —
  /// nada de `indexOf` por item, que seria quadrático no histórico cheio.
  List<_ListRow> _buildRows() {
    final rows = <_ListRow>[
      // Acima de tudo, inclusive dos fixados: ela não pertence a grupo nenhum —
      // é o que a lista oferece além do que já guardou.
      if (widget.state.hasGenerator) const _ListRow.generator(),
    ];
    bool? group;

    for (var index = 0; index < widget.state.results.length; index++) {
      final item = widget.state.results[index];

      if (item.isPinned != group) {
        rows.add(
          _ListRow.header(
            item.isPinned ? 'Fixados' : 'Recentes',
            isFirst: rows.isEmpty,
          ),
        );
        group = item.isPinned;
      }

      rows.add(_ListRow.item(item, index: index));
    }

    return rows;
  }

  /// Rola o mínimo necessário para trazer a seleção ao viewport.
  void _revealSelection() {
    if (!_scrollController.hasClients) return;

    final row = _rows.indexWhere(
      (row) => row.resultIndex == widget.state.selectedIndex,
    );
    if (row < 0) return;

    var top = _paddingTop;
    for (var i = 0; i < row; i++) {
      top += _rows[i].height;
    }
    final bottom = top + _rows[row].height;

    final position = _scrollController.position;
    final offset = position.pixels;
    final viewport = position.viewportDimension;

    // Um cabeçalho de grupo acima da linha vem junto quando a rolagem sobe: é o
    // que dá contexto de "em qual grupo eu estou" ao navegar pelo teclado.
    final leadIn =
        row > 0 && _rows[row - 1].isHeader ? _rows[row - 1].height : 0.0;

    final double target;
    if (top - leadIn < offset) {
      target = top - leadIn;
    } else if (bottom > offset + viewport) {
      target = bottom - viewport;
    } else {
      return;
    }

    _scrollController.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: AppDurations.instant,
      curve: AppDurations.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.compact ? AppSpacing.xs : AppSpacing.sm;

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          horizontal,
          _paddingTop,
          horizontal,
          _paddingBottom,
        ),
        itemCount: _rows.length,
        itemExtentBuilder: (index, _) => _rows[index].height,
        itemBuilder: (context, index) => _buildRow(_rows[index]),
      ),
    );
  }

  Widget _buildRow(_ListRow row) {
    if (row.isGenerator) {
      return PinGeneratorRow(
        taxId: widget.state.generatedTaxId!,
        kind: widget.state.generatorKind!,
        isSelected: widget.state.isGeneratorSelected,
        compact: widget.compact,
        onCopy: widget.onCopyGenerated,
        onRegenerate: widget.onRegenerateTaxId,
      );
    }

    final item = row.item;

    if (item == null) {
      return EgSectionLabel(
        row.label!,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          row.isFirst ? AppSpacing.xs : AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxs,
        ),
      );
    }

    return PinListItem(
      item: item,
      isSelected: row.resultIndex == widget.state.selectedIndex,
      query: widget.state.query,
      shortcut: widget.state.shortcutFor(item),
      compact: widget.compact,
      onTap: () => widget.onSelect(item),
    );
  }
}

/// Uma linha da lista: o gerador, um cabeçalho de grupo ou um item, com altura
/// conhecida.
@immutable
class _ListRow {
  const _ListRow.header(this.label, {required this.isFirst})
      : item = null,
        isGenerator = false,
        resultIndex = _noIndex;

  const _ListRow.item(this.item, {required int index})
      : label = null,
        isFirst = false,
        isGenerator = false,
        resultIndex = index;

  const _ListRow.generator()
      : item = null,
        label = null,
        isFirst = false,
        isGenerator = true,
        resultIndex = -1;

  final ClipboardItem? item;
  final String? label;

  /// Primeiro cabeçalho da lista — leva menos respiro acima que os seguintes.
  final bool isFirst;

  /// A linha "Gerar CPF", que fica acima de todos os grupos.
  final bool isGenerator;

  /// Posição da linha em `state.results` — e [_noIndex] para o que não está
  /// lá.
  ///
  /// O gerador tem `-1` porque é assim que a seleção o alcança (ver
  /// `PinOverlayState.selectedIndex`), e é justamente por isso que os
  /// cabeçalhos **não** podem usar `-1`: `_revealSelection` acha a linha
  /// selecionada comparando este número, e acharia um cabeçalho no lugar do
  /// gerador.
  final int resultIndex;

  static const _noIndex = -2;

  bool get isHeader => item == null && !isGenerator;

  /// Altura fixa: texto de 11px com o padding do cabeçalho, ou a linha de item —
  /// que é a mesma do gerador.
  static const _headerHeight = AppSpacing.xs + 15 + AppSpacing.xxs;
  static const _headerHeightWithGap = AppSpacing.lg + 15 + AppSpacing.xxs;

  double get height {
    if (!isHeader) return PinListItem.height;
    return isFirst ? _headerHeight : _headerHeightWithGap;
  }
}

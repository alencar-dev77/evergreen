import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/clipboard_item.dart';
import '../viewmodels/pin_overlay_state.dart';
import 'pin_list_item.dart';

/// Lista de resultados do overlay, agrupada em "Fixados" e "Recentes".
///
/// Mantém o item selecionado sempre visível ao navegar pelo teclado, que é a
/// forma principal de usar o Pin.
class PinResultList extends StatefulWidget {
  const PinResultList({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onActivate,
    this.compact = false,
  });

  final PinOverlayState state;

  /// Clique simples: move a seleção.
  final ValueChanged<ClipboardItem> onSelect;

  /// Duplo clique / Enter: copia e fecha.
  final ValueChanged<ClipboardItem> onActivate;

  /// Coluna estreita exibida ao lado do preview.
  final bool compact;

  @override
  State<PinResultList> createState() => _PinResultListState();
}

class _PinResultListState extends State<PinResultList> {
  final _scrollController = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(PinResultList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state.selectedIndex != widget.state.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
    }
  }

  /// Rola o mínimo necessário para trazer a seleção ao viewport.
  void _revealSelection() {
    final key = _itemKeys[widget.state.selectedIndex];
    final context = key?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: AppDurations.fast,
      curve: AppDurations.curve,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.state.pinned;
    final recent = widget.state.recent;

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          widget.compact ? AppSpacing.xs : AppSpacing.sm,
          AppSpacing.md,
          widget.compact ? AppSpacing.xs : AppSpacing.sm,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pinned.isNotEmpty) ...[
              _sectionLabel('Fixados', isFirst: true),
              ...pinned.map(_buildItem),
            ],
            if (recent.isNotEmpty) ...[
              _sectionLabel('Recentes', isFirst: pinned.isEmpty),
              ...recent.map(_buildItem),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {required bool isFirst}) => EgSectionLabel(
        text,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          isFirst ? AppSpacing.xs : AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxs,
        ),
      );

  Widget _buildItem(ClipboardItem item) {
    final index = widget.state.results.indexOf(item);
    final key = _itemKeys.putIfAbsent(index, GlobalKey.new);

    return KeyedSubtree(
      key: key,
      child: PinListItem(
        item: item,
        isSelected: index == widget.state.selectedIndex,
        shortcut: widget.state.shortcutFor(item),
        compact: widget.compact,
        onTap: () => widget.onSelect(item),
        onDoubleTap: () => widget.onActivate(item),
      ),
    );
  }
}

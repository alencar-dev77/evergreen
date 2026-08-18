import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_overlay_shell.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_search_field.dart';
import '../../models/clipboard_item.dart';
import '../../models/pin_quick_shortcut.dart';
import '../viewmodels/pin_overlay_view_model.dart';
import '../widgets/pin_hint_bar.dart';
import '../widgets/pin_preview_pane.dart';
import '../widgets/pin_result_list.dart';
import 'pin_overlay_intents.dart';

/// Painel flutuante do Pin — a tela que o `⌘⇧C` abre.
///
/// A janela é transparente e sem chrome; tudo que se vê é este painel. O foco
/// vai para a busca assim que a janela aparece, e perder o foco fecha o
/// overlay, como no Spotlight.
class PinOverlayView extends ConsumerStatefulWidget {
  const PinOverlayView({super.key});

  @override
  ConsumerState<PinOverlayView> createState() => _PinOverlayViewState();
}

class _PinOverlayViewState extends ConsumerState<PinOverlayView> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Campo de apelido do preview. Enquanto ele tem o foco o overlay troca de
  /// mapa de teclado — daí o listener com `setState`.
  final _aliasController = TextEditingController();
  final _aliasFocusNode = FocusNode(debugLabel: 'pin-alias');

  /// Item cujo apelido está no campo. Guardado à parte da seleção porque o
  /// clique numa outra linha não tira o foco do campo: sem isso, o texto
  /// digitado seria gravado no item errado.
  ClipboardItem? _aliasItem;

  bool _isPreviewOpen = false;

  /// Largura do painel em cada modo, conforme as telas do design.
  static const _listOnlyWidth = 420.0;
  static const _withPreviewWidth = 560.0;
  static const _maxPanelHeight = 460.0;

  /// Largura da coluna da lista quando o preview está aberto.
  static const _compactListWidth = 210.0;

  @override
  void initState() {
    super.initState();
    _aliasFocusNode.addListener(_onAliasFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _aliasFocusNode.removeListener(_onAliasFocusChanged);
    _aliasFocusNode.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  /// Cada abertura começa do zero: busca em branco, cursor no campo e preview
  /// fechado.
  void _onShow() {
    _searchController.clear();
    _searchFocusNode.requestFocus();

    // O campo de apelido volta do zero: o preview fecha junto, e a abertura
    // seguinte recarrega o apelido do item que estiver selecionado então.
    _aliasItem = null;
    _aliasController.clear();

    setState(() => _isPreviewOpen = false);
  }

  /// Guardada uma vez, na primeira construção, em vez de procurada a cada uso:
  /// a troca de item também acontece dentro de um listener do próprio provider,
  /// e procurar o `ProviderScope` na árvore enquanto ela se rearranja é o tipo
  /// de coisa que o Flutter recusa a fazer.
  late final PinOverlayViewModel _viewModel =
      ref.read(pinOverlayViewModelProvider.notifier);

  /// Esconder a janela não tira o foco do campo de apelido dentro do Flutter,
  /// então o que estava digitado é guardado aqui — fechar não é desistir.
  Future<void> _close({bool paste = false}) {
    _commitAlias();
    return OverlayWindow.instance.hide(paste: paste);
  }

  /// Fecha após copiar. Com o auto-colar ligado, o item é colado no app anterior
  /// em vez de só devolver o foco — os dois caminhos passam por aqui.
  Future<void> _closeAfterCopy() async {
    await _close(paste: await _viewModel.shouldAutoPaste());
  }

  Future<void> _activate(ClipboardItem item) async {
    await _viewModel.copyItem(item);
    await _closeAfterCopy();
  }

  Future<void> _activateSelection() async {
    if (await _viewModel.copySelected()) await _closeAfterCopy();
  }

  /// `⌘N` / `⌥N`: copia e sai, sem passar pela seleção.
  ///
  /// Se o slot estiver vazio o overlay fica aberto — apertar um número que não
  /// existe na lista não deve custar a janela.
  Future<void> _quickCopy(PinShortcutGroup group, int number) async {
    if (await _viewModel.copyByShortcut(group, number)) await _closeAfterCopy();
  }

  void _togglePreview() {
    final item = ref.read(pinOverlayViewModelProvider).selectedItem;
    if (item == null) return;

    _syncAliasField(item);
    setState(() => _isPreviewOpen = !_isPreviewOpen);
  }

  /// A barra de dicas e o mapa de teclado mudam quando o apelido entra em
  /// edição — os dois saem daqui.
  void _onAliasFocusChanged() {
    if (!_aliasFocusNode.hasFocus) _commitAlias();
    if (mounted) setState(() {});
  }

  /// Recarrega o campo quando a seleção muda de item.
  ///
  /// O que estava sendo digitado é guardado antes: trocar de linha com o texto
  /// pela metade é uma troca de assunto, não um cancelamento.
  void _syncAliasField(ClipboardItem? item) {
    if (_aliasItem?.id == item?.id) return;

    _commitAlias();
    _aliasItem = item;
    _aliasController.text = item?.alias ?? '';
  }

  /// `⌘R`: abre o preview, se preciso, e leva o cursor para o apelido.
  void _editAlias() {
    final item = ref.read(pinOverlayViewModelProvider).selectedItem;
    if (item == null) return;

    _syncAliasField(item);
    if (!_isPreviewOpen) setState(() => _isPreviewOpen = true);

    // O campo só existe depois que o preview entra na árvore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _aliasFocusNode.requestFocus();
      _aliasController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _aliasController.text.length,
      );
    });
  }

  /// Guarda o apelido digitado. Chamado também quando o campo perde o foco por
  /// qualquer motivo — fechar o overlay no meio da edição não perde o texto.
  void _commitAlias() {
    final item = _aliasItem;
    if (item == null) return;

    _viewModel.setAlias(item, _aliasController.text);

    // O item guardado vira a nova referência do campo: é ele que o Esc
    // restaura, e um apelido já gravado não é mais o valor a desfazer.
    _aliasItem = item.copyWith(alias: _aliasController.text.trim());
  }

  /// Enter no campo: guarda e devolve o teclado à lista.
  void _finishAliasEdit() {
    _commitAlias();
    _searchFocusNode.requestFocus();
  }

  /// Esc no campo: desfaz o que foi digitado e devolve o teclado à lista.
  ///
  /// Restaura o texto **antes** de tirar o foco porque é a saída do foco que
  /// grava — do contrário o cancelamento salvaria justamente o que ele desfez.
  void _cancelAliasEdit() {
    _aliasController.text = _aliasItem?.alias ?? '';
    _searchFocusNode.requestFocus();
  }

  /// `⌘,`: sai de cena primeiro, depois abre o Hub — nessa ordem, um problema
  /// ao criar a janela nunca deixa o overlay preso na tela.
  Future<void> _openSettings() async {
    await _close();
    await HubWindow.instance.open();
  }

  /// Esc é hierárquico: recolhe o preview primeiro e só fecha o overlay quando
  /// não há mais nada aberto dentro dele. Assim ninguém perde a busca digitada
  /// por ter apertado Esc só para sair do preview.
  Future<void> _handleEscape() async {
    if (_isPreviewOpen) {
      setState(() => _isPreviewOpen = false);
      return;
    }

    await _close();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinOverlayViewModelProvider);
    final showPreview = _isPreviewOpen && state.selectedItem != null;
    final isEditingAlias = _aliasFocusNode.hasFocus;

    // O campo acompanha a seleção: navegar pela lista com o preview aberto
    // troca o item exibido, e o apelido é do item, não do painel. Vai num
    // `listen`, e não no corpo do build, porque guardar o apelido anterior
    // escreve no estado — proibido enquanto a árvore se constrói.
    ref.listen(pinOverlayViewModelProvider, (previous, next) {
      if (previous?.selectedItem?.id == next.selectedItem?.id) return;
      _syncAliasField(next.selectedItem);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: PinOverlayIntents.shortcuts(isEditingAlias: isEditingAlias),
        child: Actions(
          actions: PinOverlayIntents.actions(
            onMove: _viewModel.moveSelection,
            onMovePinned: _viewModel.movePinnedSelection,
            onActivate: _activateSelection,
            onClose: _handleEscape,
            onTogglePreview: _togglePreview,
            onQuickCopy: _quickCopy,
            onTogglePin: _viewModel.togglePinSelected,
            onDelete: _viewModel.deleteSelected,
            onOpenSettings: _openSettings,
            onEditAlias: _editAlias,
            onCommitAlias: _finishAliasEdit,
            onCancelAlias: _cancelAliasEdit,
          ),
          // O painel do Pin é o único que muda de largura: abrir o preview
          // anima a caixa em vez de trocá-la, para o painel crescer a partir do
          // mesmo centro em que a casca o ancora.
          child: EgOverlayShell(
            onClose: () => unawaited(_close()),
            onShow: _onShow,
            child: AnimatedContainer(
              duration: AppDurations.medium,
              curve: AppDurations.curve,
              width: showPreview ? _withPreviewWidth : _listOnlyWidth,
              constraints: const BoxConstraints(maxHeight: _maxPanelHeight),
              child: EgPanel(
                vibrant: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _searchBar(),
                    Flexible(child: _content(showPreview)),
                    PinHintBar(
                      isPreviewOpen: showPreview,
                      canMovePinned: state.canMoveSelectedPinned,
                      isEditingAlias: isEditingAlias,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(border: AppBorders.bottom),
      child: EgSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _viewModel.search,
        hintText: 'Buscar no histórico',
        bare: true,
        autofocus: true,
      ),
    );
  }

  Widget _content(bool showPreview) {
    final state = ref.watch(pinOverlayViewModelProvider);

    if (state.isLoading && state.results.isEmpty) return const _Loading();
    if (state.isEmpty) return _emptyState(fromSearch: state.isEmptyBecauseOfSearch);

    final list = PinResultList(
      state: state,
      compact: showPreview,
      onSelect: _viewModel.selectItem,
      onActivate: _activate,
    );

    if (!showPreview) return list;

    final selected = state.selectedItem!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _compactListWidth,
          child: DecoratedBox(
            decoration: const BoxDecoration(border: AppBorders.right),
            child: list,
          ),
        ),
        Expanded(
          child: PinPreviewPane(
            item: selected,
            aliasController: _aliasController,
            aliasFocusNode: _aliasFocusNode,
            onAliasSubmitted: (_) => _finishAliasEdit(),
            onCopy: () => _activate(selected),
            onTogglePin: () => _viewModel.togglePin(selected),
            onDelete: () => _viewModel.delete(selected),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({required bool fromSearch}) {
    return EgEmptyState(
      icon: fromSearch ? EgIconData.search : EgIconData.document,
      title: fromSearch ? 'Nenhum resultado' : 'Nenhum item ainda',
      message: fromSearch
          ? 'Nada no histórico corresponde à sua busca.'
          : 'Tudo que você copiar aparecerá aqui automaticamente.',
    );
  }
}

/// Espera pela primeira carga do histórico.
///
/// O banco é local, então isso termina em poucos milissegundos e o spinner
/// nunca chega a aparecer — é exatamente o objetivo do atraso. Um indicador que
/// pisca por 40ms e some é pior que indicador nenhum.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  static const _delay = Duration(milliseconds: 200);

  Timer? _timer;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_delay, () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _spinnerBoxHeight,
      child: Center(
        child: _isVisible
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
    );
  }

  /// Reserva a altura do bloco antes e depois do spinner aparecer, para o painel
  /// não mudar de tamanho no meio da espera.
  static const _spinnerBoxHeight = 96.0;
}

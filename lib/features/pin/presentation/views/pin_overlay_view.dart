import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_gradients.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/pin_overlay_window.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
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

class _PinOverlayViewState extends ConsumerState<PinOverlayView>
    with WindowListener, SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Fade de entrada do painel. Nasce em 1 para que a primeira construção (e os
  /// testes, que não têm janela) já mostrem o painel pronto — quem rebobina a
  /// animação é o `onWindowFocus`, uma vez por abertura.
  late final _entrance = AnimationController(
    vsync: this,
    duration: AppDurations.entrance,
    value: 1,
  );

  late final _entranceOpacity =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  bool _isPreviewOpen = false;

  /// Largura do painel em cada modo, conforme as telas do design.
  static const _listOnlyWidth = 420.0;
  static const _withPreviewWidth = 560.0;
  static const _maxPanelHeight = 460.0;

  /// Largura da coluna da lista quando o preview está aberto.
  static const _compactListWidth = 210.0;

  /// Margem para o macOS terminar a troca de foco antes de confirmarmos um
  /// blur. Curto o bastante para o fechamento continuar parecendo instantâneo.
  static const _blurGracePeriod = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _entranceOpacity.dispose();
    _entrance.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
    _entrance.forward(from: 0);
    setState(() => _isPreviewOpen = false);
  }

  @override
  void onWindowBlur() => unawaited(_handleBlur());

  @override
  void onWindowClose() => _close();

  /// Fecha o overlay quando o foco vai para outro aplicativo.
  ///
  /// Ativar a janela faz o macOS oscilar o key status por um instante, então um
  /// `windowDidResignKey` isolado não significa que o usuário saiu: confirmamos
  /// que o foco não voltou antes de esconder. Sem essa checagem o overlay pisca
  /// e some logo depois de abrir.
  Future<void> _handleBlur() async {
    await Future<void>.delayed(_blurGracePeriod);
    if (!mounted) return;
    if (await windowManager.isFocused()) return;

    await _close();
  }

  PinOverlayViewModel get _viewModel =>
      ref.read(pinOverlayViewModelProvider.notifier);

  Future<void> _close({bool paste = false}) =>
      PinOverlayWindow.instance.hide(paste: paste);

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
    if (ref.read(pinOverlayViewModelProvider).selectedItem == null) return;
    setState(() => _isPreviewOpen = !_isPreviewOpen);
  }

  /// `⌘,`: leva às preferências do Pin no Hub e sai de cena.
  Future<void> _openSettings() async {
    await HubWindow.instance.open();
    await _close();
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: PinOverlayIntents.shortcuts,
        child: Actions(
          actions: PinOverlayIntents.actions(
            onMove: _viewModel.moveSelection,
            onActivate: _activateSelection,
            onClose: _handleEscape,
            onTogglePreview: _togglePreview,
            onQuickCopy: _quickCopy,
            onTogglePin: _viewModel.togglePinSelected,
            onDelete: _viewModel.deleteSelected,
            onOpenSettings: _openSettings,
          ),
          // A janela é maior que o painel para caber a sombra e o painel
          // expandido. O resto dela é transparente, mas ainda captura cliques —
          // então tratamos essa área como barreira: clicar fora fecha.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  // Fade curto na chegada; a saída não anima — a janela
                  // simplesmente se esconde, porque voltar ao trabalho é mais
                  // urgente que assistir o painel sair.
                  child: FadeTransition(
                    opacity: _entranceOpacity,
                    child: AnimatedContainer(
                      duration: AppDurations.medium,
                      curve: AppDurations.curve,
                      width: showPreview ? _withPreviewWidth : _listOnlyWidth,
                      constraints:
                          const BoxConstraints(maxHeight: _maxPanelHeight),
                      child: EgPanel(
                        gradient: AppGradients.panelSurface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _searchBar(),
                            Flexible(child: _content(showPreview)),
                            PinHintBar(isPreviewOpen: showPreview),
                          ],
                        ),
                      ),
                    ),
                  ),
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

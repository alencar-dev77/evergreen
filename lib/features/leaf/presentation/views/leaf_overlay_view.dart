import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_overlay_shell.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../viewmodels/leaf_state.dart';
import '../viewmodels/leaf_view_model.dart';
import '../widgets/leaf_grid.dart';
import 'leaf_overlay_intents.dart';

/// Painel flutuante do Leaf — a parede que o `⌘⇧F` abre.
///
/// Divide a janela com Pin, Focus e Awake (ver `OverlayWindow`). Diferente
/// deles, o painel não tem tamanho fixo: ele acompanha a parede, que começa com
/// duas colunas e ganha a terceira quando a terceira anotação chega. Como a
/// janela é centralizada na tela, crescer é crescer para os dois lados.
class LeafOverlayView extends ConsumerStatefulWidget {
  const LeafOverlayView({super.key});

  @override
  ConsumerState<LeafOverlayView> createState() => _LeafOverlayViewState();
}

class _LeafOverlayViewState extends ConsumerState<LeafOverlayView> {
  /// Segura o foco do painel quando nenhum cartão está sendo escrito — sem um
  /// nó focado, o `Shortcuts` não receberia tecla nenhuma.
  final _panelFocusNode = FocusNode(debugLabel: 'leaf-panel');

  final _editorController = TextEditingController();
  final _editorFocusNode = FocusNode(debugLabel: 'leaf-editor');

  @override
  void initState() {
    super.initState();
    _editorFocusNode.addListener(_onEditorFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    _editorFocusNode.removeListener(_onEditorFocusChanged);
    _editorFocusNode.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  /// O cartão que perde o cursor guarda o que tinha escrito e volta a ser um
  /// cartão.
  ///
  /// É a convenção do produto — sair do campo guarda, por qualquer caminho —, a
  /// mesma que o apelido do Pin segue. Aqui ela resolve o que um clique no
  /// painel deixava pendurado: no macOS o `TextField` larga o foco a cada
  /// clique fora dele, e sem isto o cartão continuava com a borda accent, com o
  /// rodapé prometendo "esc descartar" e sem cursor nenhum para receber a
  /// próxima letra.
  ///
  /// O Esc não passa por aqui: ele desfaz a edição **antes** de o campo sair da
  /// árvore, e quando o foco se perde já não há edição para guardar.
  void _onEditorFocusChanged() {
    if (_editorFocusNode.hasFocus) return;

    _commitPendingEdit();
  }

  /// O foco volta ao painel a cada abertura — a menos que um cartão tenha
  /// ficado em edição, e nesse caso o cursor é dele.
  void _onShow() {
    if (ref.read(leafViewModelProvider).isEditing) return;
    _panelFocusNode.requestFocus();
  }

  LeafViewModel get _viewModel => ref.read(leafViewModelProvider.notifier);

  /// Fecha o painel guardando o que estava sendo escrito.
  ///
  /// A convenção do produto para campo de edição é "sair do campo guarda, por
  /// qualquer caminho" — e um painel que some levando junto a frase recém
  /// digitada seria a pior forma possível de descobrir isso.
  Future<void> _close() async {
    _commitPendingEdit();
    await OverlayWindow.instance.hide();
  }

  void _commitPendingEdit() {
    if (!ref.read(leafViewModelProvider).isEditing) return;

    _viewModel.commitEdit(_editorController.text);
  }

  /// `⌘N`: copia e sai de cena, como o `⌘1`–`⌘5` do Pin.
  ///
  /// Vaga vazia não fecha nada: a tecla não encontrou anotação nenhuma, e
  /// fechar seria fingir que encontrou.
  Future<void> _copySlot(int slot) async {
    if (!await _viewModel.copySlot(slot)) return;

    await _close();
  }

  /// `⌘,`: sai de cena primeiro, depois abre o Hub — nessa ordem, um problema
  /// ao criar a janela nunca deixa o painel preso na tela.
  Future<void> _openSettings() async {
    await _close();
    await HubWindow.instance.open();
  }

  /// Passa o teclado para o campo quando a edição começa, e o devolve ao painel
  /// quando ela termina.
  ///
  /// O foco é pedido à mão, e não pelo `autofocus` do campo: `autofocus` só
  /// vale quando **nada** no escopo tem o foco, e aqui o painel sempre tem — era
  /// por isso que o cartão abria em branco esperando um clique antes de aceitar
  /// a primeira letra. O pedido espera o quadro seguinte porque no instante do
  /// aviso o campo ainda não existe na árvore.
  void _syncEditing(LeafState? previous, LeafState next) {
    if (previous?.editingSlot == next.editingSlot) return;

    final slot = next.editingSlot;
    if (slot == null) {
      _editorController.clear();
      _panelFocusNode.requestFocus();
      return;
    }

    // O campo nasce com o texto que já existia e o cursor no fim: editar uma
    // anotação é continuar a frase, não recomeçá-la.
    final content = next.noteAt(slot)?.content ?? '';
    _editorController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LeafState>(leafViewModelProvider, _syncEditing);
    final state = ref.watch(leafViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: state.isEditing
            ? LeafOverlayIntents.editing
            : LeafOverlayIntents.browsing,
        child: Actions(
          actions: LeafOverlayIntents.actions(
            onNewNote: _viewModel.startNote,
            onActivate: _viewModel.editSelected,
            onMoveSelection: _viewModel.moveSelection,
            onCopySlot: _copySlot,
            onDelete: _viewModel.deleteSelected,
            onUndoDelete: _viewModel.undoDelete,
            onClose: _close,
            onCommitEdit: _commitPendingEdit,
            onCancelEdit: _viewModel.cancelEdit,
            onOpenSettings: _openSettings,
          ),
          // Para a parede, que muda de tamanho, a centralização da casca é
          // também o que a mantém no mesmo lugar da tela com uma ou com nove
          // anotações.
          child: EgOverlayShell(
            onClose: () => unawaited(_close()),
            onShow: _onShow,
            focusNode: _panelFocusNode,
            child: _panel(state),
          ),
        ),
      ),
    );
  }

  Widget _panel(LeafState state) {
    // Anima os dois eixos: a parede ganha coluna ao chegar no terceiro cartão e
    // perde linha a cada cartão jogado fora. Sem isto o painel saltaria de
    // tamanho, e um salto de 200px é a diferença entre "encolheu" e "piscou".
    // Cresce a partir do centro, como o painel se posiciona na janela: a parede
    // se abre para os quatro lados em torno do mesmo ponto da tela.
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: AppDurations.curve,
      alignment: Alignment.center,
      child: SizedBox(
        width: LeafGrid.widthFor(LeafGrid.columnsFor(state)),
        child: EgPanel(
          vibrant: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                // Enquanto o painel muda de tamanho, a parede já tem o tamanho
                // novo: o viewport a recorta em silêncio por 220ms em vez de
                // acusar estouro de layout.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: LeafGrid(
                    state: state,
                    editorController: _editorController,
                    editorFocusNode: _editorFocusNode,
                    onSelect: _viewModel.editSlot,
                    onDelete: _delete,
                  ),
                ),
              ),
              _hintBar(state),
            ],
          ),
        ),
      ),
    );
  }

  void _delete(int slot) {
    _viewModel.selectSlot(slot);
    _viewModel.deleteSelected();
  }

  /// O rodapé fala do estado atual, não do mapa inteiro de teclas.
  ///
  /// Com o cartão em edição sobram duas: o Enter que guarda e o Esc que desfaz.
  /// Fora dela, o Enter muda de verbo conforme a vaga selecionada — é ele o
  /// botão primário desta tela, e o rodapé é onde isso se ensina.
  Widget _hintBar(LeafState state) {
    if (state.isEditing) {
      return const EgHintBar(
        hints: [
          EgHint(keys: ['enter'], label: 'guardar'),
          EgHint(keys: ['⇧', 'enter'], label: 'quebrar linha'),
        ],
        trailing: EgHint(keys: ['esc'], label: 'descartar'),
      );
    }

    final hasNote = state.selectedNote != null;

    return EgHintBar(
      hints: [
        EgHint(keys: const ['enter'], label: hasNote ? 'editar' : 'anotar'),
        // `⌘+` só se anuncia quando o Enter não faz o mesmo: sobre a vaga
        // livre os dois criam, e ensinar as duas teclas para a mesma coisa
        // gastaria a linha à toa.
        if (!state.isFull && hasNote) const EgHint(keys: ['⌘+'], label: 'nova'),
        if (hasNote) const EgHint(keys: ['⌘⌫'], label: 'apagar'),
        // Só depois de apagar, e só enquanto o painel estiver aberto: a dica
        // aparece exatamente onde a dúvida nasce ("cadê o cartão que eu acabei
        // de arrancar?") e é o alvo de mouse do `⌘Z` — nenhuma ação do
        // Evergreen é só de teclado.
        if (state.canUndoDelete)
          EgHint(
            keys: const ['⌘Z'],
            label: 'desfazer',
            onTap: _viewModel.undoDelete,
          ),
      ],
      trailing: const EgHint(keys: ['esc'], label: 'fechar'),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../models/leaf_note.dart';
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

  /// `1`–`9`: copia, e o painel **fica**.
  ///
  /// Diferente do Pin, onde copiar é o fim do gesto e o painel some: ali se
  /// procura um item num histórico de centenas; aqui a parede tem nove vagas
  /// que se sabe de cor, e quem copia costuma copiar dois seguidos. O que o
  /// sumiço dizia ("copiei") passou a ser dito pelo aviso no cartão.
  Future<void> _copySlot(int slot) => _viewModel.copySlot(slot);

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
            onEditSlot: _viewModel.editSlot,
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
    // Sem `AnimatedSize`: a parede é sempre a parede, então o painel tem um
    // tamanho só. A animação existia porque a grade ganhava coluna no terceiro
    // cartão e perdia linha a cada um jogado fora — com as nove vagas sempre
    // desenhadas, não há mais o que animar, e animar nada custa uma camada.
    return SizedBox(
      width: LeafGrid.widthFor(context, LeafGrid.columnsFor(state)),
      child: EgPanel(
        vibrant: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(state),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              // O viewport fica, e não era pela animação que saiu: ele é o que
              // faz uma superfície mais estreita que a parede **recortá-la** em
              // silêncio em vez de acusar estouro de layout. A janela flutuante
              // tem 920 e a parede pede 798, mas quem desenha o painel fora
              // dela (um teste, um golden) não tem essa garantia.
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
  /// O topo do painel: o nome do módulo, o que fazer, e quanto já foi usado.
  ///
  /// O painel não tinha cabeçalho — a parede começava colada na borda, e a
  /// tecla que copia só estava dita no rodapé, do outro lado da tela. "Aperte o
  /// número pra copiar" mora aqui porque é aqui que o olho entra, e a contagem
  /// à direita é a única coisa que a grade não diz de relance: com as nove
  /// vagas sempre desenhadas, quantas estão ocupadas passa a ser uma conta.
  Widget _header(LeafState state) {
    final eg = context.eg;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(border: Border(bottom: eg.hairline)),
      child: Row(
        children: [
          Text('Leaf', style: eg.text.bodyStrong),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'aperte o número pra copiar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: eg.text.footnote.copyWith(color: eg.colors.textTertiary),
            ),
          ),
          Text(
            '${state.notes.length} de ${LeafNote.maxNotes} usados',
            style: eg.text.monoSmall.copyWith(color: eg.colors.textTertiary),
          ),
        ],
      ),
    );
  }

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
    final hasAny = state.notes.isNotEmpty;

    return EgHintBar(
      hints: [
        // As duas teclas da parede, sempre — elas são o módulo. O resto entra
        // conforme o que está selecionado.
        if (hasAny) const EgHint(keys: ['1–9'], label: 'copiar'),
        if (hasAny) const EgHint(keys: ['⌥1–9'], label: 'editar'),
        if (!hasAny) const EgHint(keys: ['enter'], label: 'anotar'),
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

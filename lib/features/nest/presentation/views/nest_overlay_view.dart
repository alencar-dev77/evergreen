import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_overlay_shell.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../data/nest_channel.dart';
import '../../models/nest_destination.dart';
import '../../models/nest_transfer_mode.dart';
import '../viewmodels/nest_state.dart';
import '../viewmodels/nest_view_model.dart';
import '../widgets/nest_item_card.dart';
import 'nest_overlay_intents.dart';

/// Painel flutuante do Nest — a prateleira que o `⌘⇧S` abre.
///
/// Divide a janela com os outros cinco painéis (ver `OverlayWindow`). Duas
/// coisas o separam deles:
///
/// - **Ele recebe arquivos.** Enquanto está à vista, a janela 0 é um destino de
///   arraste (`NestChannel.setDropEnabled`); nos outros painéis não é, porque
///   soltar um arquivo em cima do Focus não deve significar nada.
/// - **Ele não fecha ao perder o foco, nunca.** Uma prateleira que some quando
///   se clica fora é inútil: clicar fora — no Finder, no navegador — é
///   exatamente o que se faz entre abrir a prateleira e enchê-la. Vale também
///   com ela vazia, que é justamente o estado de quem vai buscar o primeiro
///   arquivo. Fecha pelo `esc`, pelo atalho global e pelo menu da barra.
/// - **E a janela deixa o clique passar em volta dele.** É a outra metade da
///   mesma coisa: a janela 0 é bem maior que o painel e o resto dela é
///   transparente mas ainda captura clique. Nos outros painéis isso é o "clicar
///   fora fecha"; aqui impedia de clicar na janela do Finder de onde os
///   arquivos viriam. Ver `_reportBounds`.
class NestOverlayView extends ConsumerStatefulWidget {
  const NestOverlayView({super.key});

  @override
  ConsumerState<NestOverlayView> createState() => _NestOverlayViewState();
}

class _NestOverlayViewState extends ConsumerState<NestOverlayView> {
  /// Segura o foco do painel — sem um nó focado, o `Shortcuts` não receberia
  /// tecla nenhuma. Não há campo de texto aqui, então ele é o único.
  final _panelFocusNode = FocusNode(debugLabel: 'nest-panel');

  /// Guardado num campo, e não lido do `ref` na hora: o `dispose` precisa
  /// desligar o destino de arraste, e ali o `BuildContext` já não vale.
  late final NestChannel _channel;

  /// O painel desenhado, para medir onde ele está dentro da janela.
  final _panelKey = GlobalKey(debugLabel: 'nest-panel-bounds');

  /// O último retângulo informado ao lado nativo, para não repetir a chamada a
  /// cada quadro da animação de altura.
  Rect? _reportedBounds;

  /// A largura do Pin estreito. A prateleira é uma lista de nomes de arquivo:
  /// mais estreita corta os nomes no meio, mais larga sobra vão à direita de
  /// linhas curtas.
  static const _panelWidth = 420.0;

  /// Quantas linhas cabem antes de a lista começar a rolar.
  static const _visibleItems = 6;

  @override
  void initState() {
    super.initState();
    _channel = ref.read(nestChannelProvider);
    HardwareKeyboard.instance.addHandler(_watchModifiers);
    unawaited(_channel.setDropEnabled(enabled: true));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_watchModifiers);
    unawaited(_channel.setDropEnabled(enabled: false));
    // A janela volta a capturar clique em toda a sua área — é o que os outros
    // painéis esperam dela.
    unawaited(_channel.setInteractiveRect(null));
    _panelFocusNode.dispose();
    super.dispose();
  }

  NestViewModel get _viewModel => ref.read(nestViewModelProvider.notifier);

  /// O `⌥` pressionado inverte copiar/mover, e a barra de dicas passa a dizer o
  /// que vai acontecer de verdade.
  ///
  /// Um observador, e não um atalho: `⌥` sozinho não é um `ShortcutActivator`, e
  /// o que interessa é o estado da tecla enquanto ela está para baixo. Devolve
  /// `false` sempre — ele olha o teclado, nunca consome a tecla.
  bool _watchModifiers(KeyEvent event) {
    _viewModel.setInvertHeld(isHeld: HardwareKeyboard.instance.isAltPressed);
    return false;
  }

  /// Informa ao lado nativo onde o painel está, para que o clique atravesse a
  /// janela em toda a área fora dele.
  ///
  /// A cada quadro, porque a altura do painel muda com o conteúdo — mas só
  /// **chama** quando o retângulo muda de fato: a animação de altura passaria a
  /// mesma medida trinta vezes por segundo depois de terminar.
  void _reportBounds() {
    final box = _panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final bounds = box.localToGlobal(Offset.zero) & box.size;
    if (bounds == _reportedBounds) return;

    _reportedBounds = bounds;
    unawaited(_channel.setInteractiveRect(bounds));
  }

  Future<void> _close() => OverlayWindow.instance.hide();

  /// `⌘,`: sai de cena primeiro, depois abre o Hub — nessa ordem, um problema
  /// ao criar a janela nunca deixa o painel preso na tela.
  Future<void> _openSettings() async {
    await _close();
    await HubWindow.instance.open();
  }

  Future<void> _reveal() async {
    final item = ref.read(nestViewModelProvider).cursorItem;
    if (item != null) await _viewModel.revealInFinder(item);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nestViewModelProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportBounds();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: NestOverlayIntents.shortcuts,
        child: Actions(
          actions: NestOverlayIntents.actions(
            onSend: _viewModel.sendToIndex,
            onRemove: _viewModel.removeSelected,
            onClear: _viewModel.clear,
            onUndo: _viewModel.undo,
            onMoveCursor: _viewModel.moveCursor,
            onSelectAll: _viewModel.selectAll,
            onReveal: _reveal,
            onClose: _close,
            onOpenSettings: _openSettings,
          ),
          child: EgOverlayShell(
            onClose: () => unawaited(_close()),
            onShow: _panelFocusNode.requestFocus,
            focusNode: _panelFocusNode,
            // Perder o foco é o gesto de ir buscar os arquivos, não o de
            // desistir da prateleira — ver a classe.
            dismissOnBlur: false,
            // Arrastar pelo fundo do painel move a janela: a prateleira fica
            // por cima de tudo, e às vezes o arquivo que se quer ver está
            // justamente atrás dela. Puxar **a lista** é outra coisa (leva os
            // arquivos embora), e ganha desta por estar mais fundo na árvore.
            draggable: true,
            child: EgPanel(
              key: _panelKey,
              width: _panelWidth,
              vibrant: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: AnimatedSize(
                      duration: AppDurations.medium,
                      curve: context.eg.motion.curve,
                      alignment: Alignment.center,
                      child: _body(state),
                    ),
                  ),
                  _hintBar(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(NestState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isEmpty) _empty(state) else _items(state),
        const SizedBox(height: AppSpacing.lg),
        _destinations(state),
      ],
    );
  }

  /// Com a prateleira vazia, o convite — ou, logo depois de um envio, o que
  /// acabou de acontecer.
  ///
  /// A mesma superfície para as duas coisas de propósito: mandar tudo embora
  /// esvazia a prateleira, e o lugar onde a lista estava é exatamente onde o
  /// olho já está quando ela some. Uma faixa de aviso à parte apareceria por
  /// dois segundos num painel que ficou vazio de qualquer jeito.
  Widget _empty(NestState state) => EgEmptyState(
    icon: EgIconData.tray,
    title: state.notice ?? 'A prateleira está vazia',
    message: state.notice != null && state.canUndo
        ? '⌘Z desfaz.'
        : 'Arraste arquivos para cá — ou chacoalhe um arquivo no meio do '
              'arraste — e mande todos juntos para uma pasta.',
  );

  Widget _items(NestState state) {
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < state.items.length; index++)
          NestItemCard(
            item: state.items[index],
            isSelected: state.selection.contains(index),
            // As modificadoras são lidas na hora do clique, e não guardadas no
            // estado: `⌘` e `⇧` aqui não mudam nada na tela enquanto seguradas
            // — diferente do `⌥`, que troca o que o painel promete fazer.
            onTap: () => _viewModel.select(
              index,
              toggle: HardwareKeyboard.instance.isMetaPressed,
              extend: HardwareKeyboard.instance.isShiftPressed,
            ),
            onRemove: () => _viewModel.removeAt(index),
          ),
      ],
    );

    final maxHeight = NestItemCard.height * _visibleItems;
    final body = state.items.length <= _visibleItems
        ? list
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(child: list),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Puxar a lista leva a prateleira inteira para fora — para uma pasta do
        // Finder, para o campo de anexo de um e-mail. Um `onPanStart`, e não um
        // botão: o gesto é o mesmo com que os arquivos chegaram aqui, e quem vem
        // do Dropover tenta isso antes de qualquer outra coisa. O toque continua
        // selecionando a linha; na arena do Flutter, quem se move ganha do
        // toque, e quem solta sem mover perde para ele.
        GestureDetector(
          onPanStart: (_) => unawaited(_viewModel.beginDragOut()),
          child: body,
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(
            'Ou arraste daqui para qualquer pasta.',
            style: context.eg.text.captionXS.copyWith(
              color: context.eg.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _destinations(NestState state) {
    if (!state.hasDestinations) {
      return Text(
        'Nenhuma pasta cadastrada. Abra as preferências com ⌘, e escolha as '
        'pastas para onde a prateleira manda.',
        style: context.eg.text.captionSmall,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgSectionLabel(
          state.effectiveMode == NestTransferMode.move
              ? 'Mover para'
              : 'Copiar para',
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
        ),
        for (var index = 0; index < state.destinations.length; index++)
          _DestinationRow(
            destination: state.destinations[index],
            number: index + 1,
            onTap: state.canSend
                ? () => unawaited(_viewModel.sendToIndex(index))
                : null,
          ),
      ],
    );
  }

  Widget _hintBar(NestState state) {
    if (state.isEmpty) {
      return EgHintBar(
        hints: [
          if (state.canUndo) const EgHint(keys: ['⌘Z'], label: 'desfazer'),
        ],
        trailing: const EgHint(keys: ['esc'], label: 'fechar'),
      );
    }

    final verb = state.effectiveMode == NestTransferMode.move
        ? 'mover'
        : 'copiar';

    return EgHintBar(
      hints: [
        EgHint(
          keys: const ['⌘1'],
          // "tudo" só quando é tudo mesmo: com dois de cinco escolhidos, a
          // dica precisa dizer quantos vão, senão ela promete a prateleira
          // inteira e entrega dois.
          label: state.isNarrowed
              ? '$verb ${state.selection.length}'
              : '$verb tudo',
        ),
        EgHint(
          keys: const ['⌥'],
          label: state.defaultMode == NestTransferMode.move
              ? 'copiar'
              : 'mover',
        ),
        if (state.selection.isNotEmpty)
          const EgHint(keys: ['⌫'], label: 'tirar'),
      ],
      trailing: const EgHint(keys: ['esc'], label: 'fechar'),
    );
  }
}

/// Uma pasta de destino no painel: o número do atalho e o nome.
///
/// Só o nome, sem o caminho: quem cadastrou a pasta sabe onde ela fica, e o
/// caminho inteiro numa linha de 420px viraria uma cauda de reticências. O
/// caminho está na tela de preferências, que é onde ele é útil.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.destination,
    required this.number,
    required this.onTap,
  });

  final NestDestination destination;
  final int number;

  /// Nulo com a prateleira vazia: a linha continua na tela, apagada, porque é
  /// ela que ensina o `⌘1` antes de haver o que enviar.
  final VoidCallback? onTap;

  /// A altura de linha de lista do aplicativo.
  static const _height = 34.0;

  /// Coluna do atalho, à direita — alinhada como o `⌘1` do Pin.
  static const _shortcutColumn = 28.0;

  @override
  Widget build(BuildContext context) {
    return EgInteractiveSurface(
      onTap: onTap,
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: context.eg.text.bodyCompactEmphasis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: _shortcutColumn,
            child: Text(
              '⌘$number',
              textAlign: TextAlign.right,
              style: context.eg.text.monoSmall.copyWith(
                color: context.eg.colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

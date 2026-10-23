import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/nest_channel.dart';
import '../../data/nest_file_service.dart';
import '../../data/nest_settings_repository.dart';
import '../../data/nest_transfer_repository.dart';
import '../../data/nest_destinations.dart';
import '../../models/nest_destination.dart';
import '../../models/nest_item.dart';
import '../../models/nest_transfer.dart';
import '../../models/nest_transfer_mode.dart';
import 'nest_state.dart';

final nestViewModelProvider = NotifierProvider<NestViewModel, NestState>(
  NestViewModel.new,
);

/// A prateleira do Nest.
///
/// Vive no engine da janela flutuante, e aqui isso é obrigatório e não
/// preferência: um arquivo pode chegar pelo canal nativo com
/// o painel fechado, e a prateleira precisa continuar cheia depois de o painel
/// se esconder. Fechar não esvazia — encerrar o aplicativo esvazia, porque o
/// conteúdo é referência a arquivo, não arquivo.
class NestViewModel extends Notifier<NestState> {
  late final NestFileService _files;
  late final NestSettingsRepository _settings;
  late final NestTransferRepository _transfers;
  late final NestChannel _channel;
  late final DateTime Function() _now;

  StreamSubscription<List<String>>? _drops;
  StreamSubscription<bool>? _dragOver;
  StreamSubscription<NestThumbnail>? _thumbnails;
  StreamSubscription<NestTransferMode?>? _dragOut;
  StreamSubscription<NestMovedOut>? _movedOut;

  /// Um envio ou um desfazer em curso.
  ///
  /// Os dois mexem em disco e demoram, e o `⌘1` segurado repete: sem a trava,
  /// a segunda chamada partia da mesma prateleira antes de a primeira voltar —
  /// copiando, nasciam `x 2.pdf`, `x 3.pdf`; desfazendo, os itens voltavam
  /// duas vezes.
  bool _busy = false;

  /// Os caminhos que o arraste em curso levou, guardados na partida.
  ///
  /// Não se relê `state.outgoing` no fim: no modo mover a linha sai da
  /// prateleira quando a promessa é cumprida, e isso pode chegar antes do fim
  /// da sessão.
  List<String> _draggingOutPaths = const [];

  /// O modo com que o arraste em curso saiu. `null` quando não há arraste.
  ///
  /// Guardado na partida porque é ali que a decisão foi tomada e mostrada na
  /// tela — o `⌥` solto no meio do caminho não muda o que já foi declarado ao
  /// sistema.
  NestTransferMode? _draggingOutAs;

  @override
  NestState build() {
    _files = ref.watch(nestFileServiceProvider);
    _now = ref.watch(clockProvider);
    _settings = ref.watch(nestSettingsRepositoryProvider);
    _transfers = ref.watch(nestTransferRepositoryProvider);
    _channel = ref.watch(nestChannelProvider);

    ref.onDispose(() {
      unawaited(_drops?.cancel());
      unawaited(_dragOver?.cancel());
      unawaited(_thumbnails?.cancel());
      unawaited(_dragOut?.cancel());
      unawaited(_movedOut?.cancel());
    });

    final settings = _settings.load();

    return NestState(
      destinations: settings.destinations,
      defaultMode: settings.defaultMode,
    );
  }

  /// Liga a escuta do lado nativo. Uma vez, no `EvergreenBootstrap`.
  ///
  /// Aqui, e não na tela: um arquivo pode chegar com o painel
  /// fechado — é o caminho principal do módulo, e um ouvinte que só existisse
  /// enquanto a tela está montada perderia justamente ele.
  void startListening() {
    _drops ??= _channel.onDropped.listen((paths) => unawaited(addPaths(paths)));
    _dragOver ??= _channel.onDragOver.listen(
      (isOver) => state = state.copyWith(isDragOver: isOver),
    );
    _thumbnails ??= _channel.onThumbnail.listen(_applyThumbnail);
    _dragOut ??= _channel.onDragOutEnded.listen(_finishDragOut);
    _movedOut ??= _channel.onMovedOut.listen(_applyMovedOut);
  }

  /// Arrasta a prateleira inteira para fora — para uma pasta do Finder, para o
  /// campo de anexo de um e-mail, para onde quer que aceite arquivos.
  ///
  /// Inteira, como o `⌘1`: juntar coisas de várias pastas para levá-las de uma
  /// vez é a razão de o módulo existir. Quem não quer um item junto o tira antes
  /// com o `⌫`.
  Future<void> beginDragOut() async {
    if (!state.canSend || _draggingOutAs != null || _busy) return;

    final mode = state.effectiveMode;
    final paths = [for (final item in state.outgoing) item.path];
    final started = await _channel.beginDragOut(
      paths,
      move: mode == NestTransferMode.move,
    );

    if (started) {
      _draggingOutAs = mode;
      _draggingOutPaths = paths;
    }
  }

  /// O arraste terminou. `null` é "soltou em lugar nenhum" — a prateleira fica
  /// como estava.
  ///
  /// Não há desfazer neste caminho, e é uma consequência, não um esquecimento:
  /// o destino é do sistema, e o Evergreen não guarda para onde os arquivos
  /// foram. Na cópia, quem desfaz é o `⌘Z` do próprio Finder.
  ///
  /// Copiando, a linha sai aqui: o original não sai do lugar, e quem copia é o
  /// destino. Movendo, **não**: o arraste é uma promessa que o lado nativo
  /// cumpre depois, e a linha só sai quando [_applyMovedOut] diz que o arquivo
  /// de fato mudou de lugar — o que falhou continua na prateleira.
  void _finishDragOut(NestTransferMode? operation) {
    final mode = _draggingOutAs;
    final paths = _draggingOutPaths;
    _draggingOutAs = null;
    _draggingOutPaths = const [];

    if (mode == null || operation == null || paths.isEmpty) return;

    final transfer = NestTransfer(
      at: _now(),
      mode: operation,
      destinationPath: '',
      movements: [
        for (final path in paths) NestMovement(source: path, destination: ''),
      ],
    );

    _transfers.insert(transfer);

    final promised = mode == NestTransferMode.move;
    final gone = paths.toSet();

    state = state.copyWith(
      items: promised
          ? state.items
          : [
              for (final item in state.items)
                if (!gone.contains(item.path)) item,
            ],
      clearSelection: true,
      clearUndo: true,
      notice: _noticeFor(transfer, null),
    );
  }

  /// A promessa de mover de um arquivo foi cumprida — ou falhou.
  void _applyMovedOut(NestMovedOut result) {
    final index = state.items.indexWhere((item) => item.path == result.path);
    if (index < 0) return;

    if (!result.moved) {
      state = state.copyWith(
        notice:
            'Não deu para mover ${state.items[index].name} — '
            'continua na prateleira.',
      );
      return;
    }

    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.path != result.path) item,
      ],
      clearSelection: true,
    );
  }

  /// Relê o que o Hub pode ter mudado e confere se os originais continuam lá.
  ///
  /// As duas coisas na abertura porque as duas mudam sem o painel saber: as
  /// pastas favoritas são editadas em outro engine, e um arquivo que espera na
  /// prateleira pode ter sido movido pelo Finder desde ontem.
  Future<void> prepareForOpen() async {
    await _settings.reload();
    final settings = _settings.load();

    state = state.copyWith(
      // Conferidas contra o disco: uma pasta favorita pode ter sido renomeada
      // no Finder desde a última abertura, e é aqui que o painel descobre.
      destinations: await NestDestinations.resolve(
        settings.destinations,
        _files,
      ),
      defaultMode: settings.defaultMode,
      isDragOver: false,
      // A oferta de desfazer não atravessa uma abertura: ela existe para o
      // engano de um segundo atrás.
      clearUndo: true,
    );

    await _refreshItems();
  }

  /// `⇧⌫`: tira da prateleira tudo o que sumiu do disco.
  ///
  /// A prateleira guarda referências, não arquivos — quando o original é
  /// apagado ou movido pelo Finder, a linha fica marcada e não serve mais para
  /// nada: mandá-la para um destino falha, e arrastá-la para fora não leva
  /// coisa alguma. Marcar era metade do trabalho; **isto é a outra metade**, e
  /// numa prateleira que junta arquivos de várias pastas ao longo do dia é o
  /// que evita ter de tirar sete linhas mortas uma a uma.
  ///
  /// Nenhum arquivo é tocado, porque não há arquivo: é uma limpeza de lista.
  void removeMissing() {
    final indexes = <int>{
      for (var index = 0; index < state.items.length; index++)
        if (state.items[index].isMissing) index,
    };
    if (indexes.isEmpty) return;

    _removeAll(indexes);
    state = state.copyWith(
      notice: indexes.length == 1
          ? '1 item que sumiu foi tirado da prateleira.'
          : '${indexes.length} itens que sumiram foram tirados da prateleira.',
    );
  }

  /// Acrescenta o que foi solto, na ordem em que veio.
  ///
  /// O que já está na prateleira não entra duas vezes: soltar de novo a mesma
  /// pasta é o gesto de quem não lembrava que já a tinha soltado, não o de quem
  /// quer duas linhas iguais.
  Future<void> addPaths(List<String> paths) async {
    final known = {for (final item in state.items) item.path};
    final added = <NestItem>[];

    for (final path in paths) {
      if (known.contains(path)) continue;

      final item = await _files.inspect(path);
      if (item == null) continue;

      known.add(path);
      added.add(item);
    }

    if (added.isEmpty) return;

    final items = [...state.items, ...added];

    state = state.copyWith(
      items: items,
      // Sem escolha nenhuma: sem ela, sai a prateleira inteira — que é o que
      // quem acabou de soltar cinco arquivos quer. Ver `NestState.selection`.
      clearSelection: true,
      isDragOver: false,
      clearNotice: true,
    );

    for (final item in added) {
      unawaited(_channel.requestThumbnail(item.path));
    }
  }

  /// Escolhe um item — do jeito do Finder.
  ///
  /// Clique sozinho troca a escolha; `⌘` acrescenta ou tira um; `⇧` estende do
  /// cursor até aqui. São os três gestos que qualquer pessoa já traz aprendidos,
  /// e por isso nenhum deles aparece na barra de dicas.
  void select(int index, {bool toggle = false, bool extend = false}) {
    if (index < 0 || index >= state.items.length) return;

    if (extend && state.cursor != null) {
      final from = state.cursor!;
      final low = from < index ? from : index;
      final high = from < index ? index : from;

      state = state.copyWith(selection: {for (var i = low; i <= high; i++) i});
      return;
    }

    if (toggle) {
      final selection = {...state.selection};
      if (!selection.remove(index)) selection.add(index);

      state = state.copyWith(selection: selection, cursor: index);
      return;
    }

    state = state.copyWith(selection: {index}, cursor: index);
  }

  /// Esquece a escolha: volta a valer a prateleira inteira.
  ///
  /// É o que a pilha do notch pede ao aparecer — ela mostra e manda **tudo**,
  /// e uma escolha deixada na prateleira completa faria o `⌘1` da pilha mandar
  /// só dois de cinco sem que a pilha mostrasse quais.
  void clearSelection() {
    if (state.selection.isEmpty) return;

    state = state.copyWith(clearSelection: true);
  }

  void selectAll() {
    if (state.isEmpty) return;

    state = state.copyWith(
      selection: {
        for (var index = 0; index < state.items.length; index++) index,
      },
    );
  }

  /// Anda na lista, sem dar a volta: a prateleira é curta e um cursor que salta
  /// do fim para o começo faz perder o lugar.
  ///
  /// Com [extend], o item novo entra na escolha em vez de substituí-la — é o
  /// `⇧↑`/`⇧↓` de qualquer lista do macOS.
  void moveCursor(int delta, {bool extend = false}) {
    if (state.isEmpty) return;

    final current = state.cursor ?? 0;
    final next = (current + delta).clamp(0, state.items.length - 1);

    state = state.copyWith(
      selection: extend ? {...state.selection, next} : {next},
      cursor: next,
    );
  }

  /// Tira um item da prateleira. O arquivo não é tocado — ele nunca saiu do
  /// lugar.
  void removeAt(int index) => _removeAll({index});

  /// `⌫`: tira da prateleira tudo o que estiver escolhido.
  void removeSelected() => _removeAll(state.selection);

  void _removeAll(Set<int> indexes) {
    if (indexes.isEmpty) return;

    final items = [
      for (var index = 0; index < state.items.length; index++)
        if (!indexes.contains(index)) state.items[index],
    ];

    if (items.isEmpty) {
      state = state.copyWith(items: items, clearSelection: true);
      return;
    }

    // O cursor fica onde estava o primeiro que saiu, e a escolha volta a ser
    // uma linha só: depois de tirar três itens do meio, manter três posições
    // escolhidas apontaria para arquivos que ninguém escolheu.
    final cursor = indexes
        .reduce((a, b) => a < b ? a : b)
        .clamp(0, items.length - 1);

    state = state.copyWith(items: items, selection: {cursor}, cursor: cursor);
  }

  /// Esvazia a prateleira. Nenhum arquivo é apagado — só a lista de referências.
  void clear() {
    if (state.isEmpty) return;

    state = state.copyWith(
      items: const [],
      clearSelection: true,
      clearNotice: true,
    );
  }

  void setInvertHeld({required bool isHeld}) {
    if (state.isInvertHeld == isHeld) return;

    state = state.copyWith(isInvertHeld: isHeld);
  }

  /// Manda **a prateleira inteira** para o destino da posição [index].
  ///
  /// Inteira, e não só o item selecionado: juntar coisas de várias pastas para
  /// mandá-las de uma vez é a razão de o módulo existir. Quem não quer um item
  /// junto o tira antes, com o `⌫`.
  Future<void> sendToIndex(int index) async {
    final destinations = state.destinations;
    if (index < 0 || index >= destinations.length) return;

    await sendTo(destinations[index]);
  }

  Future<void> sendTo(NestDestination destination) async {
    if (_busy || !state.canSend) return;

    _busy = true;
    try {
      await _sendTo(destination);
    } finally {
      _busy = false;
    }
  }

  Future<void> _sendTo(NestDestination destination) async {
    final mode = state.effectiveMode;
    final chosen = state.outgoing;
    final transfer = await _files.send(
      items: chosen,
      destination: destination,
      mode: mode,
    );

    // O que falhou continua na prateleira — some da tela só o que realmente
    // chegou ao destino. Uma lista que se esvazia inteira depois de uma falha
    // esconde exatamente o arquivo que precisa de atenção.
    //
    // Marcado como "sumiu" só o que sumiu de fato: falta de permissão ou de
    // espaço não tira o arquivo do lugar, e marcá-lo levaria o `⇧⌫` a tirar da
    // prateleira um arquivo que continua lá.
    final vanished = <String>{
      for (final failure in transfer.failures)
        if (!await _files.exists(failure.path)) failure.path,
    };
    final sent = {for (final movement in transfer.movements) movement.source};
    final kept = [
      for (final item in state.items)
        if (vanished.contains(item.path))
          item.copyWith(isMissing: true)
        else if (!sent.contains(item.path))
          item,
    ];

    final id = _transfers.insert(transfer);

    state = state.copyWith(
      items: kept,
      clearSelection: true,
      lastTransfer: transfer.isEmpty ? null : transfer,
      lastTransferId: transfer.isEmpty ? null : id,
      clearUndo: transfer.isEmpty,
      notice: _noticeFor(transfer, destination),
    );
  }

  /// `⌘Z`: devolve o que a última transferência levou.
  ///
  /// Apaga também a linha que o Track leu: uma transferência desfeita não
  /// organizou nada, e contá-la seria contar arquivos que voltaram para onde
  /// estavam.
  Future<void> undo() async {
    if (_busy || state.lastTransfer == null) return;

    _busy = true;
    try {
      await _undo(state.lastTransfer!);
    } finally {
      _busy = false;
    }
  }

  Future<void> _undo(NestTransfer transfer) async {
    final restored = await _files.undo(transfer);

    final id = state.lastTransferId;
    if (id != null) _transfers.delete(id);

    // Os originais voltaram para o lugar: a prateleira volta a apontar para
    // eles, na ordem em que estavam.
    final items = <NestItem>[];
    for (final movement in transfer.movements) {
      final item = await _files.inspect(movement.source);
      if (item != null) items.add(item);
    }

    state = state.copyWith(
      items: [...items, ...state.items],
      clearSelection: true,
      clearUndo: true,
      notice: restored == 0
          ? 'Não deu para desfazer — os arquivos já foram mexidos.'
          : null,
      clearNotice: restored > 0,
    );

    for (final item in items) {
      unawaited(_channel.requestThumbnail(item.path));
    }
  }

  Future<void> revealInFinder(NestItem item) =>
      _channel.revealInFinder(item.path);

  /// Manda o original para o Lixo e tira a linha da prateleira.
  ///
  /// Para o Lixo, e não `File.delete`: o Lixo tem o desfazer do Finder, e este
  /// é o único caminho do módulo que apaga um arquivo de verdade.
  Future<void> moveToTrash(int index) async {
    if (index < 0 || index >= state.items.length) return;

    final item = state.items[index];
    if (await _channel.moveToTrash(item.path)) removeAt(index);
  }

  void _applyThumbnail(NestThumbnail thumbnail) {
    var changed = false;

    final items = [
      for (final item in state.items)
        if (item.path == thumbnail.path)
          () {
            changed = true;
            return item.copyWith(thumbnail: thumbnail.bytes);
          }()
        else
          item,
    ];

    if (changed) state = state.copyWith(items: items);
  }

  /// Reconfere no disco o que a prateleira está mostrando.
  ///
  /// A conferência é feita sobre uma foto da prateleira, mas aplicada sobre a
  /// prateleira **de agora**, por caminho: as leituras demoram, e um envio que
  /// estava em curso quando o painel reabriu pode ter tirado linhas nesse
  /// meio-tempo. Regravar a foto traria de volta o que já foi enviado.
  Future<void> _refreshItems() async {
    if (state.isEmpty) return;

    final checked = <String, NestItem?>{};
    for (final item in state.items) {
      checked[item.path] = await _files.inspect(item.path);
    }

    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (checked.containsKey(item.path))
            _rechecked(item, checked[item.path])
          else
            item,
      ],
    );
  }

  NestItem _rechecked(NestItem item, NestItem? fresh) => fresh == null
      ? item.copyWith(isMissing: true)
      // A miniatura já lida continua valendo: o arquivo é o mesmo, e pedi-la de
      // novo a cada abertura faria a prateleira piscar.
      : fresh.copyWith(thumbnail: item.thumbnail);

  /// [destination] é nulo no arraste para fora: ali o destino é do sistema, e o
  /// Evergreen não sabe o nome dele.
  String _noticeFor(NestTransfer transfer, NestDestination? destination) {
    if (transfer.isEmpty) {
      return 'Nada foi enviado: ${transfer.failures.first.reason}.';
    }

    final verb = transfer.mode == NestTransferMode.move ? 'movido' : 'copiado';
    final count = transfer.fileCount;
    final subject = count == 1 ? '1 arquivo $verb' : '$count arquivos ${verb}s';
    final where = destination == null ? '' : ' para ${destination.label}';
    final tail = transfer.hasFailures
        ? ' — ${transfer.failures.length} ficaram para trás'
        : '';

    return '$subject$where$tail.';
  }
}

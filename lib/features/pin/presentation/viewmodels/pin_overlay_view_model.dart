import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/clipboard_repository.dart';
import '../../data/clipboard_watcher.dart';
import '../../data/pin_image_store.dart';
import '../../models/pin_image.dart';
import '../../data/pin_settings_repository.dart';
import '../../models/clipboard_item.dart';
import '../../models/clipboard_item_type.dart';
import '../../models/pin_quick_shortcut.dart';
import '../../models/pin_search.dart';
import '../../models/tax_id.dart';
import 'pin_overlay_state.dart';

final pinOverlayViewModelProvider =
    NotifierProvider<PinOverlayViewModel, PinOverlayState>(
      PinOverlayViewModel.new,
    );

/// Orquestra o histórico da área de transferência exibido no overlay.
///
/// Mantém a lista completa em memória e recalcula a filtragem localmente: com
/// algumas centenas de itens isso é instantâneo e evita ir ao banco a cada
/// tecla digitada.
class PinOverlayViewModel extends Notifier<PinOverlayState> {
  late final ClipboardRepository _repository;
  late final ClipboardWatcher _watcher;
  late final PinSettingsRepository _settings;
  late final PinImageStore _images;
  late final PinImageJanitor _janitor;

  StreamSubscription<String>? _watchSubscription;
  StreamSubscription<CapturedImage>? _imageSubscription;

  List<ClipboardItem> _allItems = const [];

  /// De qual documento é o número que está na linha do gerador.
  ///
  /// Não dá para deduzir do próprio número: `state.generatedTaxId` é uma
  /// `String`, e o filtro já mudou quando se pergunta. Sem isto, sair do CPF e
  /// entrar no CNPJ deixaria o CPF sorteado escrito na linha "Gerar CNPJ" — o
  /// número preservado é o do filtro em que se está, não o último que existiu.
  TaxIdKind? _generatedKind;

  @override
  PinOverlayState build() {
    _repository = ref.watch(clipboardRepositoryProvider);
    _watcher = ref.watch(clipboardWatcherProvider);
    _settings = ref.watch(pinSettingsRepositoryProvider);
    _images = ref.watch(pinImageStoreProvider);
    _janitor = ref.watch(pinImageJanitorProvider);

    ref.onDispose(() {
      _watchSubscription?.cancel();
      _imageSubscription?.cancel();
    });

    return PinOverlayState();
  }

  /// Liga a captura da área de transferência. Chamado uma única vez, na
  /// inicialização do app — a captura roda mesmo com o overlay fechado.
  void startWatching() {
    _watchSubscription ??= _watcher.onCopy.listen(_onClipboardChanged);
    _imageSubscription ??= _watcher.onImage.listen(_onImageCopied);
    _watcher.start();

    // Antes da primeira carga: o filtro por tipo mostra o que o classificador
    // enxerga, e um histórico classificado por uma versão anterior apareceria
    // inteiro como "Texto". Custa uma passada por até 500 linhas, uma única vez
    // na vida do banco (ver `ClipboardItemClassifier.version`).
    _repository.reclassifyOutdated();

    // O que um "Limpar histórico" do Hub, ou uma restauração de backup,
    // deixou sem linha desde a última abertura.
    _janitor.sweep();

    load();
  }

  /// Desliga a captura da área de transferência.
  ///
  /// O caminho do módulo desligado, e a metade do interruptor que mais importa:
  /// o Pin registra **tudo** o que passa pela área de transferência, senha
  /// inclusive. Desligá-lo tem de parar a escrita, não só esconder a porta.
  ///
  /// O histórico que já existe fica onde está — religar devolve a lista como
  /// ela ficou.
  Future<void> stopWatching() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    await _imageSubscription?.cancel();
    _imageSubscription = null;
    await _watcher.stop();
  }

  /// Recarrega o histórico do banco.
  void load() {
    _allItems = _repository.loadAll();
    _emitResults(resetSelection: true);
  }

  /// Prepara o overlay para ser exibido: limpa a busca, tira o filtro e
  /// recarrega a lista.
  ///
  /// O filtro sai junto da busca porque ele é do mesmo tipo de coisa: um
  /// recorte da vez, não uma preferência. Encontrar o Pin filtrado por um tipo
  /// escolhido ontem seria encontrá-lo com metade do histórico faltando, sem
  /// nada explicando o porquê.
  Future<void> prepareForOpen() async {
    // As preferências são editadas no Hub, que é outro engine: sem reler, o
    // painel abriria com os tipos de ontem. O aviso pelo canal
    // (`ModuleSettingsHost`) já releu esta cópia no instante da mudança — esta
    // leitura é o cinto: se o canal falhar, o painel ainda abre certo.
    await _settings.reload();

    state = state.copyWith(
      query: '',
      typeFilter: null,
      keepTypeFilter: false,
      // O número sai junto do filtro: um CPF sorteado ontem, ainda na tela hoje,
      // pareceria um item do histórico que sobrou de alguma coisa.
      generatedTaxId: null,
      keepGeneratedTaxId: false,
    );
    _generatedKind = null;
    load();
  }

  void search(String query) {
    state = state.copyWith(query: query);
    _emitResults(resetSelection: true);
  }

  /// Troca o tipo exibido. `null` é "Tudo".
  void setTypeFilter(ClipboardItemType? type) {
    if (type == state.typeFilter) return;

    state = state.copyWith(typeFilter: type, keepTypeFilter: false);
    _emitResults(resetSelection: true);
  }

  /// Anda pela fila de pílulas com `⌘←` / `⌘→`, parando nas pontas.
  ///
  /// Para nas pontas, e não dá a volta, pela mesma razão do `EgSegmentedControl`
  /// e da lista: um seletor que volta ao começo sozinho faz duvidar de onde se
  /// está quando a tecla é repetida sem olhar.
  void cycleTypeFilter(int delta) {
    if (!state.hasTypeFilter) return;

    final options = state.typeFilterOptions;
    final current = options.indexOf(state.typeFilter);
    if (current < 0) return;

    setTypeFilter(options[(current + delta).clamp(0, options.length - 1)]);
  }

  /// Tira o filtro. Devolve `false` se não havia nenhum — é assim que o Esc
  /// sabe que não tem nada a desfazer e pode fechar o overlay.
  bool clearTypeFilter() {
    if (state.typeFilter == null) return false;

    setTypeFilter(null);
    return true;
  }

  /// Move a seleção com ↑/↓, parando nas extremidades da lista.
  ///
  /// Com a linha do gerador na tela o piso desce para `-1`, que é ela: o `↑` a
  /// partir do primeiro item chega no gerador, e o `↓` volta para a lista.
  void moveSelection(int delta) {
    if (state.results.isEmpty && !state.hasGenerator) return;

    final floor = state.hasGenerator ? -1 : 0;
    final next = (state.selectedIndex + delta).clamp(
      floor,
      state.results.length - 1,
    );
    if (next == state.selectedIndex) return;

    state = state.copyWith(selectedIndex: next);
  }

  /// Reordena o fixado selecionado dentro do grupo (`⌥↑` / `⌥↓`).
  ///
  /// Troca de lugar com o vizinho **visível**: com uma busca ativa o grupo está
  /// filtrado, e o que a pessoa vê acontecer é o item passar por cima de quem
  /// estava ao lado dele na tela. Nas pontas do grupo o atalho não faz nada —
  /// sair dos fixados por baixo significaria desafixar, que é trabalho do ⌘P.
  void movePinnedSelection(int delta) {
    if (!state.canMoveSelectedPinned) return;

    final item = state.selectedItem!;
    final pinned = state.pinned;
    final index = pinned.indexWhere((it) => it.id == item.id);
    if (index < 0) return;

    final target = index + delta;
    if (target < 0 || target >= pinned.length) return;

    final id = item.id;
    final targetId = pinned[target].id;
    if (id == null || targetId == null) return;

    _repository.swapPinnedOrder(id, targetId);
    _allItems = _repository.loadAll();

    // Sem `preferredIndex`: a seleção segue o item pelo id, que é o ponto —
    // quem se move é a linha, não o cursor.
    _emitResults();
  }

  void selectItem(ClipboardItem item) {
    final index = state.results.indexOf(item);
    if (index < 0) return;
    state = state.copyWith(selectedIndex: index);
  }

  /// Devolve o item selecionado à área de transferência.
  ///
  /// Retorna `false` se não havia seleção, para que a view saiba que não deve
  /// fechar o overlay.
  Future<bool> copySelected() async {
    if (state.isGeneratorSelected) {
      await copyGeneratedTaxId();
      return true;
    }

    final item = state.selectedItem;
    if (item == null) return false;

    return copyItem(item);
  }

  /// Sorteia outro documento para a linha do gerador (`⌘G`).
  ///
  /// Só troca o número — quem copia é o Enter. Fora dos filtros de CPF e de
  /// CNPJ a linha não existe, e a tecla não tem o que fazer. Qual documento
  /// sortear é o filtro que diz: a mesma tecla no CNPJ devolve um CNPJ.
  void regenerateTaxId() {
    final kind = state.typeFilter?.taxIdKind;
    if (kind == null) return;

    state = state.copyWith(generatedTaxId: TaxId.generate(kind));
  }

  /// Copia o documento sorteado, que entra no histórico como qualquer cópia.
  ///
  /// Passa pelo mesmo [copyItem] dos itens da lista: um item ainda sem `id` é o
  /// que a captura já produz, e o `upsert` resolve pelo conteúdo. É por isso que
  /// o gerador não precisou de nada novo no repositório — e é o que faz o número
  /// voltar depois em `⌘1`, classificado como CPF.
  Future<void> copyGeneratedTaxId() async {
    final generated = state.generatedTaxId;
    if (generated == null) return;

    await copyItem(ClipboardItem.capture(generated));
  }

  /// Copia o item alcançado por `⌘N` / `⌥N`.
  ///
  /// Retorna `false` quando o slot está vazio — a view usa isso para não fechar
  /// o overlay à toa se o usuário apertar um número que não existe na lista.
  Future<bool> copyByShortcut(PinShortcutGroup group, int number) async {
    final item = state.itemForShortcut(group, number);
    if (item == null) return false;

    return copyItem(item);
  }

  /// Fixa ou desafixa o item selecionado (`⌘P`).
  void togglePinSelected() {
    final item = state.selectedItem;
    if (item == null) return;

    togglePin(item);
  }

  /// Apaga o item selecionado (`⌘⌫`).
  void deleteSelected() {
    final item = state.selectedItem;
    if (item == null) return;

    delete(item);
  }

  /// Diz se o item selecionado deve ser colado automaticamente no app anterior.
  ///
  /// Relê as preferências do disco antes de responder: o toggle vive no Hub,
  /// que roda em outro engine, então o cache em memória deste engine pode estar
  /// defasado.
  Future<bool> shouldAutoPaste() async {
    await _settings.reload();
    return _settings.load().autoPaste;
  }

  /// Há o que copiar neste item — `false` só na imagem cujo arquivo não está
  /// mais no disco, ou cuja descrição não sobreviveu no banco. É o que desliga
  /// o "Copiar" do preview.
  bool canCopy(ClipboardItem item) {
    if (item.type != ClipboardItemType.image) return true;

    final image = item.image;
    return image != null && _images.exists(image.fileName);
  }

  /// Põe o item na área de transferência e devolve se pôs.
  ///
  /// `false` só numa imagem sem arquivo — e é o que impede o painel de fechar
  /// e colar: com o auto-colar ligado, fechar mesmo assim despejaria no outro
  /// aplicativo o que estava na área de transferência **antes**, que ninguém
  /// pediu.
  Future<bool> copyItem(ClipboardItem item) async {
    final image = item.image;

    if (image != null) {
      // A imagem em si, e não o caminho — é o que o destino cola. Sem o
      // arquivo (uma restauração de backup traz a linha e não a imagem) não
      // há o que escrever, e a área de transferência fica como estava.
      if (!_images.exists(image.fileName)) return false;
      if (!await _watcher.writeImage(_images.pathOf(image.fileName))) {
        return false;
      }
    } else if (item.type == ClipboardItemType.image) {
      // Imagem cuja descrição não sobreviveu no banco: a chave `imagem:…` não
      // é algo que alguém queira colar.
      return false;
    } else {
      await Clipboard.setData(ClipboardData(text: item.content));

      // Sem isso a captura leria a nossa própria escrita como uma cópia nova.
      // Aguardado de propósito: é o que garante que a marcação chegue ao lado
      // nativo antes do próximo ciclo de leitura do pasteboard.
      await _watcher.acknowledge(item.content);
    }

    _repository.upsert(item.copyWith(copiedAt: DateTime.now()));
    _allItems = _repository.loadAll();
    _emitResults();
    return true;
  }

  void togglePin(ClipboardItem item) {
    final id = item.id;
    if (id == null) return;

    _repository.setPinned(id, isPinned: !item.isPinned);
    _allItems = _repository.loadAll();
    _emitResults();
  }

  /// Guarda o apelido do item — texto em branco tira o que havia.
  ///
  /// Só toca o banco quando o texto muda de verdade: o campo confirma sozinho
  /// ao perder o foco, então fechar o overlay sem editar nada passaria por aqui
  /// a cada abertura.
  void setAlias(ClipboardItem item, String alias) {
    final id = item.id;
    if (id == null) return;

    final trimmed = alias.trim();
    if (trimmed == (item.alias?.trim() ?? '')) return;

    _repository.setAlias(id, trimmed);
    _allItems = _repository.loadAll();
    _emitResults();
  }

  void delete(ClipboardItem item) {
    final id = item.id;
    if (id == null) return;

    _repository.delete(id);
    _janitor.sweep();
    _allItems = _repository.loadAll();

    // Mantém a seleção na mesma posição da lista, que agora aponta para o item
    // seguinte — o comportamento esperado ao apagar vários itens em sequência.
    _emitResults(preferredIndex: state.selectedIndex);
  }

  void _onClipboardChanged(String content) {
    final captured = ClipboardItem.capture(content);
    final settings = _settings.load();

    // O tipo desligado é **deixado passar**, e não guardado e escondido: o que
    // não está no banco não vaza por backup, por restauração nem por um bug de
    // filtro. É a diferença entre "não mostrar" e "não registrar", e num
    // gerenciador de área de transferência ela é a única que importa.
    if (!settings.captures(captured.type)) return;

    _store(captured, settings.historyLimit);
  }

  /// Uma imagem copiada: vira arquivo na pasta de imagens e linha no
  /// histórico, com a mesma regra do texto — o tipo desligado não é
  /// registrado, nem como arquivo.
  void _onImageCopied(CapturedImage captured) {
    final settings = _settings.load();
    if (!settings.captures(ClipboardItemType.image)) return;

    final PinImage image;
    try {
      image = _images.save(captured);
    } on FileSystemException {
      // Disco cheio, pasta sem permissão: a cópia não entra, e nada mais
      // deixa de funcionar. Uma linha sem o arquivo seria pior — ela
      // prometeria uma imagem que não está em lugar nenhum.
      return;
    }

    _store(ClipboardItem.fromImage(image), settings.historyLimit);
  }

  void _store(ClipboardItem captured, int historyLimit) {
    _repository.upsert(captured);
    _repository.trimHistory(historyLimit);

    // O teto pode ter levado uma imagem — o arquivo dela sai junto. Pergunta
    // ao banco, e não à lista em memória: uma restauração de backup feita no
    // Hub traz linhas que esta janela ainda não leu. Sem imagem nenhuma, não
    // varre — seria abrir a pasta a cada texto copiado.
    if (captured.isImage || _repository.imageFiles().isNotEmpty) {
      _janitor.sweep();
    }

    _allItems = _repository.loadAll();
    _emitResults();
  }

  /// Reaplica busca e filtro sobre [_allItems] e ajusta a seleção.
  void _emitResults({bool resetSelection = false, int? preferredIndex}) {
    final availableTypes = _availableTypes();

    // O tipo escolhido pode ter acabado de sair do histórico — apagar o último
    // link com o filtro em "Links" tira a própria pílula de baixo do dedo. Sem
    // isto, o seletor ficaria apontando para uma opção que não está mais na
    // fila, e a lista ficaria vazia sem nada explicando por quê.
    final type = availableTypes.contains(state.typeFilter)
        ? state.typeFilter
        : null;

    final results = _rank(type);

    // O número é sorteado ao entrar num filtro de documento e esquecido ao sair
    // — mas **preservado** enquanto ele durar. Sortear a cada `_emitResults`
    // faria a linha trocar de número a cada tecla digitada na busca, embaixo do
    // dedo de quem estava lendo o documento para conferir.
    //
    // Trocar de documento **não** é durar: sair do CPF e entrar no CNPJ passa
    // por `null` no meio (o filtro intermediário, ou o próprio "Tudo"), e o que
    // é preservado é o número do filtro em que se está. Um CPF sobrevivendo na
    // linha "Gerar CNPJ" seria pior que sortear demais.
    final kind = type?.taxIdKind;
    final generated = kind == null
        ? null
        : (_generatedKind == kind ? state.generatedTaxId : null) ??
              TaxId.generate(kind);
    _generatedKind = kind;

    state = state.copyWith(
      results: results,
      typeFilter: type,
      keepTypeFilter: false,
      availableTypes: availableTypes,
      isLoading: false,
      generatedTaxId: generated,
      keepGeneratedTaxId: false,
      selectedIndex: _resolveSelection(
        results,
        resetSelection: resetSelection,
        preferredIndex: preferredIndex,
        hasGenerator: generated != null,
      ),
    );
  }

  /// Filtra o histórico pela busca e pelo tipo, e ordena o que sobrou.
  ///
  /// **Os fixados não são reordenados.** Eles são a camada `⌥`, não um
  /// resultado de busca: `⌥2` precisa continuar apontando para o mesmo item
  /// enquanto se digita, e a ordem deles é a que a pessoa arrumou à mão com
  /// `⌥↑`/`⌥↓`. Quem é ranqueado por relevância é o grupo dos recentes.
  ///
  /// Sem busca, ninguém é reordenado: a ordem é a do banco (fixados primeiro,
  /// depois por `copiedAt`), que é a lista em repouso.
  List<ClipboardItem> _rank(ClipboardItemType? type) {
    final matched = <_ScoredItem>[];
    final settings = _settings.load();

    for (final item in _allItems) {
      if (type != null && item.type != type) continue;
      // Desligado é desligado, inclusive para o que já estava guardado: o item
      // continua no banco (religar o devolve), mas não aparece.
      if (!settings.captures(item.type)) continue;

      final match = PinSearch.match(item, state.query);
      if (match == null) continue;

      matched.add(_ScoredItem(item, match.score));
    }

    if (state.query.trim().isEmpty) {
      return matched.map((scored) => scored.item).toList(growable: false);
    }

    final pinned = <ClipboardItem>[];
    final recent = <_ScoredItem>[];
    for (final scored in matched) {
      if (scored.item.isPinned) {
        pinned.add(scored.item);
      } else {
        recent.add(scored);
      }
    }

    // O desempate por `copiedAt` não é enfeite: `List.sort` não é estável, e sem
    // um segundo critério dois itens de mesma nota trocariam de lugar entre uma
    // tecla e outra — a lista piscaria embaixo do dedo de quem digita.
    recent.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      return b.item.copiedAt.compareTo(a.item.copiedAt);
    });

    return [
      ...pinned,
      ...recent.map((scored) => scored.item),
    ].toList(growable: false);
  }

  /// Os tipos presentes no histórico, na ordem do enum.
  ///
  /// **CPF e CNPJ são a exceção: os dois estão sempre na fila**, tenha o
  /// histórico um ou nenhum. Desde que a pílula passou a ter o gerador dentro
  /// dela, ela deixou de ser só um recorte do que já existe — e a regra geral a
  /// esconderia justamente de quem ainda não tem documento nenhum, que é quem
  /// precisa gerar um.
  List<ClipboardItemType> _availableTypes() {
    final settings = _settings.load();
    final present = _allItems.map((item) => item.type).toSet()
      ..addAll(TaxIdKind.values.map((kind) => kind.itemType));

    // O tipo desligado sai da fila mesmo com itens dele no banco: o que a tela
    // de preferências desligou tem de sumir **do Pin**, senão ela diz uma coisa
    // e o painel mostra outra. Religar devolve tudo — nada é apagado aqui.
    return ClipboardItemType.values
        .where(
          (type) =>
              type.hasFilter &&
              present.contains(type) &&
              settings.captures(type),
        )
        .toList(growable: false);
  }

  int _resolveSelection(
    List<ClipboardItem> results, {
    required bool resetSelection,
    required bool hasGenerator,
    int? preferredIndex,
  }) {
    if (results.isEmpty) return -1;

    // A seleção que já estava no gerador fica onde está: uma cópia capturada em
    // outro app não é motivo para tirar o cursor da linha que a pessoa estava
    // olhando. Trocar de filtro é (daí o `resetSelection` vir antes disto).
    if (resetSelection) return 0;
    if (hasGenerator && state.selectedIndex == -1) return -1;

    if (preferredIndex != null) {
      return preferredIndex.clamp(0, results.length - 1);
    }

    // Preserva o item selecionado mesmo que ele tenha mudado de posição.
    final current = state.selectedItem;
    if (current != null) {
      final index = results.indexWhere((item) => item.id == current.id);
      if (index >= 0) return index;
    }

    return state.selectedIndex.clamp(0, results.length - 1);
  }
}

/// Um item com a nota que a busca deu a ele — ver [PinOverlayViewModel._rank].
class _ScoredItem {
  const _ScoredItem(this.item, this.score);

  final ClipboardItem item;
  final int score;
}

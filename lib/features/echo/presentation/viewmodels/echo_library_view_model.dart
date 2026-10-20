import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/storage/export_service.dart';
import '../../../home/presentation/viewmodels/app_settings_view_model.dart';
import '../../data/echo_channel.dart';
import '../../data/echo_repository.dart';
import '../../data/echo_summary_runner.dart';
import '../../models/echo_capabilities.dart';
import '../../models/echo_summary_status.dart';
import '../../models/meeting.dart';
import '../../models/meeting_document.dart';
import '../../models/meeting_search.dart';

final echoLibraryViewModelProvider =
    NotifierProvider<EchoLibraryViewModel, EchoLibraryState>(
      EchoLibraryViewModel.new,
    );

/// Um pedido para a leitura ir até um trecho — o Enter num resultado da busca.
///
/// Carrega um número de série, e não só o destino: abrir o mesmo trecho duas
/// vezes seguidas (a pessoa rolou para longe e quer voltar) precisa ser um
/// pedido novo, e um destino igual ao anterior não mudaria nada para quem
/// compara.
class EchoJump {
  const EchoJump({
    required this.serial,
    required this.meetingId,
    this.kind,
    this.atMs,
    this.turnStartMs,
  });

  final int serial;
  final int meetingId;

  /// Que face abrir. `null` quando a reunião casou só pelo título — aí a
  /// leitura fica na aba em que estava.
  final MeetingHitKind? kind;

  /// Onde o áudio para, pronto para tocar dali. `null` no resumo.
  final int? atMs;

  /// A fala que a leitura vai buscar.
  final int? turnStartMs;
}

/// Uma linha da lista de resultados: a reunião, ou um trecho dela.
///
/// É a unidade em que o teclado anda — `↑↓` passam pela reunião e pelos
/// trechos dela na ordem em que estão desenhados.
class EchoSearchEntry {
  const EchoSearchEntry(this.result, [this.hit]);

  final MeetingSearchResult result;

  /// `null` na linha da própria reunião.
  final MeetingHit? hit;
}

class EchoLibraryState {
  const EchoLibraryState({
    this.meetings = const [],
    this.selectedId,
    this.summaries = SummaryAvailability.unavailable,
    this.summarizingId,
    this.progress,
    this.errorMessage,
    this.query = '',
    this.results = const [],
    this.activeEntry,
    this.jump,
  });

  final List<Meeting> meetings;
  final int? selectedId;
  final SummaryAvailability summaries;

  /// Qual reunião está sendo resumida agora, se alguma.
  final int? summarizingId;

  /// "bloco 2 de 4" — o resumo de um texto longo acontece em partes, e mostrar
  /// isso é melhor que uma ampulheta girando por um minuto.
  final (int, int)? progress;

  final String? errorMessage;

  /// O que está escrito na busca. Vazio, a lista é a de sempre.
  final String query;

  /// As reuniões que casaram com [query], da melhor para a pior.
  final List<MeetingSearchResult> results;

  /// Qual das [entries] o teclado está apontando.
  final int? activeEntry;

  /// O último pedido de ir até um trecho — ver [EchoJump].
  final EchoJump? jump;

  /// A busca está de pé: a tela mostra resultados no lugar da lista, e a
  /// leitura grifa o que foi buscado.
  ///
  /// Pelo que a busca entende, e não pelo que está escrito: uma letra solta
  /// ainda não é busca (ver [MeetingQuery.parse]), e a lista de sempre fica
  /// até a segunda.
  bool get isSearching => !MeetingQuery.parse(query).isEmpty;

  /// Os resultados como o teclado os percorre: cada reunião, seguida dos
  /// trechos dela.
  List<EchoSearchEntry> get entries => [
    for (final result in results) ...[
      EchoSearchEntry(result),
      for (final hit in result.hits) EchoSearchEntry(result, hit),
    ],
  ];

  Meeting? get selected {
    final id = selectedId;
    if (id == null) return null;

    for (final meeting in meetings) {
      if (meeting.id == id) return meeting;
    }
    return null;
  }

  bool get isEmpty => meetings.isEmpty;

  EchoLibraryState copyWith({
    List<Meeting>? meetings,
    int? selectedId,
    SummaryAvailability? summaries,
    int? summarizingId,
    (int, int)? progress,
    String? errorMessage,
    String? query,
    List<MeetingSearchResult>? results,
    int? activeEntry,
    EchoJump? jump,
    bool clearSelection = false,
    bool clearSummarizing = false,
    bool clearError = false,
    bool clearActiveEntry = false,
    bool clearJump = false,
  }) {
    return EchoLibraryState(
      meetings: meetings ?? this.meetings,
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      summaries: summaries ?? this.summaries,
      summarizingId: clearSummarizing
          ? null
          : (summarizingId ?? this.summarizingId),
      progress: clearSummarizing ? null : (progress ?? this.progress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      query: query ?? this.query,
      results: results ?? this.results,
      activeEntry: clearActiveEntry ? null : (activeEntry ?? this.activeEntry),
      jump: clearJump ? null : (jump ?? this.jump),
    );
  }
}

/// A biblioteca de reuniões, no Hub.
///
/// É aqui que a transcrição é lida e o resumo é pedido — o painel flutuante só
/// grava. Texto de meia hora de reunião não cabe num painel estreito, e o
/// histórico das reuniões passadas menos ainda.
///
/// **Pedir o resumo não é fazer o resumo.** Quem escreve é o
/// [EchoSummaryRunner] da janela 0, que sobrevive a esta janela ser fechada;
/// esta ViewModel manda começar e depois pergunta como vai. Enquanto o
/// trabalho corria aqui, fechar o Hub no meio dele matava o engine e o resumo
/// junto — a reunião voltava sem resumo e sem nada explicando por quê.
class EchoLibraryViewModel extends Notifier<EchoLibraryState> {
  /// De quanto em quanto tempo se pergunta ao fundo como vai o resumo.
  ///
  /// Um bloco leva segundos, então meio segundo de atraso na contagem não é
  /// perceptível — e é uma pergunta barata, feita só enquanto há trabalho.
  static const _pollInterval = Duration(milliseconds: 500);

  late final EchoRepository _repository;
  late final EchoChannel _channel;
  late final EchoSummaryRunner _runner;
  late final ExportService _exports;

  Timer? _poll;

  /// O índice da busca e as reuniões de que ele foi feito.
  ///
  /// Refeito só quando a lista muda de verdade — renomear, apagar, um resumo
  /// novo —, nunca a cada tecla: dobrar horas de conversa a cada letra
  /// digitada é o que faria a busca engasgar.
  MeetingSearch? _index;
  List<Meeting>? _indexedMeetings;
  String? _indexedUserName;

  var _jumpSerial = 0;

  @override
  EchoLibraryState build() {
    _repository = ref.watch(echoRepositoryProvider);
    _channel = ref.watch(echoChannelProvider);
    _runner = ref.watch(echoSummaryRunnerProvider);
    _exports = ref.watch(exportServiceProvider);

    ref.onDispose(() => _poll?.cancel());

    return const EchoLibraryState();
  }

  Future<void> load() async {
    final meetings = _repository.loadAll();

    var summaries = state.summaries;
    try {
      summaries = (await _channel.capabilities()).summaries;
    } on EchoException {
      summaries = SummaryAvailability.unavailable;
    }

    state = state.copyWith(
      meetings: meetings,
      summaries: summaries,
      selectedId: state.selectedId ?? meetings.firstOrNull?.id,
      clearError: true,
    );
    _refreshSearch();

    // Pode haver um resumo correndo desde antes desta janela abrir — pedido e
    // deixado para trás. É aqui que a tela o reencontra, com a contagem de
    // blocos no ponto em que ela está.
    await _syncSummary();
  }

  /// Escolhe a reunião pela lista — e esquece o último salto da busca.
  ///
  /// O salto é de um gesto só. Sobrando no estado, abrir a mesma reunião pela
  /// lista depois levaria a leitura de volta ao trecho de uma busca que a
  /// pessoa já largou.
  void select(int id) =>
      state = state.copyWith(selectedId: id, clearJump: true);

  /// Busca em todas as reuniões de uma vez, a cada tecla.
  ///
  /// O primeiro resultado já nasce apontado: o Enter logo depois de digitar
  /// abre a melhor resposta, como no Spotlight.
  void search(String query) {
    final results = MeetingQuery.parse(query).isEmpty
        ? const <MeetingSearchResult>[]
        : _searchIndex().search(query);

    state = state.copyWith(
      query: query,
      results: results,
      activeEntry: results.isEmpty ? null : 0,
      clearActiveEntry: results.isEmpty,
    );
  }

  void clearSearch() => search('');

  /// Anda [delta] linhas pelos resultados, sem dar a volta: a lista tem fim,
  /// e a seta que pula do último para o primeiro faz perder o lugar.
  void moveActive(int delta) {
    final count = state.entries.length;
    if (count == 0) return;

    final current = state.activeEntry ?? 0;
    state = state.copyWith(activeEntry: (current + delta).clamp(0, count - 1));
  }

  /// Abre o resultado [index] — ou o apontado, sem índice.
  ///
  /// Abrir é escolher a reunião **e** pedir à leitura que vá até o trecho:
  /// a face certa, a fala certa, o áudio parado no ponto em que a palavra
  /// soa. A linha da própria reunião leva ao melhor trecho dela. Devolve se
  /// havia o que abrir — quem chama abre a região só nesse caso.
  bool openEntry([int? index]) {
    final entries = state.entries;
    final at = index ?? state.activeEntry;
    if (at == null || at < 0 || at >= entries.length) return false;

    final entry = entries[at];
    final id = entry.result.meeting.id;
    if (id == null) return false;

    final hit = entry.hit ?? entry.result.hits.firstOrNull;

    state = state.copyWith(
      selectedId: id,
      activeEntry: at,
      jump: EchoJump(
        serial: ++_jumpSerial,
        meetingId: id,
        kind: hit?.kind,
        atMs: hit?.atMs,
        turnStartMs: hit?.turnStartMs,
      ),
    );
    return true;
  }

  MeetingSearch _searchIndex() {
    final meetings = state.meetings;
    final userName = _userName;

    if (_index == null ||
        !identical(_indexedMeetings, meetings) ||
        _indexedUserName != userName) {
      _index = MeetingSearch.index(meetings, userName: userName);
      _indexedMeetings = meetings;
      _indexedUserName = userName;
    }

    return _index!;
  }

  /// Refaz a busca de pé sobre a lista nova — a reunião renomeada, apagada ou
  /// recém-resumida muda o que casa, e um resultado apontando para uma
  /// reunião que já não existe abriria o nada.
  void _refreshSearch() {
    if (!state.isSearching) return;

    final results = _searchIndex().search(state.query);
    final count = [
      for (final result in results) 1 + result.hits.length,
    ].fold(0, (sum, rows) => sum + rows);
    final active = state.activeEntry;

    state = state.copyWith(
      results: results,
      activeEntry: active == null || count == 0
          ? null
          : active.clamp(0, count - 1),
      clearActiveEntry: active == null || count == 0,
    );
  }

  /// Dá nome à reunião. Vazio devolve o nome com que ela nasceu — a data e a
  /// hora —, que é o jeito de desfazer um nome sem ter de lembrá-lo.
  void rename(int id, String title) {
    final meeting = _repository.findById(id);
    if (meeting == null) return;

    final trimmed = title.trim();
    final next = trimmed.isEmpty
        ? Meeting.defaultTitle(meeting.startedAt)
        : trimmed;
    if (next == meeting.title) return;

    _repository.setTitle(id, next);
    state = state.copyWith(meetings: _repository.loadAll());
    _refreshSearch();
  }

  void toggleKept(int id) {
    final meeting = _repository.findById(id);
    if (meeting == null) return;

    _repository.setKept(id, isKept: !meeting.isKept);
    state = state.copyWith(meetings: _repository.loadAll());
    _refreshSearch();
  }

  void delete(int id) {
    _repository.delete(id);

    final meetings = _repository.loadAll();
    final stillThere = meetings.any(
      (meeting) => meeting.id == state.selectedId,
    );

    state = state.copyWith(
      meetings: meetings,
      selectedId: stillThere ? state.selectedId : meetings.firstOrNull?.id,
      clearSelection: !stillThere && meetings.isEmpty,
    );
    _refreshSearch();
  }

  /// Apaga tudo o que não está guardado. O áudio sai na varredura seguinte do
  /// `EchoAudioJanitor`, como em qualquer outro jeito de apagar a reunião.
  void clear() {
    _repository.clearAll();

    final meetings = _repository.loadAll();
    final stillThere = meetings.any(
      (meeting) => meeting.id == state.selectedId,
    );

    state = state.copyWith(meetings: meetings, clearSelection: !stillThere);
    _refreshSearch();
  }

  /// Põe na área de transferência a face aberta da reunião.
  ///
  /// Devolve a frase de confirmação que a tela mostra por um instante, ou
  /// `null` quando não havia o que copiar — resumo que ainda não foi feito,
  /// reunião em que nenhuma fala foi reconhecida. O botão já não é oferecido
  /// nesses casos; o `null` é o cinto, para o caminho do teclado.
  ///
  /// **O que vai é o que está na tela**, não a transcrição crua que vai ao
  /// modelo: quem copia está levando o texto para um e-mail, e lá ele precisa
  /// estar em turnos, como se lê. Ver [MeetingDocument].
  Future<String?> copy(int id, MeetingDocumentKind kind) async {
    final text = _documentBody(id, kind);
    if (text == null) return null;

    await Clipboard.setData(ClipboardData(text: text));

    return kind.copiedLabel;
  }

  /// Escreve a face aberta num arquivo e o mostra no Finder.
  ///
  /// Devolve a confirmação que a tela mostra por um instante. O nome do
  /// arquivo não entra nela: quem o mostra é a janela do Finder que acabou de
  /// abrir com ele selecionado, e repeti-lo numa linha de 140px só o cortaria
  /// no meio. Falhar em escrever vira aviso de erro no lugar de sempre
  /// ([EchoLibraryState.errorMessage]), e não uma confirmação silenciosa de
  /// algo que não aconteceu.
  Future<String?> export(int id, MeetingDocumentKind kind) async {
    final meeting = _meetingById(id);
    if (meeting == null) return null;

    final content = MeetingDocument.file(meeting, kind, userName: _userName);
    if (content == null) return null;

    try {
      await _exports.write(
        baseName: MeetingDocument.fileName(meeting, kind),
        content: content,
      );

      state = state.copyWith(clearError: true);

      return kind.exportedLabel;
    } on Object catch (error) {
      state = state.copyWith(errorMessage: 'Não foi possível exportar: $error');
      return null;
    }
  }

  String? _documentBody(int id, MeetingDocumentKind kind) {
    final meeting = _meetingById(id);
    if (meeting == null) return null;

    return MeetingDocument.body(meeting, kind, userName: _userName);
  }

  Meeting? _meetingById(int id) {
    for (final meeting in state.meetings) {
      if (meeting.id == id) return meeting;
    }
    return null;
  }

  /// Como chamar quem falou pelo microfone, para a transcrição que sai daqui
  /// dizer o mesmo que a que está na tela.
  String get _userName => ref.read(appSettingsViewModelProvider).userName;

  /// Manda resumir a reunião — e volta assim que o pedido foi aceito.
  ///
  /// O resultado não chega por aqui: ele é gravado no banco pelo runner, e esta
  /// tela o descobre no [_syncSummary] seguinte. É o que permite fechar o Hub
  /// no meio e encontrar o resumo pronto na volta.
  Future<void> summarize(int id) async {
    if (state.summarizingId != null) return;

    try {
      await _runner.start(id);
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return;
    }

    await _syncSummary();
  }

  /// Desiste do resumo em curso.
  ///
  /// O `_syncSummary` no fim é o que devolve a tela ao estado parado sem
  /// esperar meio segundo pela pergunta periódica seguinte — e é ele, e não
  /// este método, quem decide o que mostrar: a verdade continua sendo a do
  /// runner. Ver [EchoSummaryRunner.cancel] para o que "cancelar" alcança.
  Future<void> cancelSummary() async {
    if (state.summarizingId == null) return;

    try {
      await _runner.cancel();
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return;
    }

    await _syncSummary();
  }

  /// Copia para a tela o que o runner está fazendo, e liga (ou desliga) a
  /// pergunta periódica conforme houver trabalho.
  Future<void> _syncSummary() async {
    final wasRunning = state.summarizingId != null;
    final EchoSummaryStatus status;

    try {
      status = await _runner.status();
    } on EchoException catch (error) {
      _stopPolling();

      // A tela volta a mostrar o que o banco tem — o resumo pode ter ficado
      // pronto, e é a única resposta honesta quando não dá mais para perguntar.
      // O aviso só aparece se havia trabalho sendo acompanhado: perder o canal
      // com nada em curso não é assunto de quem só abriu a janela.
      state = state.copyWith(
        meetings: _repository.loadAll(),
        clearSummarizing: true,
        errorMessage: wasRunning ? error.message : null,
        clearError: !wasRunning,
      );
      _refreshSearch();
      return;
    }

    state = state.copyWith(
      // O trabalho acabou desde a última pergunta: a lista é relida para que o
      // resumo recém-gravado apareça. Só nessa transição — reler a cada meio
      // segundo seria consultar o banco por nada.
      meetings: wasRunning && !status.isRunning ? _repository.loadAll() : null,
      summarizingId: status.meetingId,
      progress: status.isRunning ? (status.done, status.total) : null,
      clearSummarizing: !status.isRunning,
      errorMessage: status.errorMessage,
      clearError: status.errorMessage == null,
    );
    if (wasRunning && !status.isRunning) _refreshSearch();

    if (status.isRunning) {
      _poll ??= Timer.periodic(_pollInterval, (_) => _syncSummary());
      return;
    }

    _stopPolling();
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }
}

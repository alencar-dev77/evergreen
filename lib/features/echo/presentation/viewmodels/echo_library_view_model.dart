import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/echo_channel.dart';
import '../../data/echo_repository.dart';
import '../../data/echo_settings_repository.dart';
import '../../models/echo_capabilities.dart';
import '../../models/meeting.dart';
import '../../models/summary_chunker.dart';

final echoLibraryViewModelProvider =
    NotifierProvider<EchoLibraryViewModel, EchoLibraryState>(
      EchoLibraryViewModel.new,
    );

class EchoLibraryState {
  const EchoLibraryState({
    this.meetings = const [],
    this.selectedId,
    this.summaries = SummaryAvailability.unavailable,
    this.summarizingId,
    this.progress,
    this.errorMessage,
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
    bool clearSelection = false,
    bool clearSummarizing = false,
    bool clearError = false,
  }) {
    return EchoLibraryState(
      meetings: meetings ?? this.meetings,
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      summaries: summaries ?? this.summaries,
      summarizingId: clearSummarizing ? null : (summarizingId ?? this.summarizingId),
      progress: clearSummarizing ? null : (progress ?? this.progress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// A biblioteca de reuniões, no Hub.
///
/// É aqui que a transcrição é lida e o resumo é pedido — o painel flutuante só
/// grava. Texto de meia hora de reunião não cabe num painel estreito, e o
/// histórico das reuniões passadas menos ainda.
class EchoLibraryViewModel extends Notifier<EchoLibraryState> {
  /// Instrução dos resumos de bloco.
  ///
  /// Fixa e neutra de propósito: os blocos são matéria-prima, não resposta. Se
  /// o formato pedido pela pessoa fosse aplicado aqui, o passo final receberia
  /// tópicos de tópicos e perderia o material bruto de que precisa para
  /// organizar. Bloco preserva fato; o formato entra só no fim.
  static const _blockInstructions =
      'Resuma este trecho de reunião preservando fatos, decisões, números e '
      'nomes próprios. Escreva em texto corrido, sem formatação. Não invente '
      'nada que não esteja no trecho.';

  late final EchoRepository _repository;
  late final EchoSettingsRepository _settings;
  late final EchoChannel _channel;

  @override
  EchoLibraryState build() {
    _repository = ref.watch(echoRepositoryProvider);
    _settings = ref.watch(echoSettingsRepositoryProvider);
    _channel = ref.watch(echoChannelProvider);

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
  }

  void select(int id) => state = state.copyWith(selectedId: id);

  void rename(int id, String title) {
    _repository.setTitle(id, title);
    state = state.copyWith(meetings: _repository.loadAll());
  }

  void toggleKept(int id) {
    final meeting = _repository.findById(id);
    if (meeting == null) return;

    _repository.setKept(id, isKept: !meeting.isKept);
    state = state.copyWith(meetings: _repository.loadAll());
  }

  void delete(int id) {
    _repository.delete(id);

    final meetings = _repository.loadAll();
    final stillThere = meetings.any((meeting) => meeting.id == state.selectedId);

    state = state.copyWith(
      meetings: meetings,
      selectedId: stillThere ? state.selectedId : meetings.firstOrNull?.id,
      clearSelection: !stillThere && meetings.isEmpty,
    );
  }

  /// Resume a reunião selecionada com o modelo local.
  ///
  /// Em dois passos quando o texto não cabe de uma vez: cada bloco vira um
  /// resumo neutro, e o passo final junta os resumos aplicando a instrução que
  /// a pessoa escreveu nas preferências. Com um bloco só, o passo final é o
  /// único que existe.
  Future<void> summarize(int id) async {
    if (state.summarizingId != null) return;

    final meeting = _repository.findById(id);
    if (meeting == null || meeting.isEmpty) return;

    // A instrução mora no Hub, mas pode ter sido editada em outra janela desde
    // que esta tela abriu.
    await _settings.reload();
    final instructions = _settings.load().summaryInstructions.trim();

    final chunks = SummaryChunker.chunk(meeting.plainText);
    if (chunks.isEmpty) return;

    state = state.copyWith(
      summarizingId: id,
      progress: (0, chunks.length),
      clearError: true,
    );

    try {
      final summary = chunks.length == 1
          ? await _summarize(chunks.single, instructions)
          : await _summarizeInBlocks(chunks, instructions);

      _repository.setSummary(id, summary);
      state = state.copyWith(
        meetings: _repository.loadAll(),
        clearSummarizing: true,
      );
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message, clearSummarizing: true);
    }
  }

  Future<String> _summarizeInBlocks(List<String> chunks, String instructions) async {
    final partials = <String>[];

    for (var index = 0; index < chunks.length; index++) {
      state = state.copyWith(progress: (index + 1, chunks.length));
      partials.add(await _summarize(chunks[index], _blockInstructions));
    }

    return _summarize(partials.join('\n\n'), instructions);
  }

  /// Uma chamada ao modelo, com a saída para o texto que não coube.
  ///
  /// O estouro de janela é o único erro que dá para resolver aqui: repartir o
  /// bloco ao meio e resumir as metades chega no mesmo lugar, só mais devagar.
  Future<String> _summarize(String text, String instructions) async {
    try {
      return await _channel.summarize(text: text, instructions: instructions);
    } on EchoException catch (error) {
      if (!error.isContextWindowExceeded || text.length < 500) rethrow;

      final halves = SummaryChunker.chunk(text, maxChars: text.length ~/ 2);
      final partials = <String>[];
      for (final half in halves) {
        partials.add(await _summarize(half, _blockInstructions));
      }

      return _summarize(partials.join('\n\n'), instructions);
    }
  }
}

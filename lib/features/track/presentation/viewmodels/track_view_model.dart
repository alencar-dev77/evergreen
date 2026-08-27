import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/utils/day_bounds.dart';
import '../../data/track_repository.dart';
import '../../data/track_summarizer.dart';
import '../../data/track_summary_cache.dart';
import '../../models/track_day.dart';
import '../../models/track_range.dart';

/// O parágrafo de um dia, e em que pé ele está.
///
/// Três situações, e a tela desenha coisa diferente em cada uma: escrevendo
/// (uma linha discreta dizendo isso), escrito (o parágrafo) e indisponível
/// (nada — nem aviso, nem espaço reservado).
@immutable
class TrackSummary {
  const TrackSummary._(this.text, this.signature, {required this.isWriting});

  const TrackSummary.writing(String signature)
      : this._(null, signature, isWriting: true);

  const TrackSummary.written(String text, String signature)
      : this._(text, signature, isWriting: false);

  const TrackSummary.unavailable(String signature)
      : this._(null, signature, isWriting: false);

  final String? text;
  final bool isWriting;

  /// A assinatura do dia no momento em que este parágrafo foi pedido — ver
  /// `TrackDay.signature`. É o que faz um resumo envelhecido ser descartado em
  /// vez de continuar na tela contradizendo os números ao lado.
  final String signature;

  bool get hasText => text != null;
}

/// O que a tela do Track mostra.
@immutable
class TrackState {
  const TrackState({
    required this.range,
    required this.days,
    this.selectedDate,
    this.summaries = const {},
  });

  final TrackRange range;

  /// Os dias do recorte, do mais recente para o mais antigo.
  final List<TrackDay> days;

  /// O dia aberto na região de leitura do Hub, se houver.
  ///
  /// Guardado por data, e não como objeto: a lista é relida do banco a cada
  /// [TrackViewModel.refresh], e um objeto guardado aqui envelheceria em
  /// silêncio enquanto a lista ao lado já mostra os números novos.
  final DateTime? selectedDate;

  /// O parágrafo de cada dia que já foi aberto uma vez.
  final Map<DateTime, TrackSummary> summaries;

  TrackTotals get totals => TrackTotals.of(days);

  bool get isEmpty => days.every((day) => day.isEmpty);

  /// O dia aberto, ou `null` quando nenhum está — inclusive quando o que
  /// estava aberto saiu do recorte.
  TrackDay? get selected {
    if (selectedDate == null) return null;

    for (final day in days) {
      if (day.date == selectedDate) return day;
    }

    return null;
  }

  /// O parágrafo do dia aberto.
  TrackSummary get selectedSummary =>
      summaries[selectedDate] ?? const TrackSummary.unavailable('');

  TrackState copyWith({
    TrackRange? range,
    List<TrackDay>? days,
    DateTime? selectedDate,
    bool clearSelection = false,
    Map<DateTime, TrackSummary>? summaries,
  }) {
    return TrackState(
      range: range ?? this.range,
      days: days ?? this.days,
      selectedDate: clearSelection ? null : selectedDate ?? this.selectedDate,
      summaries: summaries ?? this.summaries,
    );
  }
}

final trackViewModelProvider = NotifierProvider<TrackViewModel, TrackState>(
  TrackViewModel.new,
);

/// O dia reconstruído, lido sob demanda.
///
/// Como o Focus e o Echo, o Track roda no engine do Hub e lê tabelas que os
/// outros módulos escrevem no engine da janela flutuante: nada aqui é avisado
/// de nada, e por isso a tela pede [refresh] ao ser montada.
class TrackViewModel extends Notifier<TrackState> {
  late final TrackRepository _repository;
  late final TrackSummarizer _summarizer;
  late final TrackSummaryCache _cache;
  late final DateTime Function() _now;

  @override
  TrackState build() {
    _repository = ref.watch(trackRepositoryProvider);
    _summarizer = ref.watch(trackSummarizerProvider);
    _cache = ref.watch(trackSummaryCacheProvider);
    _now = ref.watch(clockProvider);

    // A semana, e não o dia, é o que abre a tela: com "Hoje" a lista teria uma
    // linha só, e o valor do módulo é justamente ver a sexta-feira ao lado da
    // segunda. "Hoje" continua sendo a primeira linha da lista.
    return _read(TrackRange.week);
  }

  void refresh() => state = _read(
        state.range,
        selectedDate: state.selectedDate,
        summaries: state.summaries,
      );

  void setRange(TrackRange range) {
    if (range == state.range) return;

    // A seleção sobrevive à troca de recorte quando o dia continua na lista —
    // trocar para "Hoje" com o dia de hoje aberto ao lado não pode fechar a
    // região que a pessoa acabou de abrir.
    state = _read(
      range,
      selectedDate: state.selectedDate,
      summaries: state.summaries,
    );
  }

  /// Escolhe o dia que a região de leitura mostra, e manda escrever o
  /// parágrafo dele se ainda não houver um.
  void select(DateTime date) {
    state = state.copyWith(selectedDate: date);

    final day = state.selected;
    if (day == null) return;
    if (state.summaries.containsKey(date)) return;

    unawaited(_write(day));
  }

  void closeSelection() => state = state.copyWith(clearSelection: true);

  /// Pede o parágrafo ao modelo e guarda o resultado.
  ///
  /// O texto que sai daqui fica no cache (ver [TrackSummaryCache]): um dia que
  /// já passou não muda mais, e o Hub abre e fecha dezenas de vezes por dia —
  /// reabrir ontem não pode custar uma escrita nova do modelo toda vez.
  Future<void> _write(TrackDay day) async {
    final signature = day.signature;
    _setSummary(day.date, TrackSummary.writing(signature));

    final text = await _summarizer.write(day);
    // A tela pode ter trocado de recorte — ou a janela ter fechado — enquanto o
    // modelo escrevia.
    if (!ref.mounted) return;

    _setSummary(
      day.date,
      text == null
          ? TrackSummary.unavailable(signature)
          : TrackSummary.written(text, signature),
    );

    // Só o que deu certo é guardado: "o modelo não estava disponível" é uma
    // condição da máquina naquele instante, não um fato sobre o dia, e guardá-la
    // faria a tela desistir de tentar de novo na próxima abertura.
    if (text != null) unawaited(_cache.write(day.date, signature, text));
  }

  void _setSummary(DateTime date, TrackSummary summary) {
    state = state.copyWith(
      summaries: {...state.summaries, date: summary},
    );
  }

  TrackState _read(
    TrackRange range, {
    DateTime? selectedDate,
    Map<DateTime, TrackSummary> summaries = const {},
  }) {
    final now = _now();
    final today = DayBounds.startOfDay(now);
    final days = _repository.loadDays(since: range.since(now));

    // Hoje entra sempre, mesmo sem nada registrado: é a linha que a pessoa vem
    // procurar, e uma lista que começa em "Ontem" às dez da manhã parece um
    // módulo quebrado. Os outros dias vazios ficam de fora — uma quarta-feira
    // de folga não precisa de linha para dizer que foi folga.
    if (days.every((day) => day.date != today)) {
      days.insert(0, TrackDay(date: today));
    }

    return TrackState(
      range: range,
      days: List.unmodifiable(days),
      selectedDate: days.any((day) => day.date == selectedDate)
          ? selectedDate
          : null,
      summaries: _restored(_pruneSummaries(summaries, days), days),
    );
  }

  /// Traz de volta os parágrafos que já foram escritos numa sessão anterior.
  ///
  /// O que está em memória manda: um resumo sendo escrito agora não pode ser
  /// atropelado pela versão guardada. O cache responde pelo resto — e responde
  /// `null` sozinho quando o dia mudou desde que aquele texto foi escrito.
  Map<DateTime, TrackSummary> _restored(
    Map<DateTime, TrackSummary> summaries,
    List<TrackDay> days,
  ) {
    final restored = {...summaries};

    for (final day in days) {
      if (restored.containsKey(day.date)) continue;

      final text = _cache.read(day.date, day.signature);
      if (text == null) continue;

      restored[day.date] = TrackSummary.written(text, day.signature);
    }

    return restored;
  }

  /// Descarta o parágrafo de um dia que mudou desde que ele foi escrito.
  ///
  /// Um resumo que diz "três sessões" ao lado de uma lista com quatro é pior
  /// que resumo nenhum — e é exatamente o que acontece quando uma sessão é
  /// registrada com o Hub aberto.
  static Map<DateTime, TrackSummary> _pruneSummaries(
    Map<DateTime, TrackSummary> summaries,
    List<TrackDay> days,
  ) {
    if (summaries.isEmpty) return summaries;

    final signatures = {for (final day in days) day.date: day.signature};

    return {
      for (final entry in summaries.entries)
        if (signatures[entry.key] == entry.value.signature)
          entry.key: entry.value,
    };
  }
}

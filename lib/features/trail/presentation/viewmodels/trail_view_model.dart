import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/utils/day_bounds.dart';
import '../../data/trail_repository.dart';
import '../../data/trail_summarizer.dart';
import '../../models/trail_day.dart';
import '../../models/trail_range.dart';

/// O parágrafo de um dia, e em que pé ele está.
///
/// Três situações, e a tela desenha coisa diferente em cada uma: escrevendo
/// (uma linha discreta dizendo isso), escrito (o parágrafo) e indisponível
/// (nada — nem aviso, nem espaço reservado).
@immutable
class TrailSummary {
  const TrailSummary._(this.text, this.signature, {required this.isWriting});

  const TrailSummary.writing(String signature)
      : this._(null, signature, isWriting: true);

  const TrailSummary.written(String text, String signature)
      : this._(text, signature, isWriting: false);

  const TrailSummary.unavailable(String signature)
      : this._(null, signature, isWriting: false);

  final String? text;
  final bool isWriting;

  /// A assinatura do dia no momento em que este parágrafo foi pedido — ver
  /// `TrailDay.signature`. É o que faz um resumo envelhecido ser descartado em
  /// vez de continuar na tela contradizendo os números ao lado.
  final String signature;

  bool get hasText => text != null;
}

/// O que a tela do Trail mostra.
@immutable
class TrailState {
  const TrailState({
    required this.range,
    required this.days,
    this.selectedDate,
    this.summaries = const {},
  });

  final TrailRange range;

  /// Os dias do recorte, do mais recente para o mais antigo.
  final List<TrailDay> days;

  /// O dia aberto na região de leitura do Hub, se houver.
  ///
  /// Guardado por data, e não como objeto: a lista é relida do banco a cada
  /// [TrailViewModel.refresh], e um objeto guardado aqui envelheceria em
  /// silêncio enquanto a lista ao lado já mostra os números novos.
  final DateTime? selectedDate;

  /// O parágrafo de cada dia que já foi aberto uma vez.
  final Map<DateTime, TrailSummary> summaries;

  TrailTotals get totals => TrailTotals.of(days);

  bool get isEmpty => days.every((day) => day.isEmpty);

  /// O dia aberto, ou `null` quando nenhum está — inclusive quando o que
  /// estava aberto saiu do recorte.
  TrailDay? get selected {
    if (selectedDate == null) return null;

    for (final day in days) {
      if (day.date == selectedDate) return day;
    }

    return null;
  }

  /// O parágrafo do dia aberto.
  TrailSummary get selectedSummary =>
      summaries[selectedDate] ?? const TrailSummary.unavailable('');

  TrailState copyWith({
    TrailRange? range,
    List<TrailDay>? days,
    DateTime? selectedDate,
    bool clearSelection = false,
    Map<DateTime, TrailSummary>? summaries,
  }) {
    return TrailState(
      range: range ?? this.range,
      days: days ?? this.days,
      selectedDate: clearSelection ? null : selectedDate ?? this.selectedDate,
      summaries: summaries ?? this.summaries,
    );
  }
}

final trailViewModelProvider = NotifierProvider<TrailViewModel, TrailState>(
  TrailViewModel.new,
);

/// O dia reconstruído, lido sob demanda.
///
/// Como o Focus e o Echo, o Trail roda no engine do Hub e lê tabelas que os
/// outros módulos escrevem no engine da janela flutuante: nada aqui é avisado
/// de nada, e por isso a tela pede [refresh] ao ser montada.
class TrailViewModel extends Notifier<TrailState> {
  late final TrailRepository _repository;
  late final TrailSummarizer _summarizer;
  late final DateTime Function() _now;

  @override
  TrailState build() {
    _repository = ref.watch(trailRepositoryProvider);
    _summarizer = ref.watch(trailSummarizerProvider);
    _now = ref.watch(clockProvider);

    // A semana, e não o dia, é o que abre a tela: com "Hoje" a lista teria uma
    // linha só, e o valor do módulo é justamente ver a sexta-feira ao lado da
    // segunda. "Hoje" continua sendo a primeira linha da lista.
    return _read(TrailRange.week);
  }

  void refresh() => state = _read(
        state.range,
        selectedDate: state.selectedDate,
        summaries: state.summaries,
      );

  void setRange(TrailRange range) {
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
  /// O resultado fica em memória e some ao fechar a janela: o Trail não cria
  /// tabela nenhuma, e um parágrafo gerado por um modelo local se refaz em
  /// segundos.
  Future<void> _write(TrailDay day) async {
    final signature = day.signature;
    _setSummary(day.date, TrailSummary.writing(signature));

    final text = await _summarizer.write(day);
    // A tela pode ter trocado de recorte — ou a janela ter fechado — enquanto o
    // modelo escrevia.
    if (!ref.mounted) return;

    _setSummary(
      day.date,
      text == null
          ? TrailSummary.unavailable(signature)
          : TrailSummary.written(text, signature),
    );
  }

  void _setSummary(DateTime date, TrailSummary summary) {
    state = state.copyWith(
      summaries: {...state.summaries, date: summary},
    );
  }

  TrailState _read(
    TrailRange range, {
    DateTime? selectedDate,
    Map<DateTime, TrailSummary> summaries = const {},
  }) {
    final now = _now();
    final today = DayBounds.startOfDay(now);
    final days = _repository.loadDays(since: range.since(now));

    // Hoje entra sempre, mesmo sem nada registrado: é a linha que a pessoa vem
    // procurar, e uma lista que começa em "Ontem" às dez da manhã parece um
    // módulo quebrado. Os outros dias vazios ficam de fora — uma quarta-feira
    // de folga não precisa de linha para dizer que foi folga.
    if (days.every((day) => day.date != today)) {
      days.insert(0, TrailDay(date: today));
    }

    return TrailState(
      range: range,
      days: List.unmodifiable(days),
      selectedDate: days.any((day) => day.date == selectedDate)
          ? selectedDate
          : null,
      summaries: _pruneSummaries(summaries, days),
    );
  }

  /// Descarta o parágrafo de um dia que mudou desde que ele foi escrito.
  ///
  /// Um resumo que diz "três sessões" ao lado de uma lista com quatro é pior
  /// que resumo nenhum — e é exatamente o que acontece quando uma sessão é
  /// registrada com o Hub aberto.
  static Map<DateTime, TrailSummary> _pruneSummaries(
    Map<DateTime, TrailSummary> summaries,
    List<TrailDay> days,
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

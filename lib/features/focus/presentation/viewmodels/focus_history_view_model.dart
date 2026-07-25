import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/focus_session_repository.dart';
import '../../models/focus_session.dart';

/// O que a tela do Focus no Hub mostra sobre o passado: os dois totais e as
/// sessões da semana.
@immutable
class FocusHistoryState {
  const FocusHistoryState({required this.sessions, required this.stats});

  final List<FocusSession> sessions;
  final FocusStats stats;

  bool get isEmpty => sessions.isEmpty;
}

final focusHistoryViewModelProvider =
    NotifierProvider<FocusHistoryViewModel, FocusHistoryState>(
  FocusHistoryViewModel.new,
);

/// Histórico e resumo do Focus, lidos sob demanda.
///
/// O Hub roda em um engine separado do cronômetro: uma sessão registrada
/// enquanto esta janela estava aberta não chega aqui sozinha. Por isso a tela
/// pede [refresh] ao ser montada, em vez de assinar um fluxo que não existe
/// entre engines.
class FocusHistoryViewModel extends Notifier<FocusHistoryState> {
  late final FocusSessionRepository _repository;
  late final DateTime Function() _now;

  /// Histórico "simples": as sessões da semana, sem paginação. Quem quiser
  /// análise longa não vai encontrá-la aqui de propósito.
  static const _limit = 50;

  @override
  FocusHistoryState build() {
    _repository = ref.watch(focusSessionRepositoryProvider);
    _now = ref.watch(clockProvider);
    return _read();
  }

  void refresh() => state = _read();

  /// Apaga uma sessão só — o oposto de "limpar histórico", que leva a semana
  /// inteira.
  void delete(FocusSession session) {
    final id = session.id;
    if (id == null) return;

    _repository.delete(id);
    refresh();
  }

  void clear() {
    _repository.clearAll();
    refresh();
  }

  /// Toda leitura começa apagando o que é de semanas anteriores — é aqui que a
  /// virada de segunda-feira acontece, sem tarefa agendada nem serviço extra.
  FocusHistoryState _read() {
    final now = _now();
    _repository.trimToCurrentWeek(now: now);

    return FocusHistoryState(
      sessions: _repository.loadRecent(limit: _limit, now: now),
      stats: _repository.stats(now: now),
    );
  }
}

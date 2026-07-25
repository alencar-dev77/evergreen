import 'package:flutter/foundation.dart';

import 'focus_session_note.dart';

/// Uma sessão de foco concluída.
///
/// Só entra no histórico o que terminou: sessões encerradas antes do tempo são
/// registradas com o que de fato foi focado, e uma sessão em andamento não
/// existe aqui — ela vive no estado do cronômetro.
@immutable
class FocusSession {
  const FocusSession({
    this.id,
    required this.startedAt,
    required this.duration,
    this.activity,
    this.summary,
    this.notes = const [],
  });

  final int? id;

  /// Quando a sessão começou. É o "horário" mostrado no histórico.
  final DateTime startedAt;

  /// Tempo efetivamente focado, já descontadas as pausas.
  final Duration duration;

  /// O que a pessoa disse que ia fazer, se disse. Texto livre — a integração
  /// com ferramentas de tarefa é assunto de uma versão futura.
  final String? activity;

  /// O que a pessoa disse que fez, se disse.
  final String? summary;

  /// Observações escritas no meio da sessão, na ordem em que foram escritas.
  final List<FocusSessionNote> notes;

  bool get hasActivity => activity != null && activity!.isNotEmpty;
  bool get hasSummary => summary != null && summary!.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;

  FocusSession copyWith({
    int? id,
    DateTime? startedAt,
    Duration? duration,
    String? activity,
    String? summary,
    List<FocusSessionNote>? notes,
  }) {
    return FocusSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      activity: activity ?? this.activity,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
    );
  }
}

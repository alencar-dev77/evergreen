import 'package:flutter/foundation.dart';

import '../../pin/models/clipboard_item_type.dart';

/// Uma coisa que aconteceu numa hora do dia e durou um tempo — uma sessão de
/// foco ou uma reunião gravada.
///
/// Uma forma só para as duas porque a leitura é a mesma: `09:12 · o quê ·
/// quanto`. O que muda entre elas é de qual tabela vieram, e isso é assunto do
/// repositório, não da linha.
@immutable
class TrailEntry {
  const TrailEntry({required this.at, required this.duration, this.label});

  final DateTime at;
  final Duration duration;

  /// O nome que a pessoa deu: a atividade da sessão, o título da reunião.
  /// `null` numa sessão de foco iniciada sem dizer em quê.
  final String? label;

  bool get hasLabel => label != null && label!.trim().isNotEmpty;
}

/// Um dia reconstruído a partir do que os módulos já gravaram.
///
/// O Trail não captura nada: cada campo aqui é a leitura de uma tabela que já
/// existia. E [copied] guarda **contagem por tipo**, nunca o conteúdo — a
/// regra do módulo, porque o Pin registra tudo que passa pela área de
/// transferência, senha colada inclusive.
@immutable
class TrailDay {
  const TrailDay({
    required this.date,
    this.focus = const [],
    this.meetings = const [],
    this.copied = const {},
    this.notesWritten = 0,
  });

  /// Meia-noite local do dia.
  final DateTime date;

  /// Sessões do Focus, da mais recente para a mais antiga.
  final List<TrailEntry> focus;

  /// Reuniões do Echo, da mais recente para a mais antiga.
  final List<TrailEntry> meetings;

  /// Quantos itens de cada tipo passaram pela área de transferência. Só a
  /// contagem — o conteúdo nunca sai do banco.
  final Map<ClipboardItemType, int> copied;

  /// Anotações do Leaf escritas neste dia.
  ///
  /// Escritas, e não "as que estavam na parede": o Leaf não guarda quando uma
  /// anotação saiu, então reconstruir a parede de um dia passado seria chute.
  final int notesWritten;

  Duration get focusTotal =>
      focus.fold(Duration.zero, (total, entry) => total + entry.duration);

  Duration get meetingTotal =>
      meetings.fold(Duration.zero, (total, entry) => total + entry.duration);

  int get copiedTotal =>
      copied.values.fold(0, (total, count) => total + count);

  /// Tempo do dia que ficou registrado em algum lugar — foco mais reunião.
  ///
  /// É a medida do Trail, e não a do Focus: o módulo pergunta "o que eu fiz
  /// hoje", e uma hora de reunião é uma hora de trabalho tanto quanto uma hora
  /// de foco. É o número que a linha do dia mostra à direita e a altura que a
  /// barra da semana desenha.
  Duration get registered => focusTotal + meetingTotal;

  bool get isEmpty =>
      focus.isEmpty &&
      meetings.isEmpty &&
      copiedTotal == 0 &&
      notesWritten == 0;

  /// O que aconteceu no dia, em pedaços curtos — "4 sessões", "2 reuniões".
  ///
  /// Mora no modelo, e não no widget, porque os mesmos pedaços aparecem em três
  /// lugares (a linha da lista, o cabeçalho da região e o texto que vai para o
  /// modelo) e três cópias da mesma pluralização divergiriam na primeira que
  /// alguém corrigisse.
  List<String> get highlights => [
        if (focus.isNotEmpty) TrailCounts.of(focus.length, 'sessão', 'sessões'),
        if (meetings.isNotEmpty)
          TrailCounts.of(meetings.length, 'reunião', 'reuniões'),
        if (copiedTotal > 0)
          TrailCounts.of(copiedTotal, 'item copiado', 'itens copiados'),
        if (notesWritten > 0)
          TrailCounts.of(notesWritten, 'anotação', 'anotações'),
      ];

  /// Assinatura barata do conteúdo do dia.
  ///
  /// Serve para saber se o parágrafo já escrito pelo modelo ainda descreve
  /// este dia: sem ela, uma sessão registrada depois de o resumo ter sido
  /// escrito deixaria na tela um texto que não bate mais com os números ao
  /// lado — e um resumo errado é pior que resumo nenhum.
  String get signature => '${focus.length}/${focusTotal.inMinutes}/'
      '${meetings.length}/${meetingTotal.inMinutes}/'
      '$copiedTotal/$notesWritten';
}

/// Os totais de um período — o que a frase do topo da tela conta.
@immutable
class TrailTotals {
  const TrailTotals({
    required this.focus,
    required this.focusSessions,
    required this.meetings,
    required this.meetingCount,
    required this.copied,
    required this.notesWritten,
  });

  final Duration focus;
  final int focusSessions;
  final Duration meetings;
  final int meetingCount;
  final int copied;
  final int notesWritten;

  static const empty = TrailTotals(
    focus: Duration.zero,
    focusSessions: 0,
    meetings: Duration.zero,
    meetingCount: 0,
    copied: 0,
    notesWritten: 0,
  );

  factory TrailTotals.of(Iterable<TrailDay> days) {
    var focus = Duration.zero;
    var focusSessions = 0;
    var meetings = Duration.zero;
    var meetingCount = 0;
    var copied = 0;
    var notes = 0;

    for (final day in days) {
      focus += day.focusTotal;
      focusSessions += day.focus.length;
      meetings += day.meetingTotal;
      meetingCount += day.meetings.length;
      copied += day.copiedTotal;
      notes += day.notesWritten;
    }

    return TrailTotals(
      focus: focus,
      focusSessions: focusSessions,
      meetings: meetings,
      meetingCount: meetingCount,
      copied: copied,
      notesWritten: notes,
    );
  }

  /// Tempo registrado no período — ver `TrailDay.registered`.
  Duration get registered => focus + meetings;

  bool get isEmpty =>
      focusSessions == 0 &&
      meetingCount == 0 &&
      copied == 0 &&
      notesWritten == 0;
}

/// Contagem com o substantivo no número certo.
abstract final class TrailCounts {
  static String of(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';
}

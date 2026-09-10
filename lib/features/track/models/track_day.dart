import 'package:flutter/foundation.dart';

import '../../../shared/utils/duration_format.dart';
import '../../pin/models/clipboard_item_type.dart';

/// Uma coisa que aconteceu numa hora do dia e durou um tempo — uma sessão de
/// foco ou uma reunião gravada.
///
/// Uma forma só para as duas porque a leitura é a mesma: `09:12 · o quê ·
/// quanto`. O que muda entre elas é de qual tabela vieram, e isso é assunto do
/// repositório, não da linha.
@immutable
class TrackEntry {
  const TrackEntry({
    required this.at,
    required this.duration,
    this.label,
    this.summary,
  });

  final DateTime at;
  final Duration duration;

  /// O nome que a pessoa deu: a atividade da sessão, o título da reunião.
  /// `null` numa sessão de foco iniciada sem dizer em quê.
  final String? label;

  /// O que já foi escrito sobre isto: o resumo que a pessoa digitou ao fechar a
  /// sessão de foco, ou o resumo que o modelo escreveu sobre a reunião.
  ///
  /// **Isto não fura a regra do módulo.** O que o Track não lê é conteúdo do
  /// Pin — porque o Pin registra tudo o que passa pela área de transferência,
  /// senha inclusive, e ninguém escolheu pôr aquilo lá. Um resumo é o oposto:
  /// é texto que a pessoa escreveu de propósito sobre o próprio trabalho, ou
  /// que ela mandou escrever. Sai desta máquina tanto quanto o resto — ou seja,
  /// não sai.
  ///
  /// `null` quase sempre: a maioria das sessões termina sem resumo, e a
  /// reunião só tem um depois de alguém pedir.
  final String? summary;

  bool get hasLabel => label != null && label!.trim().isNotEmpty;

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;
}

/// Um dia reconstruído a partir do que os módulos já gravaram.
///
/// O Track não captura nada: cada campo aqui é a leitura de uma tabela que já
/// existia. E [copied] guarda **contagem por tipo**, nunca o conteúdo — a
/// regra do módulo, porque o Pin registra tudo que passa pela área de
/// transferência, senha colada inclusive.
@immutable
class TrackDay {
  const TrackDay({
    required this.date,
    this.focus = const [],
    this.meetings = const [],
    this.awake = const [],
    this.copied = const {},
    this.notesWritten = 0,
    this.filesOrganized = 0,
  });

  /// Meia-noite local do dia.
  final DateTime date;

  /// Sessões do Focus, da mais recente para a mais antiga.
  final List<TrackEntry> focus;

  /// Reuniões do Echo, da mais recente para a mais antiga.
  final List<TrackEntry> meetings;

  /// Períodos em que o Awake segurou o Mac acordado.
  ///
  /// O rótulo diz o que estava sendo segurado — "Tela acesa" ou "Sistema
  /// acordado" —, que é a única coisa que o módulo tem a contar sobre um
  /// período.
  final List<TrackEntry> awake;

  /// Quantos itens de cada tipo passaram pela área de transferência. Só a
  /// contagem — o conteúdo nunca sai do banco.
  final Map<ClipboardItemType, int> copied;

  /// Arquivos que o Nest mandou para alguma pasta neste dia.
  ///
  /// A contagem, e nada mais: a tabela do módulo não guarda caminho nem nome de
  /// arquivo, pela mesma razão que a do Pin não guarda conteúdo. "12 arquivos
  /// organizados" é o que o dia tem a dizer sobre isso.
  final int filesOrganized;

  /// Anotações do Leaf escritas neste dia.
  ///
  /// Escritas, e não "as que estavam na parede": o Leaf não guarda quando uma
  /// anotação saiu, então reconstruir a parede de um dia passado seria chute.
  final int notesWritten;

  Duration get focusTotal =>
      focus.fold(Duration.zero, (total, entry) => total + entry.duration);

  Duration get meetingTotal =>
      meetings.fold(Duration.zero, (total, entry) => total + entry.duration);

  Duration get awakeTotal =>
      awake.fold(Duration.zero, (total, entry) => total + entry.duration);

  int get copiedTotal => copied.values.fold(0, (total, count) => total + count);

  /// Tempo do dia que ficou registrado em algum lugar — foco mais reunião.
  ///
  /// É a medida do Track, e não a do Focus: o módulo pergunta "o que eu fiz
  /// hoje", e uma hora de reunião é uma hora de trabalho tanto quanto uma hora
  /// de foco. É o número que a linha do dia mostra à direita e a altura que a
  /// barra da semana desenha.
  ///
  /// O Awake fica **de fora** de propósito: a trava não é trabalho, é uma
  /// condição da máquina. Duas horas de tela acesa numa apresentação não são
  /// duas horas de foco, e somá-las inflaria justamente o número que o módulo
  /// existe para responder com honestidade.
  Duration get registered => focusTotal + meetingTotal;

  bool get isEmpty =>
      focus.isEmpty &&
      meetings.isEmpty &&
      awake.isEmpty &&
      copiedTotal == 0 &&
      notesWritten == 0 &&
      filesOrganized == 0;

  /// O que aconteceu no dia, em pedaços curtos — "4 sessões", "2 reuniões".
  ///
  /// Mora no modelo, e não no widget, porque os mesmos pedaços aparecem em três
  /// lugares (a linha da lista, o cabeçalho da região e o texto que vai para o
  /// modelo) e três cópias da mesma pluralização divergiriam na primeira que
  /// alguém corrigisse.
  List<String> get highlights => [
    if (focus.isNotEmpty) TrackCounts.of(focus.length, 'sessão', 'sessões'),
    if (meetings.isNotEmpty)
      TrackCounts.of(meetings.length, 'reunião', 'reuniões'),
    // Duração, e não contagem como os outros: "2 travas" não diz nada, e o
    // que se quer saber do Awake é por quanto tempo o Mac ficou de pé.
    if (awake.isNotEmpty) '${DurationFormat.compact(awakeTotal)} acordado',
    if (copiedTotal > 0)
      TrackCounts.of(copiedTotal, 'item copiado', 'itens copiados'),
    if (notesWritten > 0) TrackCounts.of(notesWritten, 'anotação', 'anotações'),
    if (filesOrganized > 0)
      TrackCounts.of(
        filesOrganized,
        'arquivo organizado',
        'arquivos organizados',
      ),
  ];

  /// Assinatura barata do conteúdo do dia.
  ///
  /// Serve para saber se o parágrafo já escrito pelo modelo ainda descreve
  /// este dia: sem ela, uma sessão registrada depois de o resumo ter sido
  /// escrito deixaria na tela um texto que não bate mais com os números ao
  /// lado — e um resumo errado é pior que resumo nenhum.
  ///
  /// **Ela cobre tudo o que vai para o modelo, não só o que aparece na tela.**
  /// Os resumos das sessões e das reuniões entram no parágrafo (ver
  /// `TrackSummarizer.factsOf`), então resumir uma reunião de terça na
  /// quinta-feira precisa refazer o parágrafo de terça — e reescrever um resumo
  /// que já existia também, o que a contagem sozinha não veria: daí o
  /// comprimento somado ao lado dela.
  String get signature =>
      '${focus.length}/${focusTotal.inMinutes}/'
      '${meetings.length}/${meetingTotal.inMinutes}/'
      '${awake.length}/${awakeTotal.inMinutes}/'
      '$copiedTotal/$notesWritten/$filesOrganized/'
      '${_summarySignature(focus)}/${_summarySignature(meetings)}';

  /// Quantos resumos há e quanto texto eles somam — o bastante para notar que
  /// um apareceu, sumiu ou foi reescrito, sem guardar nada do que dizem.
  static String _summarySignature(List<TrackEntry> entries) {
    var count = 0;
    var length = 0;

    for (final entry in entries) {
      if (!entry.hasSummary) continue;
      count++;
      length += entry.summary!.length;
    }

    return '$count:$length';
  }
}

/// Os totais de um período — o que a frase do topo da tela conta.
@immutable
class TrackTotals {
  const TrackTotals({
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

  static const empty = TrackTotals(
    focus: Duration.zero,
    focusSessions: 0,
    meetings: Duration.zero,
    meetingCount: 0,
    copied: 0,
    notesWritten: 0,
  );

  factory TrackTotals.of(Iterable<TrackDay> days) {
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

    return TrackTotals(
      focus: focus,
      focusSessions: focusSessions,
      meetings: meetings,
      meetingCount: meetingCount,
      copied: copied,
      notesWritten: notes,
    );
  }

  /// Tempo registrado no período — ver `TrackDay.registered`.
  Duration get registered => focus + meetings;

  bool get isEmpty =>
      focusSessions == 0 &&
      meetingCount == 0 &&
      copied == 0 &&
      notesWritten == 0;
}

/// Contagem com o substantivo no número certo.
abstract final class TrackCounts {
  static String of(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';
}

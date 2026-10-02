import 'package:flutter/foundation.dart';

import '../../../shared/utils/day_label.dart';
import '../../../shared/utils/duration_format.dart';
import '../../echo/data/echo_channel.dart';
import '../models/track_day.dart';

/// O parágrafo em linguagem natural que abre o dia.
///
/// Usa o mesmo modelo local do Echo — `FoundationModels`, pelo canal
/// `macos/Runner/EchoChannel.swift` —, e por isso herda o piso de macOS 26 dele.
///
/// **O módulo não depende disso.** Abaixo do macOS 26, sem Apple Intelligence
/// disponível, ou se qualquer coisa der errado no caminho, o Track mostra os
/// números e as listas normalmente e só não escreve o parágrafo: o resumo é
/// enfeite, o dado é o produto.
///
/// O que vai para o modelo são os totais, as contagens por tipo, os nomes que a
/// própria pessoa deu às sessões e às reuniões — e **o que já foi escrito sobre
/// elas**: o resumo que ela digitou ao fechar uma sessão de foco, o que o
/// modelo escreveu sobre uma reunião. É a diferença entre um parágrafo que sabe
/// que houve "3 h em duas sessões" e um que sabe em quê elas foram.
///
/// Conteúdo copiado nunca: ele nem chega até aqui, porque o repositório não o
/// lê (ver [TrackRepository]). A regra não é "nada de texto" — é que o Pin
/// registra o que ninguém escolheu registrar, e um resumo é exatamente o
/// contrário. Ver [TrackEntry.summary].
class TrackSummarizer {
  const TrackSummarizer(this._channel, this._userName);

  final EchoChannel _channel;

  /// Como chamar quem viveu o dia. Vazio, o parágrafo diz "a pessoa".
  final String _userName;

  /// Com o nome, o parágrafo é sobre alguém; sem ele, sobre "a pessoa".
  ///
  /// É a diferença entre "Lucas passou a manhã no módulo de auth" e "a pessoa
  /// passou a manhã no módulo de auth" — a segunda é um relatório que alguém
  /// escreveu sobre você sem saber quem você é.
  static String instructionsFor(String userName) {
    final who = userName.isEmpty ? 'a pessoa' : userName;

    return 'Escreva um parágrafo único, em português do Brasil, no passado, '
        'contando o que $who fez neste dia de trabalho. No máximo três '
        'frases. Use apenas os dados fornecidos — não invente atividade, número '
        'nem conclusão que não esteja neles. Não escreva título, lista nem '
        'introdução: devolva só o parágrafo.';
  }

  /// Escreve o parágrafo do dia, ou `null` quando não dá para escrever.
  Future<String?> write(TrackDay day) async {
    final facts = factsOf(day);
    if (facts == null) return null;

    try {
      final text = await _channel.summarize(
        text: facts,
        instructions: instructionsFor(_userName),
      );
      final trimmed = text.trim();

      return trimmed.isEmpty ? null : trimmed;
    } on EchoException {
      // O caso previsto: `unsupportedOS`, modelo indisponível, janela de
      // contexto. A tela continua inteira sem o parágrafo.
      return null;
    } catch (_) {
      // E o caso imprevisto. A captura larga é deliberada: nenhuma falha do
      // modelo pode derrubar uma tela cujo conteúdo já está desenhado — o
      // parágrafo é o único pedaço que pode faltar.
      return null;
    }
  }

  /// Quanto de um resumo alheio cabe num fato do dia.
  ///
  /// O resumo de uma reunião é um documento — tópicos, decisões, pendências —,
  /// e o parágrafo do dia tem três frases. Mandar os documentos inteiros
  /// afogaria os números do dia num material que o modelo não tem espaço para
  /// destilar, e num dia cheio estouraria a janela de contexto: aqui isso não
  /// tem conserto, porque [write] não reparte nada — ele devolve `null`, e o
  /// dia perde o parágrafo inteiro por excesso de matéria-prima.
  ///
  /// A abertura de um resumo é onde mora o assunto dele, que é o que este
  /// parágrafo precisa saber.
  static const _summaryBudget = 400;

  /// Quantos resumos de um mesmo tipo entram.
  ///
  /// Um dia de sete reuniões não manda sete resumos: as primeiras já dizem em
  /// que o dia foi, e as outras só empurram o total para cima.
  static const _summaryCount = 3;

  /// Os resumos que existem, achatados numa linha cada e cortados no orçamento.
  ///
  /// Lista vazia quando nenhum tem resumo — que é o normal —, e nesse caso
  /// nenhuma linha entra: um "Sobre as sessões:" seguido de nada convidaria o
  /// modelo a preencher a lacuna.
  static Iterable<String> _summaries(String title, List<TrackEntry> entries) {
    final written = entries
        .where((entry) => entry.hasSummary)
        .take(_summaryCount)
        .map((entry) => _clip(entry.summary!, entry.label))
        .toList(growable: false);

    return written.isEmpty ? const [] : ['$title: ${written.join(' | ')}'];
  }

  /// Uma linha só, no orçamento, com o nome na frente quando há um.
  static String _clip(String summary, String? label) {
    final flat = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
    final body = flat.length <= _summaryBudget
        ? flat
        : '${flat.substring(0, _summaryBudget).trimRight()}…';
    final name = label?.trim() ?? '';

    return name.isEmpty ? body : '$name — $body';
  }

  /// Os fatos do dia em texto corrido, do jeito que vão para o modelo.
  ///
  /// `null` num dia sem nada: não há o que resumir, e pedir mesmo assim só
  /// convidaria o modelo a inventar um dia.
  @visibleForTesting
  static String? factsOf(TrackDay day) {
    if (day.isEmpty) return null;

    final lines = <String>['Dia: ${DayLabel.of(day.date)}.'];

    if (day.focus.isNotEmpty) {
      lines.add(
        'Foco: ${DurationFormat.compact(day.focusTotal)} em '
        '${TrackCounts.of(day.focus.length, 'sessão', 'sessões')}.',
      );

      final activities = day.focus
          .where((entry) => entry.hasLabel)
          .map((entry) => entry.label!.trim())
          .toList(growable: false);
      if (activities.isNotEmpty) {
        lines.add('Em quê: ${activities.join('; ')}.');
      }

      lines.addAll(_summaries('Sobre as sessões', day.focus));
    }

    if (day.meetings.isNotEmpty) {
      lines.add(
        'Reuniões: ${day.meetings.length}, somando '
        '${DurationFormat.compact(day.meetingTotal)}.',
      );

      final titles = day.meetings
          .where((entry) => entry.hasLabel)
          .map((entry) => entry.label!.trim())
          .toList(growable: false);
      if (titles.isNotEmpty) {
        lines.add('Quais: ${titles.join('; ')}.');
      }

      lines.addAll(_summaries('Sobre as reuniões', day.meetings));
    }

    if (day.awake.isNotEmpty) {
      lines.add(
        'Mac acordado pelo Awake: ${DurationFormat.compact(day.awakeTotal)} '
        'em ${TrackCounts.of(day.awake.length, 'período', 'períodos')}.',
      );
    }

    if (day.copiedTotal > 0) {
      final byType = day.copied.entries
          .where((entry) => entry.value > 0)
          .map(
            (entry) => '${entry.value} ${entry.key.filterLabel.toLowerCase()}',
          )
          .join(', ');

      lines.add(
        'Itens copiados: ${day.copiedTotal} — $byType. '
        'Só a contagem: o conteúdo não é compartilhado.',
      );
    }

    if (day.notesWritten > 0) {
      lines.add(
        'Anotações escritas: '
        '${TrackCounts.of(day.notesWritten, 'anotação', 'anotações')}.',
      );
    }

    if (day.filesOrganized > 0) {
      lines.add(
        'Arquivos organizados pelo Nest: '
        '${TrackCounts.of(day.filesOrganized, 'arquivo', 'arquivos')}. '
        'Só a contagem: nome e pasta não são compartilhados.',
      );
    }

    return lines.join('\n');
  }
}

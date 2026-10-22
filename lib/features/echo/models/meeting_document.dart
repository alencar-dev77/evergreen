import '../../../shared/utils/duration_format.dart';
import '../../../shared/utils/text_fold.dart';
import 'meeting.dart';
import 'meeting_turn.dart';

/// Qual das duas faces da reunião está aberta.
///
/// É o seletor da leitura que decide — e por isso é ele que decide também o
/// que "Copiar" e "Exportar" levam. Um botão só, que copiasse "a reunião",
/// teria de escolher entre o resumo e a transcrição por conta própria, e
/// escolheria errado metade das vezes.
enum MeetingDocumentKind {
  summary('Resumo', 'resumo', 'Resumo copiado', 'Resumo exportado'),
  transcript(
    'Transcrição',
    'transcricao',
    'Transcrição copiada',
    'Transcrição exportada',
  );

  const MeetingDocumentKind(
    this.label,
    this.slug,
    this.copiedLabel,
    this.exportedLabel,
  );

  /// O nome da aba — e o título da seção no arquivo exportado.
  final String label;

  /// O sufixo do nome do arquivo. Sem acento, que é o que se espera de um
  /// nome de arquivo que vai ser digitado, anexado e mandado adiante.
  final String slug;

  /// A confirmação da cópia, escrita por extenso porque o português concorda:
  /// o resumo é copiad**o** e a transcrição é copiad**a**. Montar a frase com
  /// `'<label> copiado'` acertaria uma das duas.
  final String copiedLabel;

  /// A confirmação da exportação, pela mesma razão de [copiedLabel].
  ///
  /// Não é o nome do arquivo: ele tem quarenta e tantos caracteres e não cabe
  /// na linha sem empurrar os botões. Quem mostra o nome é a janela do Finder
  /// que abre com o arquivo selecionado.
  final String exportedLabel;
}

/// A reunião virada texto, para sair do Evergreen.
///
/// Puro e sem dependência de widget: quem copia e quem escreve o arquivo
/// precisam do **mesmo** texto, e a única forma de garantir isso é os dois
/// pedirem daqui. A transcrição, em especial, é montada em turnos
/// ([MeetingTurn]) exatamente como a tela a desenha — copiar os trechos crus
/// do banco devolveria a mesma frase picada em cinco linhas que o turno existe
/// para juntar.
///
/// **O que se copia é o que se lê; o que se exporta se apresenta.** Copiar
/// entrega só o corpo, porque ele vai cair dentro de um e-mail ou de um
/// documento que já tem título e data. O arquivo sai sozinho no disco e não
/// tem esse contexto, então ele leva um cabeçalho dizendo de que reunião é.
abstract final class MeetingDocument {
  /// O corpo da face aberta, do jeito que ele está na tela.
  ///
  /// `null` quando não há o que levar: reunião sem fala nenhuma, ou o resumo
  /// de uma reunião que ainda não foi resumida. Quem chama usa isso para não
  /// oferecer um botão que copiaria vazio.
  static String? body(
    Meeting meeting,
    MeetingDocumentKind kind, {
    String userName = '',
  }) {
    return switch (kind) {
      MeetingDocumentKind.summary => _blankToNull(meeting.summary),
      MeetingDocumentKind.transcript => _transcript(meeting, userName),
    };
  }

  /// O conteúdo do arquivo exportado: o cabeçalho e o corpo.
  ///
  /// Markdown porque é o formato que se lê igual com e sem programa que o
  /// entenda — um `.md` aberto no TextEdit continua sendo o texto inteiro, com
  /// os `#` à vista e nada escondido. Não é um segundo formato a manter: não
  /// há nada aqui que o Evergreen leia de volta.
  static String? file(
    Meeting meeting,
    MeetingDocumentKind kind, {
    String userName = '',
  }) {
    final body = MeetingDocument.body(meeting, kind, userName: userName);
    if (body == null) return null;

    final buffer = StringBuffer()
      ..writeln('# ${meeting.title}')
      ..writeln()
      ..writeln(header(meeting))
      ..writeln()
      ..writeln('## ${kind.label}')
      ..writeln()
      ..writeln(body);

    // A procedência do resumo vai junto dele, e no mesmo lugar em que está na
    // tela: depois do texto, como nota de rodapé. Um resumo exportado sem a
    // instrução que o produziu é um texto sobre o qual não se pode mais
    // perguntar "por que ele ficou assim?".
    final provenance = [
      if (meeting.hasSummaryModel)
        'Resumido por ${meeting.summaryModel!.trim()}',
      if (meeting.hasSummaryPrompt)
        'Instrução deste resumo: ${meeting.summaryPrompt!.trim()}',
    ];
    if (kind == MeetingDocumentKind.summary && provenance.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln();
      for (final (index, line) in provenance.indexed) {
        if (index > 0) buffer.writeln();
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  /// `26/08/2026 · 10:00 · 32 min` — a linha de identificação do arquivo.
  ///
  /// Data absoluta, e não o "Hoje" da lista: um arquivo é lido meses depois de
  /// escrito, e "Hoje" num arquivo não quer dizer nada no dia seguinte.
  static String header(Meeting meeting) {
    final at = meeting.startedAt;
    final date = '${_pad(at.day)}/${_pad(at.month)}/${at.year}';

    return [
      date,
      '${_pad(at.hour)}:${_pad(at.minute)}',
      DurationFormat.compact(meeting.duration),
    ].join(' · ');
  }

  /// `2026-08-26-alinhamento-de-escopo-resumo.md`.
  ///
  /// A data na frente para os arquivos de uma pasta se ordenarem sozinhos pela
  /// ordem em que as reuniões aconteceram, que é a ordem em que se procura por
  /// elas. O título vem do nome que a pessoa deu — e, quando ela não deu
  /// nenhum, de um título que já é a data por extenso, daí o teto de tamanho.
  static String fileName(Meeting meeting, MeetingDocumentKind kind) {
    final at = meeting.startedAt;
    final stamp = '${at.year}-${_pad(at.month)}-${_pad(at.day)}';

    return '$stamp-${_slug(meeting.title)}-${kind.slug}';
  }

  static String? _transcript(Meeting meeting, String userName) {
    final turns = MeetingTurn.from(meeting.segments);
    if (turns.isEmpty) return null;

    return turns
        .map(
          (turn) =>
              '${turn.labelFor(userName)} · ${turn.timestamp}\n'
              '${turn.text}',
        )
        .join('\n\n');
  }

  /// O título como nome de arquivo: sem acento, sem maiúscula e sem nada que
  /// o Finder ou um anexo de e-mail tratem como caractere especial.
  static String _slug(String title) {
    final buffer = StringBuffer();

    for (final rune in title.runes) {
      final char = TextFold.foldChar(String.fromCharCode(rune));
      buffer.write(RegExp(r'^[a-z0-9]+$').hasMatch(char) ? char : '-');
    }

    final slug = buffer
        .toString()
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (slug.isEmpty) return 'reuniao';

    // Teto de 48: o nome ainda carrega a data e o sufixo da face, e um título
    // longo empurraria os dois para fora do que cabe numa coluna do Finder.
    return slug.length <= 48
        ? slug
        : slug.substring(0, 48).replaceAll(RegExp(r'-$'), '');
  }

  static String? _blankToNull(String? text) {
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

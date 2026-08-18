import 'meeting_segment.dart';

/// Uma fala inteira de uma pessoa, do jeito que se lê.
///
/// O modelo de fala não devolve frases: devolve pedaços, fechados onde ele
/// achou a pausa. Uma única frase sai assim —
///
/// ```
/// [0.0s] Bom dia pessoal, vamos fechar o escopo do projeto
/// [3.8s]  hoje.
/// [4.6s]  ficou
/// [5.0s]  decidido que o Lucas manda a proposta até
/// [7.8s]  sexta-feira.
/// ```
///
/// Mostrar isso linha a linha, cada uma com horário e nome de quem falou, é o
/// que fazia a transcrição parecer desorganizada: a mesma pessoa se repetindo
/// cinco vezes para dizer uma frase.
///
/// O turno junta os pedaços consecutivos da mesma pessoa em um parágrafo. Os
/// trechos originais continuam no banco, com o tempo exato de cada um — quem
/// agrupa é a leitura, não o armazenamento.
class MeetingTurn {
  const MeetingTurn({
    required this.speaker,
    required this.startMs,
    required this.text,
  });

  final Speaker speaker;

  /// Quando a fala começou — o horário do primeiro pedaço.
  final int startMs;

  final String text;

  /// Silêncio que encerra um turno mesmo sem trocar de pessoa.
  ///
  /// A mesma pessoa voltando a falar depois de meio minuto está dizendo outra
  /// coisa, não terminando a frase anterior. Sem este corte, uma reunião em que
  /// só uma pessoa fala viraria um parágrafo de meia hora.
  static const _gapMs = 30000;

  /// `12:03` — o relógio da fala dentro da reunião.
  String get timestamp {
    final totalSeconds = startMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Agrupa os trechos em turnos de leitura.
  static List<MeetingTurn> from(List<MeetingSegment> segments) {
    final turns = <MeetingTurn>[];

    Speaker? speaker;
    var startMs = 0;
    var endMs = 0;
    final buffer = <String>[];

    void flush() {
      final atual = speaker;
      if (atual == null || buffer.isEmpty) return;

      turns.add(
        MeetingTurn(
          speaker: atual,
          startMs: startMs,
          text: _join(buffer),
        ),
      );
      buffer.clear();
    }

    for (final segment in segments) {
      final text = segment.text.trim();
      if (text.isEmpty) continue;

      final trocouDePessoa = segment.speaker != speaker;
      final houveSilencio = segment.startMs - endMs > _gapMs;

      if (trocouDePessoa || houveSilencio) {
        flush();
        speaker = segment.speaker;
        startMs = segment.startMs;
      }

      buffer.add(text);
      endMs = segment.endMs;
    }

    flush();
    return List.unmodifiable(turns);
  }

  /// Cola os pedaços num parágrafo.
  ///
  /// Sem espaço antes de pontuação: os pedaços chegam com o espaço na frente
  /// (`" hoje."`), e juntar cru produziria "projeto hoje ." em metade das
  /// frases.
  static String _join(List<String> parts) {
    final buffer = StringBuffer();

    for (final part in parts) {
      final precisaDeEspaco =
          buffer.isNotEmpty && !_startsWithPunctuation(part);

      if (precisaDeEspaco) buffer.write(' ');
      buffer.write(part);
    }

    return buffer.toString();
  }

  static bool _startsWithPunctuation(String text) =>
      text.isNotEmpty && ',.;:!?)]}'.contains(text[0]);
}

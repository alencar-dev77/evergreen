import 'meeting_segment.dart';

/// Tira da sua faixa o que na verdade era a caixa de som.
///
/// Com a reunião saindo por alto-falante, o microfone escuta de volta o que o
/// computador está tocando. A mesma fala entra nas duas faixas, e o Echo passa
/// a mostrar a fala dos outros duas vezes — uma como "Reunião" e outra como
/// "Você". Isso destrói exatamente aquilo que o módulo promete: saber quem
/// falou.
///
/// Quem manda é a faixa do sistema: ela vem do fluxo de áudio antes de virar
/// som no ar, sem passar por caixa nem por microfone nenhum. Se um trecho seu
/// coincide no tempo **e** no texto com um trecho da reunião, o seu é eco — e
/// sai.
///
/// Fica em Dart, e não no Swift, porque é a única parte disso que é decisão e
/// não captura: dá para testar sem microfone, sem caixa de som e sem reunião.
abstract final class CrossTalkFilter {
  /// Folga na comparação de tempo.
  ///
  /// O caminho do eco é físico — sai da caixa, atravessa a sala, volta pelo
  /// microfone — e ainda passa pelo reconhecimento, que fecha cada trecho onde
  /// acha a pausa. Os dois lados nunca marcam o mesmo instante, e exigir
  /// coincidência exata não filtraria nada.
  static const _toleranceMs = 2000;

  /// Quanto do trecho precisa ser igual para ser considerado o mesmo.
  ///
  /// Não é 1.0 porque o eco chega degradado: o reconhecimento erra palavras no
  /// que voltou pela sala que acertou no áudio limpo. Também não é baixo demais
  /// — duas pessoas concordando ("isso, exatamente") diriam palavras iguais sem
  /// que uma fosse eco da outra.
  static const _similarityThreshold = 0.6;

  /// Devolve os trechos sem o eco da caixa de som.
  static List<MeetingSegment> clean(List<MeetingSegment> segments) {
    final others = segments
        .where((segment) => segment.speaker == Speaker.others)
        .toList(growable: false);

    if (others.isEmpty) return segments;

    return segments
        .where((segment) => !_isEcho(segment, others))
        .toList(growable: false);
  }

  static bool _isEcho(MeetingSegment segment, List<MeetingSegment> others) {
    if (segment.speaker != Speaker.me) return false;

    final mine = _tokens(segment.text);
    if (mine.isEmpty) return false;

    for (final other in others) {
      if (!_overlapsInTime(segment, other)) continue;
      if (_similarity(mine, _tokens(other.text)) >= _similarityThreshold) {
        return true;
      }
    }

    return false;
  }

  static bool _overlapsInTime(MeetingSegment a, MeetingSegment b) =>
      a.startMs - _toleranceMs < b.endMs && b.startMs - _toleranceMs < a.endMs;

  /// Proporção das palavras do trecho suspeito que aparecem no da reunião.
  ///
  /// Assimétrico de propósito: o que interessa é "tudo que eu disse já estava
  /// no áudio da reunião?", e não o contrário. Uma fala longa da reunião pode
  /// conter um eco curto sem que as duas se pareçam no conjunto.
  static double _similarity(List<String> mine, List<String> other) {
    if (mine.isEmpty || other.isEmpty) return 0;

    final available = [...other];
    var matches = 0;

    for (final token in mine) {
      final index = available.indexOf(token);
      if (index < 0) continue;

      available.removeAt(index);
      matches++;
    }

    return matches / mine.length;
  }

  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static List<String> _tokens(String text) => text
      .toLowerCase()
      .split(_nonWord)
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

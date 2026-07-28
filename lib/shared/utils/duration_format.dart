/// Formata durações como texto curto em português.
///
/// Duas leituras diferentes, dois formatos: a contagem regressiva precisa de
/// precisão ao segundo e largura estável; o histórico e o resumo precisam de
/// ordem de grandeza legível ("1h 20min"), nunca de "01:20:00".
abstract final class DurationFormat {
  /// `mm:ss` para o cronômetro em andamento (`04:07`, `25:00`).
  ///
  /// Passa de `60:00` para cima sem virar horas: sessões de foco não chegam
  /// perto disso, e uma terceira casa faria o painel mudar de largura.
  static String countdown(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;

    return '${_pad(minutes)}:${_pad(seconds)}';
  }

  /// Contagem regressiva que pode passar de uma hora (`59:58`, `1:59:58`).
  ///
  /// Existe separada de [countdown] porque o Awake conta até duas horas: fixar
  /// `mm:ss` ali viraria `119:58`, e obrigar o Focus a mostrar `0:24:13` daria
  /// uma casa a mais a um cronômetro que nunca chega perto de uma hora.
  static String clock(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    if (total.inHours == 0) return countdown(total);

    final minutes = total.inMinutes % 60;
    final seconds = total.inSeconds % 60;

    return '${total.inHours}:${_pad(minutes)}:${_pad(seconds)}';
  }

  /// Duração acumulada, para histórico e resumo (`45 min`, `1h 20min`).
  ///
  /// Sem segundos: quem lê o total do dia quer a ordem de grandeza, e "1h
  /// 20min 07s" só adiciona ruído.
  static String compact(Duration duration) {
    final minutes = duration.inMinutes;

    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;

    return rest == 0 ? '${hours}h' : '${hours}h ${_pad(rest)}min';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

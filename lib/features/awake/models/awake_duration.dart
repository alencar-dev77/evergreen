/// Por quanto tempo o Awake segura a tela acesa.
///
/// Uma escala curta e fechada em vez de um campo livre: as três respostas de
/// verdade são "uma apresentação", "uma tarde" e "não desliga até eu mandar" —
/// e um seletor de minutos convidaria a decidir um número que ninguém tem.
enum AwakeDuration {
  minutes30(label: '30 min', minutes: 30),
  hour1(label: '1 h', minutes: 60),
  hours2(label: '2 h', minutes: 120),

  /// Sem prazo: só desliga por ação de quem ligou (ou ao encerrar o Evergreen).
  ///
  /// "Sempre", e não "Sem limite" ou "Indefinido": as quatro opções dividem a
  /// largura do painel, e a mais longa delas é que define se as outras cabem.
  indefinite(label: 'Sempre', minutes: null);

  const AwakeDuration({required this.label, required this.minutes});

  /// Como a opção aparece no seletor.
  final String label;

  /// `null` em [indefinite] — é o que distingue "sem prazo" de "prazo zero".
  final int? minutes;

  Duration? get duration {
    final minutes = this.minutes;
    return minutes == null ? null : Duration(minutes: minutes);
  }

  bool get hasDeadline => minutes != null;

  /// Todas as opções, na ordem em que o seletor as mostra.
  static const options = values;

  static AwakeDuration fromName(String? name) => values.firstWhere(
    (duration) => duration.name == name,
    orElse: () => hour1,
  );
}

/// Por quanto tempo o teclado fica bloqueado.
///
/// Escala curta de propósito, e bem mais curta que a do Awake: bloquear o
/// teclado é coisa de um minuto, e um prazo longo só
/// aumenta o tempo em que alguém pode ficar sem teclado sem querer. "Sempre"
/// existe para quem prefere desbloquear à mão; a saída continua sendo o mouse.
///
/// É preferência, escolhida no Hub, e não pergunta do painel: na hora de
/// bloquear ninguém quer decidir um número, e o painel bloqueado não tem
/// teclado para trocar de opção.
enum KeyboardLockDuration {
  minute1(label: '1 min', minutes: 1),
  minutes5(label: '5 min', minutes: 5),
  minutes10(label: '10 min', minutes: 10),

  /// Sem prazo: só o "Desbloquear", o clique fora do painel ou o menu da barra
  /// devolvem o teclado.
  indefinite(label: 'Sempre', minutes: null);

  const KeyboardLockDuration({required this.label, required this.minutes});

  /// Como a opção aparece no seletor.
  final String label;

  /// `null` em [indefinite].
  final int? minutes;

  Duration? get duration {
    final minutes = this.minutes;
    return minutes == null ? null : Duration(minutes: minutes);
  }

  /// Todas as opções, na ordem em que o seletor as mostra.
  static const options = values;

  /// Um minuto quando não há escolha gravada.
  static KeyboardLockDuration fromName(String? name) => values.firstWhere(
    (duration) => duration.name == name,
    orElse: () => minute1,
  );
}

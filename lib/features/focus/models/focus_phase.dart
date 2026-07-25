/// As duas metades de um ciclo do Focus.
///
/// Só a fase de foco vira histórico: ninguém pergunta "quanto tempo descansei
/// na terça". A pausa existe para o ciclo fazer sentido, não para ser medida.
enum FocusPhase {
  focus('Foco'),
  rest('Pausa');

  const FocusPhase(this.label);

  /// Rótulo exibido no painel, em caixa alta pelo `EgSectionLabel`.
  final String label;

  bool get isFocus => this == FocusPhase.focus;
}

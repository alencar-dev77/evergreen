/// Os temas do Evergreen.
///
/// Dois, e os dois escuros: o Evergreen continua sendo dark-only — o que muda
/// entre eles é a linguagem, não a luz. O `evergreen` é a paleta da casa, densa
/// e opaca; o `apple` segue o HIG do macOS escuro, com vibrancy, cantos menores,
/// linhas de meio pixel e o verde do sistema.
///
/// O tema é **preferência do aplicativo**, não de módulo: mora no `AppSettings`
/// e na tela do Evergreen, como "iniciar com o macOS".
enum AppThemeId {
  evergreen('Evergreen', 'A paleta da casa: densa, opaca, verde do Evergreen.'),
  apple(
    'Apple',
    'O escuro do macOS: vibrancy, meio pixel e o verde do sistema.',
  );

  const AppThemeId(this.label, this.description);

  /// Nome mostrado no seletor de aparência.
  final String label;

  /// Uma linha dizendo o que muda — o seletor mostra a miniatura, não isto.
  final String description;

  static AppThemeId fromName(String? name) => values.firstWhere(
    (theme) => theme.name == name,
    orElse: () => AppThemeId.evergreen,
  );
}

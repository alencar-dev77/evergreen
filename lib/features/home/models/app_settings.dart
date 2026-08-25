/// Preferências do Evergreen como aplicativo — as que não pertencem a módulo
/// nenhum.
class AppSettings {
  const AppSettings({
    this.launchAtLogin = false,
    this.startMinimized = true,
    this.automaticBackup = true,
  });

  /// Iniciar o Evergreen junto com o macOS.
  ///
  /// Começa desligado de propósito: registrar um item de início sem o usuário
  /// pedir seria intrusivo. O valor real é lido do sistema a cada inicialização.
  final bool launchAtLogin;

  /// Abrir minimizado, sem mostrar o Hub.
  final bool startMinimized;

  /// Guardar uma cópia do banco uma vez por semana.
  ///
  /// Começa **ligado**, ao contrário do [launchAtLogin]: registrar um item de
  /// início mexe no sistema da pessoa, enquanto o backup escreve um arquivo na
  /// pasta do próprio aplicativo e não passa de cinco. E o Evergreen não manda
  /// nada para lugar nenhum — se este banco se perder, não há de onde puxar de
  /// volta, então o padrão que protege é o que fica ligado.
  final bool automaticBackup;

  AppSettings copyWith({
    bool? launchAtLogin,
    bool? startMinimized,
    bool? automaticBackup,
  }) {
    return AppSettings(
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      startMinimized: startMinimized ?? this.startMinimized,
      automaticBackup: automaticBackup ?? this.automaticBackup,
    );
  }
}

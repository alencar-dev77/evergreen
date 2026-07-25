/// Preferências do Evergreen como aplicativo — as que não pertencem a módulo
/// nenhum.
class AppSettings {
  const AppSettings({
    this.launchAtLogin = false,
    this.startMinimized = true,
  });

  /// Iniciar o Evergreen junto com o macOS.
  ///
  /// Começa desligado de propósito: registrar um item de início sem o usuário
  /// pedir seria intrusivo. O valor real é lido do sistema a cada inicialização.
  final bool launchAtLogin;

  /// Abrir minimizado, sem mostrar o Hub.
  final bool startMinimized;

  AppSettings copyWith({bool? launchAtLogin, bool? startMinimized}) {
    return AppSettings(
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      startMinimized: startMinimized ?? this.startMinimized,
    );
  }
}

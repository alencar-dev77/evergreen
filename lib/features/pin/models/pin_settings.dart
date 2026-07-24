/// Preferências do módulo Pin.
class PinSettings {
  const PinSettings({
    this.launchAtLogin = false,
    this.startMinimized = true,
    this.historyLimit = 200,
    this.autoPaste = false,
  });

  /// Iniciar o Evergreen junto com o macOS.
  ///
  /// Começa desligado de propósito: registrar um item de início sem o usuário
  /// pedir seria intrusivo. O valor real é lido do sistema a cada inicialização.
  final bool launchAtLogin;

  /// Abrir minimizado, sem mostrar o Hub.
  final bool startMinimized;

  /// Quantidade máxima de itens não fixados mantidos no histórico.
  final int historyLimit;

  /// Colar o item no app anterior automaticamente ao selecioná-lo (simula ⌘V).
  ///
  /// Desligado por padrão: exige permissão de Acessibilidade do macOS e é uma
  /// ação que "digita" no app do usuário — algo que só deve acontecer quando
  /// explicitamente pedido.
  final bool autoPaste;

  /// Opções oferecidas na tela de configurações.
  static const historyLimitOptions = <int>[50, 100, 200, 500];

  PinSettings copyWith({
    bool? launchAtLogin,
    bool? startMinimized,
    int? historyLimit,
    bool? autoPaste,
  }) {
    return PinSettings(
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      startMinimized: startMinimized ?? this.startMinimized,
      historyLimit: historyLimit ?? this.historyLimit,
      autoPaste: autoPaste ?? this.autoPaste,
    );
  }
}

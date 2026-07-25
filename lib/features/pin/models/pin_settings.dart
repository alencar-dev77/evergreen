/// Preferências do módulo Pin.
///
/// Só o que é do Pin: "iniciar com o macOS" e "abrir minimizado" são do
/// aplicativo e moram em `AppSettings`.
class PinSettings {
  const PinSettings({
    this.historyLimit = 200,
    this.autoPaste = false,
  });

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

  PinSettings copyWith({int? historyLimit, bool? autoPaste}) {
    return PinSettings(
      historyLimit: historyLimit ?? this.historyLimit,
      autoPaste: autoPaste ?? this.autoPaste,
    );
  }
}

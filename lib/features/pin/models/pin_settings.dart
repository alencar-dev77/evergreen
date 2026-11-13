import 'clipboard_item_type.dart';

/// Preferências do módulo Pin.
///
/// Só o que é do Pin: "iniciar com o macOS" e "abrir minimizado" são do
/// aplicativo e moram em `AppSettings`.
class PinSettings {
  const PinSettings({
    this.historyLimit = 200,
    this.autoPaste = false,
    this.ignoredTypes = const <ClipboardItemType>{},
    this.captureScreenshots = false,
  });

  /// Quantidade máxima de itens não fixados mantidos no histórico.
  final int historyLimit;

  /// Os tipos que o Pin **deixa passar** sem guardar.
  ///
  /// Guardado pela negativa, e não por uma lista do que entra: um tipo novo
  /// nasce capturado sem ninguém vir aqui, que é a mesma regra do módulo que
  /// nasce ligado. Fosse pela positiva, o dia em que o classificador aprendesse
  /// um oitavo tipo ele chegaria desligado para quem já usa o app — e ninguém
  /// procura numa tela de preferências por algo que não sabe que existe.
  ///
  /// Vazio é o estado normal: tudo o que passa pela área de transferência é
  /// registrado.
  final Set<ClipboardItemType> ignoredTypes;

  /// O tipo entra no histórico?
  bool captures(ClipboardItemType type) => !ignoredTypes.contains(type);

  /// Colar o item no app anterior automaticamente ao selecioná-lo (simula ⌘V).
  ///
  /// Desligado por padrão: exige permissão de Acessibilidade do macOS e é uma
  /// ação que "digita" no app do usuário — algo que só deve acontecer quando
  /// explicitamente pedido.
  final bool autoPaste;

  /// Guardar no Pin cada print salvo em arquivo (`⌘⇧3`, `⌘⇧4`).
  ///
  /// Desligado por padrão, como o auto-colar: o print mora numa pasta que o
  /// macOS protege (a Mesa), e ligar é o que faz o sistema pedir acesso a ela.
  /// Uma permissão pedida sem ninguém ter pedido nada seria o Evergreen
  /// surpreendendo quem acabou de atualizar.
  ///
  /// O print com `⌃`, que vai para a área de transferência, entra sempre —
  /// esse é uma cópia como outra qualquer.
  final bool captureScreenshots;

  /// Opções oferecidas na tela de configurações.
  static const historyLimitOptions = <int>[50, 100, 200, 500];

  PinSettings copyWith({
    int? historyLimit,
    bool? autoPaste,
    Set<ClipboardItemType>? ignoredTypes,
    bool? captureScreenshots,
  }) {
    return PinSettings(
      historyLimit: historyLimit ?? this.historyLimit,
      autoPaste: autoPaste ?? this.autoPaste,
      ignoredTypes: ignoredTypes ?? this.ignoredTypes,
      captureScreenshots: captureScreenshots ?? this.captureScreenshots,
    );
  }
}

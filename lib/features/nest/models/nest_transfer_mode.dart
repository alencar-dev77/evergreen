/// O que acontece com o arquivo quando ele sai da prateleira.
///
/// Copiar é o padrão, como no Finder e no Dropover: é a operação que não
/// destrói nada, e quem arrastou dez arquivos para a prateleira não
/// necessariamente quer esvaziar as pastas de origem.
///
/// A escolha vive nas preferências do módulo porque é uma decisão que se toma
/// uma vez — e o `⌥` segurado na hora inverte a que estiver valendo, que é a
/// convenção do próprio macOS. Uma linha a mais no painel perguntando "copiar
/// ou mover?" a cada envio seria uma decisão que ninguém pediu.
enum NestTransferMode {
  /// O original fica onde está.
  copy(label: 'Copiar'),

  /// O original vai junto.
  move(label: 'Mover');

  const NestTransferMode({required this.label});

  /// Como a opção aparece no seletor e na barra de dicas do painel.
  final String label;

  /// O oposto — o que o `⌘` segurado faz valer.
  NestTransferMode get inverted => this == copy ? move : copy;

  /// Todas as opções, na ordem em que o seletor as mostra.
  static const options = values;

  static NestTransferMode fromName(String? name) =>
      values.firstWhere((mode) => mode.name == name, orElse: () => copy);
}

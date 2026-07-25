/// As janelas independentes que o Evergreen pode abrir.
///
/// A janela 0 (criada pelo runner do macOS) hospeda o overlay porque é a única
/// que o `window_manager` consegue estilizar — borderless, transparente e
/// sempre no topo. O Hub abre como sub-janela, onde o chrome nativo do macOS é
/// exatamente o que se espera de um painel de configurações.
enum WindowKind {
  /// Painel flutuante estilo Spotlight, compartilhado pelos módulos invocados
  /// por atalho global (Pin e Focus). Qual painel aparece é decidido em Dart,
  /// pelo `overlayPanelProvider`.
  overlay(''),

  /// Painel principal: lista de módulos do Evergreen e suas configurações.
  hub('hub');

  const WindowKind(this.arguments);

  /// String passada ao engine da janela; a janela 0 sempre recebe vazio.
  final String arguments;

  static WindowKind fromArguments(String arguments) =>
      arguments == hub.arguments ? WindowKind.hub : WindowKind.overlay;
}

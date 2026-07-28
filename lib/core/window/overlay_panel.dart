/// Os painéis que podem ocupar a janela flutuante do Evergreen.
///
/// Pin, Focus e Awake dividem a mesma janela (a janela 0) em vez de cada um
/// abrir a sua: só ela pode ser transparente, sem chrome e sempre no topo, e
/// ela nunca é destruída — é o que faz os três atalhos globais abrirem
/// instantaneamente. Decisão registrada em
/// `docs/Ideis projeto/focus-janela-compartilhada.md`.
enum OverlayPanel {
  /// Histórico da área de transferência (`⌘⇧C`).
  pin,

  /// Cronômetro de foco (`⌘⇧X`).
  focus,

  /// Trava que mantém a tela acesa (`⌘⇧D`).
  awake,
}

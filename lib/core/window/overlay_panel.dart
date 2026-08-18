/// Os painéis que podem ocupar a janela flutuante do Evergreen.
///
/// Pin, Focus, Leaf, Awake e Echo dividem a mesma janela (a janela 0) em vez de cada
/// um abrir a sua: só ela pode ser transparente, sem chrome e sempre no topo, e
/// ela nunca é destruída — é o que faz os atalhos globais abrirem
/// instantaneamente. Decisão registrada em
/// `docs/Ideis projeto/focus-janela-compartilhada.md`.
///
/// Nenhum painel escolhe onde nasce: todos são centralizados na janela, que por
/// sua vez nasce sempre no mesmo ponto da tela do cursor (`OverlayWindow`). É o
/// que faz painéis de alturas tão diferentes quanto o Awake e a parede cheia do
/// Leaf aparecerem no mesmo lugar.
enum OverlayPanel {
  /// Histórico da área de transferência (`⌘⇧C`).
  pin,

  /// Cronômetro de foco (`⌘⇧F`).
  focus,

  /// Parede de anotações rápidas (`⌘⇧D`).
  leaf,

  /// Trava que mantém a tela acesa (`⌘⇧X`).
  awake,

  /// Gravação da reunião (`⌘⇧E`). Só começar e parar — a transcrição se lê
  /// no Hub.
  echo,
}

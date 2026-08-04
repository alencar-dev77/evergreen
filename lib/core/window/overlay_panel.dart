/// Os painéis que podem ocupar a janela flutuante do Evergreen.
///
/// Pin, Focus, Leaf e Awake dividem a mesma janela (a janela 0) em vez de cada
/// um abrir a sua: só ela pode ser transparente, sem chrome e sempre no topo, e
/// ela nunca é destruída — é o que faz os atalhos globais abrirem
/// instantaneamente. Decisão registrada em
/// `docs/Ideis projeto/focus-janela-compartilhada.md`.
enum OverlayPanel {
  /// Histórico da área de transferência (`⌘⇧C`).
  pin,

  /// Cronômetro de foco (`⌘⇧F`).
  focus,

  /// Parede de anotações rápidas (`⌘⇧D`).
  ///
  /// Abre bem mais alto que os outros porque é o único painel que ocupa quase
  /// toda a altura útil da tela: a 18% ele começaria alto o bastante para a
  /// última linha de cartões sair pela borda de baixo.
  leaf(verticalAnchor: 0.06),

  /// Trava que mantém a tela acesa (`⌘⇧X`).
  awake;

  const OverlayPanel({this.verticalAnchor = _defaultVerticalAnchor});

  /// Fração da altura da tela onde o topo do painel é ancorado.
  ///
  /// Um pouco acima do centro, como o Spotlight — quanto maior o painel, mais
  /// alto ele precisa nascer para caber inteiro.
  final double verticalAnchor;

  static const _defaultVerticalAnchor = 0.18;
}

# Acessibilidade

## Princípio central

Acessibilidade no Evergreen não é uma camada adicionada depois — é uma consequência direta da própria filosofia de design do produto (hierarquia clara, contraste deliberado, teclado como caminho primário). Um app bem desenhado segundo esta skill já resolve boa parte da acessibilidade "de graça"; esta seção existe para tornar explícito o que precisa de verificação ativa.

## Contraste

- Texto principal sobre fundo: mínimo WCAG AA (4.5:1) em qualquer combinação usada em `text/primary` sobre `surface/base` ou `surface/raised`, nos dois modos (light/dark) — ver `colors.md`.
- Texto grande (18px+ ou 14px+ bold) pode usar o mínimo reduzido de AA para texto grande (3:1), mas isso raramente se aplica no Evergreen dado que a escala tipográfica é predominantemente pequena.
- Ícones que carregam significado funcional (não puramente decorativos) seguem o mesmo padrão mínimo de contraste que texto.
- Nunca depender apenas de cor para comunicar um estado (erro, sucesso, seleção) — sempre acompanhar de uma diferença adicional perceptível: peso de texto, ícone, posição, ou label textual. Isso protege tanto pessoas com daltonismo quanto qualquer situação de tela com brilho/calibração ruim.

## Foco de teclado

- Todo elemento interativo (botão, campo, item de lista, item de menu, aba) tem um estado de foco visualmente distinto e sempre visível quando a navegação é feita por teclado — nunca remover o outline de foco sem substituí-lo por algo igualmente perceptível.
- A ordem de foco (tab order) segue a ordem lógica de leitura visual da tela — nunca uma ordem que "pula" de forma inesperada entre regiões distantes da interface.
- Todo fluxo completo do app deve ser operável do início ao fim sem nenhum uso de mouse — isso não é apenas um requisito de acessibilidade formal, é literalmente o modo de uso principal esperado do Evergreen (ver `ux.md`).

## Alvos de interação

- Área clicável mínima de 24×24px, com preferência por 28–32px sempre que o layout permitir (ver `spacing.md`) — importante tanto para pessoas com limitações motoras quanto para uso geral em trackpad.
- Elementos interativos adjacentes (ex: botões lado a lado em uma toolbar) mantêm espaçamento suficiente entre si para evitar ativação acidental do elemento errado.

## Leitores de tela e semântica

- Todo elemento interativo tem um rótulo semântico claro exposto à árvore de acessibilidade do sistema (label descritivo, não apenas um ícone sem texto alternativo) — mesmo quando o elemento visual não mostra texto (ex: um botão de ícone precisa de um label de acessibilidade equivalente ao que um tooltip mostraria visualmente).
- Estados dinâmicos (item selecionado, expandido/colapsado, carregando, desabilitado) são expostos de forma que um leitor de tela consiga anunciá-los, não apenas representados visualmente por cor/opacidade.
- Agrupamentos visuais (seções de sidebar, grupos de lista) têm uma estrutura semântica correspondente, para que a navegação por leitor de tela reflita a mesma hierarquia que a navegação visual sugere.

## Redução de movimento

- Toda animação não-essencial (motion decorativo, transições de entrada/saída, hover com movimento) respeita a preferência de sistema de "reduzir movimento" do macOS quando ativada — nesse caso, substitua transições de posição/escala por simples mudanças de opacidade instantâneas ou quase instantâneas.
- Nenhuma informação deve depender exclusivamente de estar em movimento para ser percebida (ex: um indicador que só aparece durante uma animação de entrada) — o estado final estático deve sempre comunicar a informação completa mesmo que a animação seja desativada ou pulada.

## Escala de texto e zoom

- A interface deve permanecer funcional e sem quebra de layout quando o usuário aumenta a escala de fonte do sistema/app — truncamento gracioso (ver `typography.md`) em vez de sobreposição de elementos.
- Ícones e alvos de clique não devem depender de um tamanho de texto fixo pequeno para "caber" — teste a composição também em escalas de fonte maiores antes de considerar uma tela finalizada.

## Verificação prática antes de considerar uma tela pronta

- [ ] Toda ação primária é alcançável e executável só de teclado.
- [ ] Todo elemento de foco é visualmente identificável, nos dois modos de cor.
- [ ] Nenhum estado depende só de cor para ser entendido.
- [ ] Contraste de texto principal testado nos dois modos.
- [ ] Nenhuma animação essencial de informação some completamente com "reduzir movimento" ativado.
- [ ] Labels de acessibilidade existem para todo botão/ícone sem texto visível.

# Espaçamento, Grid e Composição

## Princípio central

Espaço no Evergreen é uma ferramenta de **agrupamento**, não uma ferramenta de "respiro estético". A pergunta antes de adicionar qualquer padding ou margem não é "fica bonito?" mas "isso ajuda a pessoa a entender o que pertence junto e o que é um grupo separado?".

Aplicações desktop de produtividade (diferente de sites de marketing) tendem à **densidade deliberada**: mais informação visível por tela, com hierarquia clara compensando a densidade — não menos informação com mais espaço vazio ao redor.

## Escala de espaçamento

Use uma escala pequena, em múltiplos de 4px (padrão consistente com o grid de pixel do macOS/Retina), e resista à tentação de usar valores arbitrários fora dela:

`4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48`

Papéis sugeridos:

- **4px** — espaçamento mínimo entre elementos fortemente relacionados (ícone e seu label imediato, dentro de um badge).
- **8px** — espaçamento padrão entre itens dentro de um mesmo grupo (linhas próximas de uma lista compacta, itens de uma toolbar).
- **12–16px** — padding interno padrão de componentes (botões, campos, linhas de lista, itens de menu).
- **16–24px** — espaçamento entre grupos distintos dentro de uma mesma seção/painel.
- **24–32px** — separação entre seções inteiras dentro de uma tela (ex: entre um cabeçalho de painel e o conteúdo abaixo).
- **32–48px** — margens externas de uma janela/painel principal, usadas com moderação — nunca como "preenchimento" generalizado.

Nunca aplique um espaçamento grande (32px+) só para "a tela não parecer cheia" — se a tela está com muito espaço vazio, o problema normalmente é falta de conteúdo relevante ali (ver `anti-patterns.md`), não falta de padding.

## Grid e alinhamento

- Trabalhe com um grid de colunas implícito baseado em múltiplos consistentes de largura para sidebars, painéis e listas — não é necessário (nem apropriado) usar uma grade de 12 colunas típica de web design; um layout de app desktop normalmente é composto por **regiões fixas ou redimensionáveis** (sidebar + conteúdo + painel de detalhe opcional), não por colunas fluidas de conteúdo.
- Alinhe elementos ao mesmo eixo vertical/horizontal sempre que fizerem parte do mesmo grupo lógico — ícones de uma lista alinhados na mesma coluna, texto começando sempre no mesmo x, ações à direita sempre na mesma posição relativa à borda do painel.
- Evite centralizar conteúdo de trabalho (listas, formulários, painéis de configuração). Centralização é um padrão de landing page/documento, não de ferramenta de produtividade — o olho de quem trabalha com uma ferramenta o dia todo se acostuma a **posições fixas e previsíveis**, e conteúdo centralizado muda de posição horizontal conforme a largura da janela, quebrando essa previsibilidade.
  - Exceção legítima: um diálogo modal pequeno e pontual pode ser centralizado na janela, porque ali a centralização é sobre a janela inteira (um ponto de referência fixo), não sobre o conteúdo relativo à largura variável de um painel.

## Densidade de informação

Densidade é uma decisão consciente, calibrada pelo "modo de uso" (ver `philosophy.md`):

- **Alta densidade** (listas de comando, resultados de busca, tabelas de dados) → linhas de 28–36px de altura, padding horizontal de 8–12px, sem espaço extra "decorativo" entre itens do mesmo tipo.
- **Densidade média** (itens de sidebar, cards de configuração, linhas de lista com metadado secundário) → linhas de 36–48px, com um pouco mais de padding vertical para acomodar duas linhas de texto (título + metadado).
- **Baixa densidade** (raro — apenas telas de configuração inicial, onboarding mínimo, empty states) → mais espaço, mas ainda sem exagero; mesmo aqui, o Evergreen deve parecer "app compacto", nunca "site institucional".

Regra prática: **quando em dúvida, prefira a densidade mais alta que ainda mantém boa legibilidade e alvos de clique confortáveis** (ver `ux.md` e `accessibility.md` para tamanhos mínimos de alvo de clique/toque).

## Border-radius

Radius no Evergreen é sutil e consistente, nunca "arredondado como app de mobile de IA genérica". Use uma escala pequena:

- **4–6px** — componentes pequenos e densos: botões compactos, badges, inputs pequenos, itens de lista com fundo (linha selecionada).
- **8px** — componentes de tamanho médio: botões padrão, campos de busca, cards de configuração quando genuinamente necessários.
- **10–12px** — superfícies flutuantes maiores: popups, dropdowns, modais.
- **Nunca** use radius muito alto (16px+) em componentes retangulares de conteúdo — isso empurra a estética para "app de mobile consumer" em vez de "ferramenta desktop profissional". A exceção genuína é elementos circulares de propósito (avatar, indicador de ponto/dot), que naturalmente usam radius total (círculo), mas isso não é uma decisão de "radius alto", é geometria de círculo.
- Mantenha o radius consistente entre elementos aninhados: se um popup tem radius de 10px e contém um botão internamente encostado na borda, o radius do botão deve respeitar a curvatura do container pai (radius menor ou concêntrico), nunca dois raios visualmente conflitantes.

## Alvos de clique e área de interação

- Área clicável mínima recomendada: 24×24px para elementos muito compactos dentro de um contexto de alta densidade (ex: botão de fechar de uma aba), mas prefira 28–32px sempre que o layout permitir.
- A área clicável pode (e deve) ser maior que a área visualmente desenhada do ícone/texto — um ícone de 16px pode ter uma área de toque de 28px ao redor dele, invisível mas funcional.
- Em listas, a linha inteira geralmente é a área clicável/hover (não apenas o texto), para reduzir a precisão de mouse exigida — comportamento característico de apps macOS bem feitos (Finder, Mail, Things).

## Composição de tela

- Toda tela principal do Evergreen tende a seguir uma estrutura de regiões, não uma composição livre: **sidebar de navegação** (quando aplicável) + **área de conteúdo principal** + **painel de detalhe opcional** (quando o item selecionado precisa de mais contexto). Essa estrutura de três regiões (inspirada em Linear, Things, Mail) é o padrão default a considerar antes de inventar uma composição nova.
- Cabeçalhos de painel são compactos e funcionais: título + ação primária/busca, não um "hero" com espaço decorativo.
- Rodapés/barras de status (quando existirem) são finos e informativos (contagem de itens, atalho disponível), nunca decorativos.

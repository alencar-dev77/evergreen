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

### Escala implementada (`AppSpacing`)

A escala do produto tem nomes, não números soltos. Nenhum valor de espaçamento deve aparecer como literal em um widget — se falta um degrau, adicione o token.

| Token | Valor | Papel |
|---|---|---|
| `hairline` | 1 | título e subtítulo colados num bloco só |
| `xxxs` | 2 | respiro concêntrico de um container em volta do filho (segmented control) |
| `xxs` | 4 | ícone e seu label |
| `xs` | 6 | padding de key-cap, respiro mínimo de grupo |
| `sm` | 8 | gap padrão dentro de um grupo, padding vertical de botão |
| `md` | 10 | padding horizontal de linha de lista, gap de ícone→texto |
| `lg` | 14 | padding da barra de dicas, rodapé de lista |
| `xl` | 16 | padding horizontal de botão, padding de card interno |
| `xxl` | 20 | padding de painel (preview, diálogo), margem da sidebar |
| `xxxl` | 24 | separação entre cabeçalho e conteúdo |
| `huge` | 32 | margem externa da área de conteúdo do Hub, fim de seção de configuração |
| `giant` | 48 | rodapé de scroll da janela — o topo da escala, usado com parcimônia |

### Tamanho de ícone e de badge (`AppIconSizes`, `AppBadgeSizes`)

Ícone não escolhe tamanho por widget — um glifo de 14 ao lado de um de 15 na mesma tela não é decisão, é esquecimento. A escala é curta porque ícone aqui é sempre acessório de um texto: quem manda no tamanho é a linha em que ele vive.

| Token | Valor | Papel |
|---|---|---|
| `AppIconSizes.xs` | 13 | metadado dentro de linha compacta (lixeira do cartão, estrela do preview) |
| `AppIconSizes.sm` | 14 | ícone que acompanha um rótulo dentro de um botão |
| `AppIconSizes.md` | 15 | linha de lista, campo de busca, item de sidebar — o padrão |
| `AppIconSizes.lg` | 16 | ícone sozinho, sem rótulo (botão de ícone, marca) |
| `AppIconSizes.xl` | 18 | dentro de um badge grande (estado vazio, módulo por vir) |
| `AppBadgeSizes.sm` | 28 | badge dentro de uma linha |
| `AppBadgeSizes.md` | 36 | badge dentro de um bloco; botão de ícone |
| `AppBadgeSizes.lg` | 40 | badge sozinho acima de um texto centralizado |

Geometria de um componente só (o trilho do switch, o cartão do Leaf, a altura da linha do Pin) **não** vira token: fica no próprio componente, com o motivo escrito ao lado. Token é o que atravessa arquivos.

### Opacidade de estado (`AppOpacities`)

`disabled` (0.4) é uma só para o app inteiro — um toggle a 50% ao lado de um botão a 40% na mesma tela conta duas histórias diferentes sobre a mesma condição. `unavailable` (0.55) é mais forte de propósito: o módulo que ainda não existe continua clicável, e o que há para ver é justamente a tela que conta quando ele chega.

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

**O canto do Evergreen é contínuo, não um arco de círculo.** O macOS arredonda
com curvatura que entra e sai gradualmente, e é isso que faz um canto do sistema
parecer macio enquanto um `BorderRadius.circular` do mesmo raio parece uma
esquina lixada. Era o sintoma número um do desenho anterior — raios de 6 a 12 em
arco circular contra um sistema que arredonda contínuo e maior.

Quem resolve é o `EgSquircle`:

- `EgSquircle.shape(r)` devolve um `ContinuousRectangleBorder` acima de **14**,
  e o arredondado normal abaixo — ali os dois dão a mesma imagem, e o arco é
  mais barato (um `ShapeDecoration` custa um `Path` por quadro).
- Superfície interativa desenha com **`ShapeDecoration`**, não `BoxDecoration`.
  `EgSurface` já faz isso para todo mundo.

### Escala implementada (`EgShapes`) — valores oficiais do produto

| Token | Valor | Aplicação |
|---|---|---|
| `radiusWindow` | 26 | a janela do Hub |
| `radiusPanel` | 20 | painel flutuante, `EgConfirmDialog`, dropdown |
| `radiusStage` | 18 | bloco-instrumento: o anel do Focus, a pilha do Nest, a bancada do gerador |
| `radiusCard` | 14 | cartão de seção |
| `radiusRow` | 11 | linha de lista, item de barra lateral, faixa de estado |
| `radiusControl` | 10 | botão, campo |
| `radiusSegment` | 7 | segmento dentro do trilho, keycap |
| `radiusChip` | 999 | pílula: interruptor mestre, filtro, aba, tecla do cabeçalho |

A escala subiu inteira — o teto era 12 e passou a 26. **Isso não é "arredondado
de app mobile"**: é o raio que o macOS usa nas próprias janelas, e o que o
distingue de estética consumer é a curvatura contínua, não o número.

Aninhamento continua concêntrico: o segmento interno usa `radiusSegment` (7)
porque o trilho usa `radiusControl` (10) com 2px de padding.

**Forma é família.** Dois controles vizinhos que fazem parte do mesmo par —
o interruptor mestre e a tecla do módulo, no cabeçalho — usam o **mesmo** raio.
Cápsula ao lado de retângulo se lê como duas coisas soltas mesmo quando as duas
estão perfeitamente centradas no mesmo eixo; foi exatamente esse o "desalinho"
que se percebeu no cabeçalho antes de alguém medir.

## Alvos de clique e área de interação

- Área clicável mínima recomendada: 24×24px para elementos muito compactos dentro de um contexto de alta densidade (ex: botão de fechar de uma aba), mas prefira 28–32px sempre que o layout permitir.
- A área clicável pode (e deve) ser maior que a área visualmente desenhada do ícone/texto — um ícone de 16px pode ter uma área de toque de 28px ao redor dele, invisível mas funcional.
- Em listas, a linha inteira geralmente é a área clicável/hover (não apenas o texto), para reduzir a precisão de mouse exigida — comportamento característico de apps macOS bem feitos (Finder, Mail, Things).

## Composição de tela

- Toda tela principal do Evergreen tende a seguir uma estrutura de regiões, não uma composição livre: **sidebar de navegação** (quando aplicável) + **área de conteúdo principal** + **painel de detalhe opcional** (quando o item selecionado precisa de mais contexto). Essa estrutura de três regiões (inspirada em Linear, Things, Mail) é o padrão default a considerar antes de inventar uma composição nova.
- Cabeçalhos de painel são compactos e funcionais: título + ação primária/busca, não um "hero" com espaço decorativo.
- Rodapés/barras de status (quando existirem) são finos e informativos (contagem de itens, atalho disponível), nunca decorativos.

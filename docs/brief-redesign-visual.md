# Brief de redesign visual — Evergreen (macOS)

> Documento para colar em uma sessão de design. Contém o produto, as dimensões
> reais das janelas/painéis, os tokens atuais (cores, tipografia, espaçamento,
> motion), a matriz de estados, os componentes já existentes e a microcópia das
> telas. Tudo abaixo é o **estado atual implementado** — não é a proposta.

---

## 1. O que é o produto

**Evergreen** é uma suíte pessoal de produtividade para **macOS**, feita em
Flutter, que roda como **agente da barra de menus** (`LSUIElement`): sem janela
ao iniciar, sem ícone no Dock. Tudo é local — nada vai para a internet.

São **cinco módulos**, cada um com um atalho global e um painel flutuante que
abre por cima de qualquer app:

| Módulo | Atalho | O que faz |
|---|---|---|
| **Pin** | `⌘⇧C` | Gerenciador de área de transferência: histórico local, busca instantânea, itens fixados, cola direto no app anterior |
| **Focus** | `⌘⇧F` | Cronômetro de foco/pausa, com registro do que foi feito em cada sessão e histórico |
| **Leaf** | `⌘⇧D` | Parede de até 9 anotações curtas, todas à vista; o número do cartão é a tecla que o copia |
| **Awake** | `⌘⇧X` | Mantém a tela acesa por um prazo escolhido |
| **Echo** | `⌘⇧E` | Grava reunião, separa sua voz da dos outros, transcreve e resume localmente (macOS 26) |

Além dos painéis, existe o **Hub**: uma janela normal com a lista de módulos à
esquerda e as preferências do módulo selecionado à direita.

### Contexto comercial

- Vai para a **Mac App Store**, pago.
- Estratégia: **preço baixo, volume alto**. Precisa converter na primeira
  impressão da screenshot da loja.
- Não é app pesado nem "enterprise": é utilitário de bolso, usado por segundos
  de cada vez, o dia inteiro.

---

## 2. O pedido de design

O que existe hoje **funciona e é consistente**, mas parece **"blocado" e
amador**: retângulos escuros empilhados, cinzas muito próximos entre si, pouca
sensação de material, pouca profundidade, pouca personalidade. Parece um
wireframe pintado de preto.

O que se quer:

- Mais **bonito, moderno e profissional** — algo que dê vontade de comprar ao
  ver uma screenshot.
- Referência estética: **o próprio macOS**. É app Mac-only, então pode e deve
  parecer parte do sistema — materiais translúcidos, vibrancy, sombras de
  janela, o vocabulário visual do Sonoma/Sequoia/Tahoe, controles do sistema.
  Espírito de Raycast, Linear, Things 3, Craft, CleanShot X.
- Pode explorar **gradiente**, desde que sirva à profundidade e não à
  decoração. Se não ficar bom, ignorar — chapado bem resolvido > gradiente
  genérico.
- **Manter a paleta base** (verde + neutros escuros): o dono gosta dela. O
  problema é como ela está aplicada, não quais cores são.

### Restrições que não mudam

- **Dark-only** (light mode é dívida assumida, não esquecida).
- **Flutter puro** sempre que possível; nativo só quando não houver saída.
- **Custo de render importa**: blur permanente em superfície sempre visível é
  caro. Blur em painel que vive 200ms, não. Hoje a "luz" do fundo é um
  `RadialGradient` justamente para evitar `BackdropFilter`.
- Motion curto: entrada de painel 120ms, hover 90ms, **saída sem animação**.
- Teclado antes de mouse: todo estado precisa de foco visível.
- Ícones são **paths customizados**, não Material Icons.
- Densidade desktop: linha de lista tem 34px de altura, corpo em 13–14px.
  Nada de card espaçado estilo mobile.

---

## 3. Dimensões reais

### Janelas

| Janela | Dimensão | Observações |
|---|---|---|
| **Janela flutuante (overlay)** | `920 × 800` | Transparente, borderless, sem chrome, sempre no topo, visível em todos os Spaces. É maior que qualquer painel só para caber a sombra de 60px de blur sem corte. Compartilhada pelos 5 módulos. |
| Posição do overlay | centro óptico em **42% da altura útil** da tela | Um pouco acima do centro, como o Spotlight. Todos os painéis nascem no mesmo ponto. |
| **Hub** | `880 × 620` | Janela normal, redimensionável, abre centralizada na tela onde está o cursor. |
| Hub + região de leitura | `880 + 480 = 1360` de largura | A janela **cresce para o lado** quando o Echo abre uma reunião; volta ao fechar. |

### Painéis flutuantes (centralizados na janela de 920×800)

| Painel | Largura | Altura |
|---|---|---|
| **Pin** — só lista | `420` | até `460` (máx.) |
| **Pin** — com preview | `560` (lista compacta de `210` + preview) | até `460` |
| **Focus** | `380` | intrínseca |
| **Awake** | `380` | intrínseca |
| **Echo** | `380` | intrínseca |
| **Leaf** (parede 3×3) | `778` | `706` com as nove vagas ocupadas |
| Diálogo de sessão do Focus | `420` | intrínseca |

### Peças internas

| Peça | Medida |
|---|---|
| Sidebar do Hub | `260` de largura |
| Região de leitura (Echo) | `480` de largura |
| Padding do conteúdo do Hub | `32` nas laterais/topo, `48` no rodapé |
| Linha de lista (Pin, Focus, Echo) | `34` de altura |
| Cartão do Leaf | `236 × 200`, gap `14`, 9 linhas de conteúdo |
| Badges de ícone | `28` (em linha) · `36` (em bloco) · `40` (estado vazio) |
| Padding do botão | `16 × 8`, radius `8` |

---

## 4. Paleta atual ("Dark Premium")

Cor literal só existe neste arquivo; todo o resto referencia token.

### Superfícies

| Token | Hex | Uso |
|---|---|---|
| `background` | `#0B0B0B` | Fundo da janela / overlay |
| `backgroundTop` | `#12140F` | Topo do gradiente de fundo — preto com toque quase imperceptível de verde |
| `backgroundDeep` | `#080808` | Base do gradiente — vinheta sutil embaixo |
| `surface` | `#141414` | Painel e card principal |
| `sidebar` | `#141414` a **72%** | Sidebar do Hub, translúcida sobre o gradiente |
| `surfaceTop` | `#191B17` | Topo do gradiente de superfície do painel flutuante |
| `card` | `#1A1A1A` | Campos, cards internos, badges |
| `hover` | `#232323` | Hover neutro |
| `pressed` | `#2E2E2E` | Um degrau acima do hover |
| `border` | `#262626` | Bordas sutis de 1px |

### Acento e estado

| Token | Hex | Uso |
|---|---|---|
| `greenPrimary` | `#22C55E` | Ação primária, foco, item fixado |
| `greenLight` | `#4ADE80` | Hover do primário, acentos, texto selecionado |
| `greenDeep` | `#16A34A` | Pressed do primário, borda de card selecionado |
| `selection` | `#22C55E` a **14%** (`0x2422C55E`) | Linha/item selecionado |
| `focusRing` | `#22C55E` a **60%** (`0x9922C55E`) | Anel de foco de teclado |
| `textSelection` | `#22C55E` a **25%** (`0x4022C55E`) | Trecho selecionado dentro de campo |
| `error` | `#EF4444` | Ações destrutivas |
| `warning` | `#F59E0B` | Alertas |

### Texto

| Token | Hex | Uso |
|---|---|---|
| `textPrimary` | `#F5F5F5` | Texto principal |
| `textSecondary` | `#9CA3AF` | Metadados e labels de apoio |
| `textTertiary` | `#6B7280` | Placeholders, timestamps, terceiro nível |

### Elevação

| Token | Valor |
|---|---|
| `shadow` | `rgba(0,0,0,0.55)` |
| Sombra do painel flutuante | `0 24px 60px rgba(0,0,0,0.55)` |
| Sombra de dropdown | `0 20px 50px rgba(0,0,0,0.55)` |
| Anel de foco | 2px de spread, sem blur, em `focusRing` (não empurra o layout) |
| `scrim` (véu de modal) | `rgba(0,0,0,0.6)` |

### Gradientes existentes

- **`windowBackground`** — vertical: `#12140F` → `#0B0B0B` (55%) → `#080808`.
  Variação de 3–4% de luminância; existe só para evitar "preto blocado".
- **`windowGlow`** — radial ancorado **acima** do topo da janela (`-0.35, -1.15`,
  raio 1.25): `greenPrimary` a 6% → transparente. Simula luz difusa sem custo de
  `BackdropFilter`.
- **`panelSurface`** — vertical: `#191B17` → `#141414` (60%). Painel flutuante
  "iluminado por cima".

> Esse é exatamente o ponto em que o gradiente pode crescer, se ficar bom: hoje
> ele é tão tímido que quase não se lê como material.

---

## 5. Tipografia

Fonte: **Inter**, com fallback `SF Pro Display` → `SF Pro Text` →
`.AppleSystemUIFont` → `Helvetica Neue`. Escala curta e desktop — o maior estilo
do app tem 17px (não existe "hero" em utilitário).

| Estilo | Tamanho / peso | Uso |
|---|---|---|
| `screenTitle` | 17 / 600, tracking -0.2 | Cabeçalho de tela do Hub |
| `sectionTitle` | 15 / 600 | Cabeçalho de seção |
| `panelTitle` | 15 / 600 | Título de painel compacto |
| `body` | 14 / 400 | Corpo padrão |
| `bodyEmphasis` | 14 / 500 | Título dentro de linha, valor vs. rótulo |
| `bodyStrong` | 14 / 600, tracking -0.2 | Nome próprio em linha (a marca na sidebar) |
| `reading` | 14 / 400, entrelinha 1.65 | Leitura longa (transcrição do Echo) |
| `bodyCompact` | 13 / 400 | Variante compacta do overlay |
| `bodyCompactEmphasis` | 13 / 500 | Título de linha de lista, rótulo de config |
| `caption` | 13 / 400, `textSecondary` | Texto secundário |
| `captionSmall` | 12 / 400, `textSecondary` | Metadado em list item |
| `captionSmallEmphasis` | 12 / 600 | Opção escolhida do segmented control |
| `captionXS` | 11 / 400, `textSecondary` | Timestamp, dica de atalho, subtítulo |
| `overline` | 11 / 600, tracking 0.66, caixa alta | Header de seção |
| `button` | 14 / 600 | Label de botão |
| `timer` | **36 / 500**, tracking -0.5, dígitos tabulares | Contagem do Focus — a única exceção de escala; o número *é* a tela |
| `mono` / `monoSmall` | SF Mono 12 / 11 | Key-caps e preview de comandos |

Regra vigente: `copyWith` em estilo de texto só vale para cor. Peso e tamanho
são degraus da escala — degrau que falta entra na escala com nome.

---

## 6. Espaçamento, raios, motion

**Raios** (escala deliberadamente baixa — radius alto puxa para "app mobile
consumer"): painel/modal `12` · card `8` · botão/campo `8` · list item `6` ·
badge `6` · badge pequeno `4`.

**Espaçamento** (múltiplos de 4 com nome): `1` hairline · `2` · `4` · `6` · `8`
· `10` · `14` · `16` · `20` · `24` · `32` · `48` (máximo, usado com parcimônia).

**Ícones**: `13` metadado · `14` com rótulo · `15` padrão da interface · `16`
sozinho · `18` dentro de badge grande.

**Opacidades de estado**: `0.4` desabilitado · `0.55` módulo ainda não lançado.

**Durações**: `90ms` micro-feedback (hover, pressed, foco) · `150ms` transição
de estado pequena · `120ms` entrada de superfície flutuante · `220ms` layout ·
curva `easeOutCubic`. **Saída não tem duração** — fechar é instantâneo, sempre.
`pressed` entra sem transição; só a volta ao repouso ganha easing.

---

## 7. Matriz de estados (`EgSurfaceStyle`)

Todo elemento clicável do app resolve sua aparência por esta tabela, nunca por
`if` dentro do widget.

**Precedência, do mais forte ao mais fraco:**

| Estado | Vence quem | Por quê |
|---|---|---|
| `disabled` | todos | o controle não responde: nenhum outro estado é verdade |
| `selected` | pressed, hover, focus | é onde o teclado está — a informação mais durável da tela |
| `pressed` | hover, focus | feedback do clique acontecendo agora |
| `hover` = `focus` | rest | mesma superfície; o que separa os dois é o anel de foco |
| `rest` | — | repouso |

`selected` e `hover` **nunca** são a mesma cor: seleção é accent em baixa
opacidade, hover é neutro. Desabilitado **não** muda de superfície — só a
opacidade do conteúdo cai.

**As seis colunas existentes:**

| Coluna | rest | hover | pressed | selected | foreground | borda |
|---|---|---|---|---|---|---|
| `row` (lista, sidebar, menu) | transparente | `#232323` | `#2E2E2E` | verde 14% | `#F5F5F5` → `#4ADE80` selecionado | — |
| `ghost` (botão de ícone) | transparente | `#232323` | `#2E2E2E` | — | `#9CA3AF` → `#F5F5F5` no hover | — |
| `segment` (pílula) | transparente | `#232323` | `#2E2E2E` | verde 14% | `#9CA3AF` → `#4ADE80` selecionado | — |
| `card` (cartão do Leaf) | `#1A1A1A` | `#232323` | `#2E2E2E` | verde 14% | `#F5F5F5` | `#262626` → `#16A34A` selecionado |
| `primary` | `#22C55E` | `#4ADE80` | `#16A34A` | — | `#0B0B0B` | — |
| `secondary` | `#1A1A1A` | `#232323` | `#2E2E2E` | — | `#F5F5F5` | `#262626` |
| `destructive` | `#1A1A1A` | `#232323` | `#2E2E2E` | — | `#EF4444` | `#262626` |

> A folha visual com todos esses estados lado a lado existe como golden em
> `test/goldens/design_state_matrix.png`.

---

## 8. Componentes já existentes (prefixo `Eg`)

O app **já está componentizado** — mexer no design system reflete em tudo.

| Componente | Papel |
|---|---|
| `EgSurface` / `EgInteractiveSurface` | A caixa pintada pela matriz de estado. Base de todo clicável. |
| `EgSurfaceStyle` | As colunas da matriz acima. |
| `EgHoverable` | Detecção de hover/press/foco. |
| `EgPanel` | Superfície base de painel: `surface`, borda 1px, radius 12, sombra flutuante, gradiente opcional. |
| `EgOverlayShell` | Casca dos 5 painéis flutuantes: fade de entrada, clique fora fecha, blur confirmado fecha, painel centralizado. |
| `EgBackground` | Fundo da janela: `windowBackground` + `windowGlow`. |
| `EgButton` | 3 variantes: primary, secondary, destructive. Geometria única (16×8, radius 8). |
| `EgIcon` / `EgIconBadge` | Ícones em path customizado (document, link, terminal, search, star, plus, close, gear, trash, clipboard, timer, sun, note, microphone…). |
| `EgTextField` / `EgSearchField` | Campo de texto e campo de busca. |
| `EgToggle` | Chave liga/desliga. |
| `EgSegmentedControl` | Pílulas de escolha. |
| `EgSettingsSection` / `EgSettingsRow` / `EgSectionLabel` | Blocos das telas de preferências do Hub. |
| `EgNavTile` | Item da sidebar de módulos. |
| `EgHintBar` / `EgKeyCap` | Barra de dicas com key-caps no rodapé dos painéis. |
| `EgEmptyState` | Estado vazio. |
| `EgConfirmDialog` | Confirmação destrutiva. |
| `EgCountdown` | Contagem regressiva do Focus/Awake. |

---

## 9. Telas que existem hoje

Cada uma tem um golden de referência em `test/goldens/`:

**Painéis flutuantes**
- `pin_overlay_list` · `pin_overlay_preview`
- `focus_overlay_idle` · `focus_overlay_running`
- `leaf_overlay_wall` · `leaf_overlay_editing`
- `awake_overlay_idle` · `awake_overlay_running`
- `echo_overlay_idle` · `echo_overlay_recording`

**Hub**
- `hub_pin_settings` · `hub_focus` · `hub_focus_session` · `hub_leaf` ·
  `hub_awake` · `hub_echo` · `hub_echo_transcript` · `hub_app_settings`

**Design system**
- `design_state_matrix`

---

## 10. Microcópia atual (pt-BR)

O tom é direto, sem entusiasmo de marketing, sem exclamação, sem "Ops!".
Explica a consequência, não o mecanismo.

**Ações e rótulos**
`Iniciar foco` · `Iniciar pausa` · `Pausar` · `Encerrar` · `Copiar` ·
`Fixar (⌘P)` · `Desafixar (⌘P)` · `Excluir` · `Apagar` · `Limpar` ·
`Esvaziar` · `Fechar (esc)` · `Abrir no Hub` · `Abrir preferências` ·
`Gravar reunião` · `Parar e transcrever` · `Gravar de novo` · `Refazer resumo` ·
`Manter a tela acesa` · `Desligar` · `Permitir`

**Cabeçalhos de seção**
`Geral` · `Funcionalidades` · `Permissões` · `Gravação` · `Histórico` ·
`Fixados` · `Recentes` · `Anotações` · `Parede` · `Dentro do painel` ·
`Antes de gravar` · `Preferências do aplicativo`

**Preferências**
`Atalho global` — "Funciona com qualquer aplicativo em foco."
`Iniciar com o macOS` — "O Evergreen sobe junto com o sistema."
`Abrir minimizado` — "Fica só na barra de menus, sem abrir janelas."
`Colar automaticamente` — "Ao escolher um item, cola direto no app anterior (⌘V)."
`Itens mantidos` — "Itens fixados nunca são removidos."
`Duração padrão` — "Duração de uma sessão."
`Perguntar a atividade ao iniciar` · `Pedir um resumo ao terminar` ·
`Avisar na tela` — "O som de alerta do próprio macOS."
`Idioma da transcrição` · `Como você quer o resumo`

**Perguntas ao usuário**
`Em que você vai trabalhar?` · `O que você fez?` · `Anotar o que aconteceu` ·
`Apelido para achar depois` · `Buscar no histórico`

**Estados vazios**
`Nenhum item ainda` · `Nenhum resultado` — "Nada no histórico corresponde à sua
busca." · `Nenhuma sessão esta semana` · `Nenhuma reunião gravada` ·
`Nenhuma anotação nesta sessão.` · "As sessões concluídas aparecem aqui, com o
que você anotou."

**Destrutivos (diálogo de confirmação)**
`Apagar sessão?` — "A sessão e o que você anotou nela serão removidos. Não dá
para desfazer."
`Limpar histórico?` — "Remove todos os itens não fixados."
`Esvaziar a parede?` — "Remove as 9 anotações de uma vez."

**Erros e permissões**
`Não deu certo` · `Nenhuma fala` — "A gravação saiu muda — confira o microfone e
a saída de áudio" · `Permissão de Acessibilidade` — "Requer permissão de
Acessibilidade do macOS." · `Gravação de Tela` — "Dá acesso ao áudio da reunião
— a fala das outras pessoas." · `Microfone` — "Grava a sua voz."

**Estados em andamento**
`Gravando` · `Pausado` · `Pausa concluída` · `Pode levar alguns minutos` ·
`Resumindo — bloco 2 de 7` · `Fechar o painel não para a gravação`

---

## 11. O que avaliar na proposta

1. **Ela sobrevive à screenshot da App Store?** É por ela que a venda acontece.
2. **Ela ainda parece um app do Mac**, não um dashboard web escuro?
3. **O gradiente (se houver) significa alguma coisa** — profundidade, foco,
   estado — ou está lá só porque é bonito?
4. **A densidade continua desktop?** Linha de 34px, corpo de 13–14px, sem card
   dentro de card.
5. **Os cinco estados continuam distinguíveis** — e seleção continua diferente
   de hover?
6. **Custa caro por frame?** Blur permanente em superfície sempre visível é o
   principal risco.
7. **A primeira impressão é "que rápido", não "que bonito"?** — mas desta vez
   sem parecer inacabado.

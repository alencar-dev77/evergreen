# Prompt de redesign visual — Evergreen (macOS) · v2

> **Como usar:** cole este documento inteiro numa sessão de design. Ele contém
> (1) o produto, (2) a stack e o que ela permite de verdade, (3) o **estado
> atual exportado** — dimensões reais, tokens, componentes, regras — e (4) o
> pedido. Tudo nas seções 1–3 é **o que existe hoje**, não é a proposta.
>
> Supersede `docs/brief-redesign-visual.md` (v1, escrito quando eram 5 módulos
> e não existiam Nest, Track, temas nem a região de leitura do Hub).

---

# 1. O produto

**Evergreen** é uma suíte pessoal de produtividade para **macOS**, feita em
Flutter, que roda como **agente da barra de menus** (`LSUIElement`): sem janela
ao iniciar, sem ícone no Dock. Tudo é local — nada sai para a internet, não há
backend, não há conta, não há sync.

São **sete módulos**. Seis têm painel flutuante com atalho global; um só existe
dentro do Hub.

| Módulo | Atalho | O que faz |
|---|---|---|
| **Pin** | `⌘⇧C` | Gerenciador de área de transferência: histórico local, busca instantânea, itens fixados, cola direto no app anterior. Tem um gerador de CPF/CNPJ embutido na lista. |
| **Focus** | `⌘⇧F` | Cronômetro de foco/pausa, com registro do que foi feito em cada sessão e histórico. |
| **Leaf** | `⌘⇧D` | Parede de até 9 anotações curtas, todas à vista; o número do cartão é a tecla que o copia. |
| **Awake** | `⌘⇧X` | Mantém a tela acesa (ou só o sistema acordado) por um prazo escolhido. |
| **Echo** | `⌘⇧E` | Grava reunião, separa a sua voz da dos outros, transcreve e resume localmente (exige macOS 26 + Apple Intelligence). |
| **Nest** | `⌘⇧R` | Prateleira que junta arquivos de várias pastas e manda todos para uma só. Abre também **chacoalhando o arquivo no meio do arraste**. |
| **Track** | — | Reconstrói o dia a partir do que os outros módulos gravaram. Só lê; só existe no Hub, sem painel e sem atalho. |

Além dos painéis existe o **Hub** (`⌘⇧,`): janela normal, com a lista de módulos
à esquerda e as preferências do módulo selecionado à direita. Alguns módulos
abrem ainda uma **terceira região** à direita, para leitura longa (a reunião do
Echo, a sessão do Focus, o dia do Track) — a janela **cresce** para caber a
região, em torno do próprio centro, em vez de dividir o que já existe.

### Contexto comercial

- Vai para a **Mac App Store**, pago, preço baixo e volume alto.
- Precisa **converter na primeira impressão da screenshot da loja**.
- Não é app pesado nem "enterprise": é utilitário de bolso, usado por segundos
  de cada vez, o dia inteiro, sempre por atalho de teclado.

---

# 2. A stack — o que dá para fazer, o que não dá

Isto não é contexto: é o mapa do que é fisicamente possível. Uma proposta que
ignore esta seção não é implementável.

## 2.1 O que é

- **Flutter** (Dart SDK ^3.11.5), app desktop macOS nativo. **Não é web.** Não
  existe CSS, não existe `backdrop-filter` de graça, não existe SVG no runtime.
- **Riverpod** (`flutter_riverpod` ^3.3.2), padrão MVVM. Regra de ouro do
  projeto: **nenhuma lógica de negócio em widget**.
- **SQLite direto** (`sqlite3`), sem ORM, atrás de repositórios.
- **`desktop_multi_window`** — o Hub roda num engine Flutter próprio, separado
  da janela flutuante.
- **`window_manager`, `tray_manager`, `hotkey_manager`, `screen_retriever`** —
  janela, ícone da barra de menus, atalho global.
- **Swift/AppKit** onde o Flutter não alcança: `IOPMAssertion` (Awake),
  `ScreenCaptureKit` + `Speech` + `FoundationModels` (Echo), `QLThumbnail` +
  arraste do Finder (Nest), geometria de janela e o `NSPanel` não-ativante.
- Fonte: **Inter**, com fallback `SF Pro Display / SF Pro Text /
  .AppleSystemUIFont / Helvetica Neue`. Mono: **SF Mono**, fallback Menlo.

## 2.2 O que a stack **permite** e hoje é pouco usado

Espaço real de manobra para o redesign:

- **`BackdropFilter` com `ImageFilter.compose`** — blur + matriz de saturação. Já
  existe pronto no projeto (`AppMaterials.panelVibrancy`, blur 40 + saturate
  160%), e hoje **o tema em uso não liga isso** (`usesVibrancy: false`). Vibrancy
  de verdade, à la macOS, está a um token de distância.
- **Gradientes** (`LinearGradient`, `RadialGradient`, `SweepGradient`) em fundo,
  superfície, borda e texto (`ShaderMask`). A infra já existe em `EgGradients`;
  o tema atual passa `accentGradient: null` e `selectionGradient: null` — ou
  seja, **os degradês estão desligados por decisão, não por falta de suporte**.
- **`CustomPainter` / `Path`** — qualquer desenho. Os ícones já são paths em
  Dart (`EgIcon`), não uma fonte de ícones. Dá para desenhar glifos novos,
  gráficos, medidores, texturas, ruído, malha, o que for.
- **`ShaderMask`, `ImageFilter.blur` em elemento arbitrário, `ColorFilter`,
  `BlendMode`** — brilho, glow, borda iluminada, máscara de degradê.
- **Sombras múltiplas empilhadas** por elemento (já usadas no painel flutuante).
- **`AnimatedContainer`, `TweenAnimationBuilder`, `AnimationController`,
  implicit + explicit** — motion arbitrário, incluindo spring.
- **Fragment shaders GLSL** (`FragmentProgram`) — possível, ainda não usado.
- **Bordas arredondadas contínuas de verdade**: existe
  `ContinuousRectangleBorder` no Flutter, e dá para escrever um squircle
  Apple-fiel com `Path`. Hoje o app usa só `BorderRadius.circular` (arco
  circular), que é justamente uma das razões da queixa de "quadrado".
- **Tipografia variável**: Inter tem eixo de peso; `FontFeature` e
  `FontVariation` estão disponíveis (tabular figures já é usado no cronômetro).

## 2.3 O que a stack **proíbe** ou cobra caro

- **Blur permanente custa caro.** Um `BackdropFilter` recompõe tudo atrás dele a
  cada quadro. É aceitável num painel que vive 3 segundos; é caro numa sidebar
  que fica na tela o tempo todo. Se a proposta quiser vibrancy na sidebar, tem
  de ser assumido explicitamente como custo.
- **Só a janela 0 pode ser borderless / sempre no topo.** Todos os painéis
  flutuantes compartilham a mesma janela nativa; o painel é escolhido no lado
  Dart. Uma proposta com "duas janelas flutuantes ao mesmo tempo" está fora.
- **A janela flutuante não é redimensionável** e o painel é centralizado dentro
  dela. Painel muda de tamanho por layout Flutter, não por resize de janela.
- **Nada de Material Design.** O app usa `Scaffold` como casca, mas nenhum
  componente Material: sem `Card`, `ElevatedButton`, `ListTile`, `AppBar`,
  `Icons`. Tudo é componente próprio com prefixo `Eg`.
- **Sem imagem de bitmap decorativa.** Não há pipeline de asset de imagem no
  app (os únicos `.png` são o ícone do app e o da barra de menus, e são
  **gerados** a partir de um `CustomPainter`). Textura tem de ser desenhada em
  código.
- **Sem modo claro.** O app é dark-only hoje. Propor modo claro é possível, mas
  é escopo extra e não está pedido.
- **Todo valor visual tem de virar token.** Widget não pode conter literal de
  cor, raio ou sombra. Ver 3.9.

---

# 3. Estado atual exportado

## 3.1 Dimensões reais

### Hub (janela normal, `desktop_multi_window`)

| Medida | Valor |
|---|---|
| Tamanho de conteúdo inicial | **880 × 620 pt** |
| Mínimo | **720 × 480 pt** |
| Sidebar | **260 pt** de largura, fixa |
| Padding da área de conteúdo | `32` topo/esq/dir, `48` embaixo |
| Vão entre cabeçalho e conteúdo | `24` |
| Piso da área de conteúdo | **560 pt** (abaixo disso as linhas de configuração estouram) |
| Região de leitura (3ª coluna) | **480 pt** preferidos, cede até 0 se a janela não couber |
| Mínimo com região aberta | `720 + 480`, limitado pela tela |
| Rodapé da sidebar | linha "Evergreen · Preferências do aplicativo" + versão (`v0.15.0`) |

A janela cresce/encolhe **animada em 220 ms**, em torno do próprio centro, e o
lado nativo guarda o que a tela não deixou crescer para devolver no fechamento.

### Janela flutuante (janela 0 — `NSPanel` não-ativante, transparente, frameless)

| Medida | Valor |
|---|---|
| Tamanho da janela | **920 × 800 pt**, fixo, transparente |
| Centro óptico na tela | **42%** da altura útil (acima do centro, como o Spotlight) |
| Por que tão grande | acomodar a sombra de 60 px de blur sem corte; os painéis são centralizados dentro dela |

### Painéis, um a um

| Painel | Largura | Altura |
|---|---|---|
| **Pin** (só lista) | **420** | até **460** |
| **Pin** (com preview) | **560** | até **460** (lista compacta = 210) |
| **Focus** | **380** | conteúdo (log até 96) |
| **Awake** | **380** | conteúdo |
| **Echo** | **380** | conteúdo |
| **Nest** | **420** | conteúdo |
| **Leaf** | ~**778 × 706** | grade 3×3 de cartões **236 × 200** |

Alturas de linha padronizadas: linha de lista do Pin, do Echo, do Focus, do
Track e do Nest = **34 pt**. Cartão do Nest = 44. Barra do Track = 28.

## 3.2 Paleta — tema `evergreen` (o único que importa)

> O app tem dois temas (`evergreen` e `apple`), mas a **escolha de aparência
> está desligada por feature flag** e o app roda sempre no `evergreen`.
> **Ignore o tema `apple` por completo.** As cores abaixo são as que o dono
> gosta e quer manter como base.

```
background        #0B0B0B    fundo da janela
backgroundTop     #12140F    topo do degradê de fundo (verde quase imperceptível)
backgroundDeep    #080808    base do degradê de fundo
surface           #141414    superfície de painel
surfaceTop        #191B17    topo do degradê de superfície
surfaceFloating   #141414    painel flutuante (opaco — sem vidro hoje)
sidebar           #141414 a 72%  (0xB8141414)
card              #1A1A1A
cardTop           #1F1F1F
control           #1A1A1A
hover             #232323
pressed           #2E2E2E
border            #262626
borderHighlight   #FFFFFF a 6%  (0x0FFFFFFF)

accent            #22C55E    verde da casa
accentLight       #4ADE80
accentDeep        #16A34A
accentShade       #15803D
accentGradient    null       ← degradê desligado por decisão
onAccent          #0B0B0B    texto sobre o accent

selection         #22C55E a 14%  (0x2422C55E)   + aresta de 3 px à esquerda
selectionLabel    #4ADE80    o rótulo da linha selecionada é verde, não branco
focusRing         #22C55E a 60%  (0x9922C55E), anel de 1 px sem blur

textPrimary       #F5F5F5
textSecondary     #9CA3AF
textTertiary      #6B7280
textQuaternary    #9CA3AF a 35%
textSelection     #22C55E a 25%

error             #EF4444
warning           #F59E0B
shadow            #000 a 55%
shadowContact     #000 a 40%
scrim             #000 a 60%

systemBlue        #3B82F6   (cores de "sistema" traduzidas para a paleta da casa)
systemIndigo      #6366F1
systemTeal        #2DD4BF
systemGray        #6B7280
```

**Diagnóstico honesto da paleta aplicada:** os neutros vivem todos entre `#0B` e
`#2E`. Entre `background` (#0B0B0B), `surface` (#141414), `card` (#1A1A1A) e
`control` (#1A1A1A) há uma diferença de luminância pequena demais para separar
camadas — daí a impressão de "retângulos escuros empilhados". O verde é o único
acento e aparece em muitos papéis diferentes (seleção, toggle ligado, botão
primário, rótulo selecionado, anel de foco, glifo da marca), o que dilui o
significado dele.

## 3.3 Tipografia (escala fechada — degrau que falta tem de nascer com nome)

| Papel | Tamanho | Peso | Extras |
|---|---|---|---|
| `screenTitle` | 17 | 600 | tracking −0.2, altura 1.3 |
| `sectionTitle` / `panelTitle` | 15 | 600 | 1.3 |
| `body` | 14 | 400 | 1.4 |
| `bodyEmphasis` | 14 | 500 | 1.4 |
| `bodyStrong` | 14 | 600 | tracking −0.2 |
| `reading` | 14 | 400 | **altura 1.65** (leitura longa) |
| `bodyCompact` | 13 | 400 | 1.4 |
| `bodyCompactEmphasis` | 13 | 500 | 1.4 |
| `caption` | 13 | 400 | 1.5, cor secundária |
| `captionSmall` | 12 | 400 | secundária |
| `captionSmallEmphasis` | 12 | 600 | secundária |
| `captionXS` | 11 | 400 | secundária |
| `overline` | 11 | 600 | **tracking +0.66**, secundária — é o rótulo de seção |
| `button` | 14 | 600 | 1.2 |
| `timer` | 36 | 500 | tracking −0.5, **tabular figures** |
| `mono` / `monoSmall` | 12 / 11 | — | SF Mono |

Regra vigente: `copyWith` em estilo de texto **só para cor**. Peso e tamanho são
degraus da escala.

**Diagnóstico:** o topo da escala é 17 pt. O título de tela, o de seção e o de
painel são praticamente o mesmo tamanho (17/15/15). Não existe um degrau
"display" — nenhuma tela tem um ponto de entrada tipográfico. Isso é uma das
razões de tudo parecer ter o mesmo peso.

## 3.4 Formas e medidas de componente

```
radiusPanel      12      radiusCard    8       radiusControl  8
radiusRow         6      radiusSmall   4       hairline       1
rowPaddingV       8      rowPaddingH  10
panelPadding     16      listPadding  16
controlHeight    36
switch           36 × 21, botão 15
selectionEdge     3      (a aresta vertical accent da linha selecionada)
```

Todos os raios usam `BorderRadius.circular` — **arco circular, não squircle**.
Com raio 6 a 12 num app cuja referência é o macOS (que usa raios contínuos e
maiores), esta é provavelmente **a causa técnica número um da queixa de
"quadrado"**.

## 3.5 Espaçamento e ícones

```
hairline 1 · xxxs 2 · xxs 4 · xs 6 · sm 8 · md 10 · lg 14
xl 16 · xxl 20 · xxxl 24 · huge 32 · giant 48
```

Ícones: `xs 13 · sm 14 · md 15 · lg 16 · xl 18`
Badges quadrados de ícone: `sm 28 · md 36 · lg 40`
Opacidades: `disabled 0.4 · unavailable 0.55`

## 3.6 Motion (estático, igual em qualquer tema — só a curva é do tema)

```
instant   90 ms   hover, pressed, anel de foco
fast     150 ms   troca de estado pequena
entrance 120 ms   entrada de painel flutuante  (a SAÍDA é instantânea, sempre)
medium   220 ms   layout, crescimento da janela
settle    60 ms   o único spring do app: a lâmina da marca passa 5° e volta
curva    easeOutCubic
```

## 3.7 Elevação

```
floatingPanel  = [ #000@55%  blur 60  y+24  spread −12 ]
                 [ #000@40%  blur 12  y+4   spread −6  ]
dropdown       = [ #000@55%  blur 24  y+8   spread −8  ]
control        = []            ← botão daqui não levanta do fundo
focusRing      = [ #22C55E@60%  blur 0  spread 1 ]
panelInnerHairline = null      ← sem a linha interna de luz do macOS
controlHighlight   = null
```

## 3.8 Degradês existentes (`EgGradients`)

- `windowBackground` — vertical `backgroundTop → background → backgroundDeep`
  (0 / 0.55 / 1)
- `windowGlow` — radial accent a 12% em `(-0.35, -1.15)`, raio 1.45
- `panelSurface` — `surfaceTop → surface`
- `cardSurface` — `cardTop → card`
- `onboardingStage` — diagonal `backgroundDeep → background → accentShade`

São todos de amplitude baixíssima (2–5 pontos de luminância) — na prática não se
veem.

## 3.9 Arquitetura de tema (importa para a proposta ser implementável)

- Existe uma classe de tokens (`EgTokens`) exposta por `context.eg`:
  `context.eg.colors.accent`, `context.eg.text.body`,
  `context.eg.shapes.radiusCard`, `context.eg.elevations.floatingPanel`,
  `context.eg.motion.fast`, `context.eg.gradients.panelSurface`,
  `context.eg.surfaces.row`.
- **Todo campo dos tokens é `required`** — papel novo tem de nascer nos dois
  arquivos de tema ao mesmo tempo; é o compilador que cobra.
- Literal de cor só existe em `lib/core/design/themes/`.
- Estado interativo vem de uma **matriz** (`EgSurfaceStyle`), nunca de `if`s no
  widget: `rest / hover / pressed / selected / focused / disabled`, com
  precedência fixa (`disabled` > `selected` > `pressed` > `hover|focused` >
  `rest`). Estilos prontos: `row`, `ghost`, `segment`, `card`, `primary`,
  `secondary`, `destructive`.
- A folha visual de todos os estados é um golden:
  `test/goldens/design_state_matrix_evergreen.png`.

## 3.10 Componentes existentes (`lib/shared/widgets/`, prefixo `Eg`)

`EgBackground` · `EgBrandMark` (o canivete — marca do app, desenhada em Dart, de
onde saem o ícone do app e o da barra de menus) · `EgButton` (primary /
secondary / destructive) · `EgConfirmDialog` · `EgCountdown` · `EgDayBars` ·
`EgEmptyState` · `EgHintBar` (a barra de teclas no rodapé dos painéis) ·
`EgHoverable` (quem carrega toda a semântica de acessibilidade) · `EgIcon`
(paths customizados) · `EgKeyCap` · `EgNavTile` · `EgOverlayShell` (casca de
painel flutuante: entrada animada, barreira, foco, arraste opcional) · `EgPanel`
· `EgSearchField` · `EgSectionLabel` · `EgSegmentedControl` · `EgSettingsRow`
(+ variante `.field`) · `EgSettingsSection` / `EgSettingsPage` ·
`EgShortcutRecorder` · `EgSpinner` · `EgSurface` / `EgInteractiveSurface` ·
`EgTextField` · `EgToggle`

## 3.11 Regras de layout e produto em vigor

Não são invioláveis — mas cada uma existe por uma razão que a proposta precisa
resolver de algum jeito, mesmo que diferente:

1. **Ordem fixa de tópicos numa tela de preferência:** o que aconteceu (lista do
   módulo) → o que ele faz (interruptores primeiro, depois seletores, campos de
   texto por último) → limites e ações destrutivas → atalho global → permissões.
2. **Todo módulo liga e desliga**, e o interruptor mestre é a primeira seção de
   toda tela de módulo, igual nos sete.
3. **Conteúdo longo abre na região do Hub** — nunca em janela nova, nunca em
   modal. Modal é só para pergunta de sim/não.
4. **Teclado é a interface primária.** Todo painel tem barra de teclas no
   rodapé; `Esc` sempre fecha; `⌘1..⌘9` e `⌥1..⌥9` são camadas reais em Pin,
   Leaf e Nest.
5. **Seleção = fundo accent 14% + aresta de 3 px à esquerda**, a mesma em linha
   de lista, item de sidebar e cartão do Leaf.
6. **Densidade sobre respiro** na lista: linha de 34 pt, porque cartão espaçado
   obriga a rolar mais para ver o mesmo.
7. **Estado vazio** tem badge de ícone 40 + texto centralizado.
8. Existem 3 feature flags desligadas hoje: `themes` (escolha de aparência),
   `intro` (abertura animada do Hub) e `onboarding` (boas-vindas).

## 3.12 Referências visuais do estado atual

As screenshots reais do app estão em `test/goldens/`. As mais representativas:

- `hub_pin_settings.png` — Hub, tela de preferências típica
- `hub_track_day.png` — Hub com as três colunas (sidebar + conteúdo + leitura)
- `hub_echo.png` — Hub com lista + preferências no mesmo scroll
- `pin_overlay_preview.png` — painel flutuante mais complexo (lista + preview)
- `leaf_overlay_wall.png` — a parede 3×3
- `design_state_matrix_evergreen.png` — a folha de todos os estados
- `focus_overlay_running.png`, `awake_overlay_running.png`,
  `nest_overlay_filled.png`, `echo_overlay_recording.png` — os painéis simples

---

# 4. O pedido

## 4.1 O diagnóstico do dono

> "Não gosto muito desse layout, acho que fica tudo muito quadrado, não tô
> achando *clean*. Tá até legalzinho, mas acho que pode melhorar pra aparecer
> numa Apple Store, quero mais profissional."

Traduzindo em sintomas verificáveis nas screenshots:

1. **Quadrado.** Raios de 6–12 em arco circular, contra um macOS que usa raios
   contínuos e maiores. Tudo é retângulo com canto levemente lixado.
2. **Camadas indistinguíveis.** `#0B0B0B` / `#141414` / `#1A1A1A` / `#262626` —
   o olho não separa fundo, superfície, cartão e borda. Não há profundidade.
3. **Sem material.** O painel flutuante do macOS é vidro; o daqui é um retângulo
   cinza opaco. A infra de vibrancy existe e está desligada.
4. **Sem ponto de entrada tipográfico.** O maior texto do app tem 17 pt. Toda
   tela começa igual, com o mesmo peso, sem nada que segure o olho.
5. **Verde sobrecarregado.** Um único acento faz seleção, toggle, botão
   primário, foco, rótulo e marca. Nada se destaca porque tudo se destaca.
6. **Ritmo horizontal frouxo.** Rótulo à esquerda, controle à direita, e um vão
   enorme no meio, linha após linha — a tela de preferências vira uma escada de
   pares soltos, sem agrupamento visual que segure.
7. **Sombra genérica.** Uma sombra grande e escura embaixo do painel, sem a
   linha interna de luz na borda superior que é o que faz uma janela do macOS
   parecer feita de material.
8. **A sidebar é um bloco.** 260 pt de retângulo com sete linhas iguais e um
   rodapé; nenhuma hierarquia, nenhum agrupamento, nenhum respiro.

## 4.2 O que se quer

Uma **alternativa completamente diferente e melhor** — não um ajuste de raio e
de espaçamento sobre o que existe. Redesenho e relayout de verdade, moderno e
profissional, com cara de app que vende na Mac App Store.

- **Referência estética: a Apple.** É app Mac-only; pode e deve parecer parte do
  sistema — material translúcido, vibrancy, sombra de janela de verdade, o
  vocabulário do Sonoma/Sequoia/Tahoe, squircle, densidade de app nativo.
  Espírito vizinho: Raycast, Linear, Things 3, Craft, CleanShot X.
- **Manter a família de cor**: verde `#22C55E` + neutros escuros. O dono gosta
  da paleta. O problema é **como ela está aplicada**, não quais cores são.
  Recalibrar luminâncias, criar degraus de superfície que se vejam, dar papéis
  distintos a accent/seleção/foco — tudo isso é bem-vindo. Trocar o verde por
  outra cor, não.
- **Liberdade total de layout.** Pode mudar a estrutura das telas, a sidebar, a
  ordem das seções, a anatomia da linha de configuração, a forma dos painéis, a
  grade do Leaf, o cabeçalho do Hub. Se a proposta for melhor, as regras de
  3.11 podem cair — desde que a proposta diga **o que passa a resolver o
  problema que aquela regra resolvia**.
- **Degradê é permitido**, desde que sirva à profundidade, ao material ou a um
  estado — nunca à decoração. Se não ficar bom, chapado bem resolvido vence
  degradê genérico.
- **Não pode custar velocidade.** O app é usado por segundos de cada vez, por
  atalho. Nenhuma decisão pode adicionar tela de carregamento, transição longa
  ou pulo de layout. Blur permanente em superfície sempre visível precisa ser
  assumido como custo consciente.
- **Não pode virar "app de IA".** Evitar: simetria performática, cor como
  decoração, botão com ícone + texto + cor + sombra para uma ação simples, vazio
  sem propósito, tudo com o mesmo peso visual. Toda decisão visual precisa de
  uma razão funcional dizível em uma frase.

## 4.3 Escopo — as telas a redesenhar

**Hub (janela normal):**
1. Sidebar de módulos (7 itens + rodapé do app)
2. Cabeçalho de tela de módulo
3. Tela de preferências genérica (a anatomia de seção + linha + controle)
4. Tela do Pin (lista de tipos + gerador de CPF/CNPJ + preferências)
5. Tela do Echo (lista de reuniões agrupada por dia + preferências)
6. Tela do Focus (histórico + preferências)
7. Tela do Track (balanço da semana + barras por dia + lista de dias)
8. Tela do Nest (pastas favoritas + preferências)
9. Tela do Leaf e do Awake (as mais curtas — o teste do "módulo simples")
10. Tela de preferências do aplicativo (nome, iniciar com o macOS, backup)
11. A região de leitura (3ª coluna): reunião do Echo, sessão do Focus, dia do Track

**Painéis flutuantes:**
12. Pin — lista + preview (o mais complexo)
13. Focus — cronômetro parado e rodando
14. Leaf — a parede 3×3
15. Awake — o mais simples de todos
16. Echo — parado, gravando, transcrevendo
17. Nest — vazio e com arquivos

**Transversais:**
18. A matriz de estados (rest/hover/pressed/selected/focus/disabled)
19. Estado vazio, barra de teclas do rodapé, anel de foco
20. Seleção — o que substitui "accent 14% + aresta de 3 px"

## 4.4 O que entregar

1. **Um conceito com nome e uma tese em uma frase** — o que este redesenho
   acredita que o atual não acredita.
2. **Sistema de tokens completo**, no formato que o projeto já consome:
   `EgPalette` (as ~38 cores), `EgTypeScale` (os ~18 papéis),
   `EgShapes`, `EgElevations`, `EgMotion`, `EgGradients` — com valores concretos
   e a justificativa de cada mudança relevante. Papel novo pode ser criado;
   diga o nome e o porquê.
3. **Anatomia dos componentes-chave** com medidas: linha de lista, linha de
   configuração, item de sidebar, botão, toggle, segmented control, campo de
   busca, cartão do Leaf, barra de teclas, estado vazio, badge de ícone.
4. **Layout de cada tela do escopo**, com as dimensões reais da seção 3.1 como
   restrição (ou uma proposta explícita de dimensão nova, com o motivo).
5. **A matriz de estados completa** para cada família de superfície.
6. **Motion**: o que anima, quanto tempo, com que curva — respeitando que a
   saída de painel é instantânea e que a entrada tem ~120 ms.
7. **Um antes/depois argumentado** de pelo menos três telas, dizendo qual dos
   oito sintomas de 4.2 cada mudança resolve.
8. **O que muda em código**: quais tokens, quais componentes, quais telas —
   e, se algo exigir Swift/AppKit novo, dizer o quê e por quê (a preferência da
   casa é sempre Flutter puro; alternativa nativa descartada vira documento).

## 4.5 Como responder

- Comece pela **tese e pelo sistema** (cor, forma, tipo, material, profundidade)
  antes de qualquer tela. Uma tela bonita sem sistema não é implementável aqui.
- Seja **concreto e numérico**. "Mais respiro" não é entregável; `20 → 28` é.
- Diga o que **remover**. Um redesenho que só acrescenta não resolve "clean".
- Onde a proposta contrariar uma regra da seção 3.11, diga qual regra e o que
  entra no lugar.
- Português (pt-BR) — a UI e a microcópia do app são em pt-BR.

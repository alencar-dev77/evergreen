# Cores, Luz e Profundidade

## Princípio central

Cor no Evergreen é **um sistema de significado**, não um sistema decorativo. Antes de escolher qualquer valor de cor, pergunte: *o que essa cor está comunicando que a posição e a tipografia sozinhas não comunicariam?* Se a resposta for "nada, só queria que ficasse mais vivo", a cor está errada.

Um app com cara de macOS nativo tende a ser **90–95% neutro** (cinzas e o fundo da superfície) e usar cor de destaque em menos de 10% da área visível — normalmente concentrada em: ação primária, item selecionado, estado de erro/aviso/sucesso, e pouco mais.

## Estrutura de paleta

### Neutros (a base de tudo)

Defina uma escala de neutros com pelo menos 9–10 degraus, do quase-preto ao quase-branco, e use-a para 90% de toda a interface: fundos, bordas, texto, ícones inativos, divisores. Não use "cinza genérico" (`#808080`, `#CCCCCC`) — neutros premium têm uma leve temperatura (levemente quente ou levemente fria, nunca perfeitamente dessaturados), porque cinza puro parece "de fábrica" e cinza com temperatura parece calibrado a mão.

Sugestão de organização (ajuste os hex reais durante implementação, o que importa é a estrutura de papéis):

- `surface/base` — fundo da janela principal.
- `surface/raised` — um degrau acima do base, para painéis, sidebars, popups (diferença sutil, não um salto).
- `surface/overlay` — para modais e dropdowns, mais um degrau acima, geralmente com leve blur atrás.
- `border/subtle` — divisores quase imperceptíveis dentro de uma mesma seção.
- `border/default` — divisão entre seções distintas.
- `text/primary` — texto de leitura principal.
- `text/secondary` — labels, metadados, texto de apoio.
- `text/tertiary` — placeholders, texto desabilitado, timestamps discretos.

### Decisão do produto: dark-only, e uma pele só

O Evergreen é **dark-only** — light mode segue sendo dívida assumida, não
esquecida.

**Houve um segundo tema, o `apple`, e ele saiu (v0.16).** A escolha de aparência
estava desligada por bandeira desde que nasceu, e com todo campo de token
`required` o segundo arquivo dobrava o custo de cada papel novo. Manter uma pele
que não se veste é dívida, não é opção. Se um dia voltar, volta como um segundo
`EgPalette` completo — não como `if`s espalhados.

A pele é a **"Estufa"**: superfícies opacas no Hub, vidro no painel flutuante,
canto contínuo, e o verde com dois papéis só.

## Contraste

- Texto principal sobre fundo: mínimo AA (4.5:1), mas prefira ativamente superar isso com folga — apps nativos premium tendem a ficar mais próximos de AAA (7:1) no texto de leitura primária, porque são usados por longas sessões.
- Texto secundário/metadados pode ficar mais perto do mínimo AA, mas nunca abaixo de 3:1 mesmo para texto grande.
- Nunca use opacidade para simular texto secundário sobre superfícies que variam (light/dark, hover) sem testar o contraste real resultante — opacidade sobre superfícies dinâmicas pode cair abaixo do mínimo aceitável sem que pareça, "no design estático".
- Bordas e divisores existem para orientar, não para se destacar — geralmente ficam propositalmente **abaixo** do contraste mínimo de texto (são decoração estrutural, não conteúdo), mas ainda devem ser perceptíveis o suficiente para cumprir sua função de separação.

## Iluminação e profundidade

O Evergreen não tem uma "fonte de luz" cenográfica como um app de design 3D. A profundidade é comunicada por **camadas de superfície**, não por sombras dramáticas:

1. **Elevação por degrau de cor**, não por sombra pesada — a diferença sutil de tom entre `surface/base` e `surface/raised` já comunica "isso está por cima" antes mesmo de qualquer sombra.
2. **Sombra funcional, não decorativa** — use sombra apenas em elementos que realmente flutuam sobre o conteúdo (popups, dropdowns, modais, tooltips) e que o usuário pode fechar/dispensar. Nunca em cards estáticos de conteúdo permanente na tela — isso é o tique visual mais comum de "design genérico de IA".
3. **Blur com propósito, não como estética** — blur (efeito vidro fosco, tipo macOS) é apropriado em: sidebars translúcidas sobre conteúdo que rola por trás, barras de título, popups temporários. Não é apropriado para superfícies grandes e permanentes onde o custo de renderização é alto e o ganho visual é baixo. Regra prática: se o elemento fica na tela por mais de alguns segundos continuamente (não é um popup passageiro), pense duas vezes antes de aplicar blur nele.
4. **Sem gradiente decorativo.** Gradientes chamativos (multi-hue, diagonal, "app de IA genérico") não pertencem ao Evergreen. O único uso aceitável de gradiente é extremamente sutil — por exemplo, um gradiente de 2–3% de variação de luminosidade em uma superfície grande para evitar banding, imperceptível como "gradiente" à primeira vista.

### Fundo com profundidade (decisão do produto)

O fundo das janelas do Evergreen **não** é uma cor chapada ("preto blocado"). Ele combina duas camadas baratas, ambas dentro do limite de sutileza acima:

1. **Vinheta vertical** — gradiente do topo (levíssima elevação, com um toque quase imperceptível de verde) para a base (um degrau mais escuro). Variação de luminância na casa de 3–4%, nunca lida conscientemente como "gradiente".
2. **Brilho verde difuso** — um gradiente radial de accent em opacidade muito baixa (~3,5%), ancorado acima do topo da janela, com falloff largo. Simula o "blur por cima" / luz difusa **sem** `BackdropFilter`, então pode ficar permanente na tela sem custo de render.

Implementação: tokens em `app_colors.dart` (`backgroundTop`, `backgroundDeep`, `surfaceTop`), gradientes compostos em `app_gradients.dart`, aplicados via `EgBackground` (janelas) e pelo parâmetro `gradient` do `EgPanel` (overlay do Pin). Sidebars podem ficar levemente translúcidas (sólido com alpha sobre o gradiente, sem blur) para o brilho atravessar e unificar as regiões.

## Papéis reais implementados (`app_colors.dart`)

Os papéis abstratos acima já têm nome e valor no produto. Use o token, nunca um hex — o único arquivo do repositório autorizado a escrever `Color(0x...)` é o `app_colors.dart`.

| Papel | Token | Valor | Onde aparece |
|---|---|---|---|
| Fundo de janela | `canvas` → `canvasDeep` | `#0F1315` → `#08090A` | o degradê da janela; a luz entra por cima |
| Cartão de seção | `surface` | `#191E20` | `EgSettingsCard`, superfície que carrega conteúdo |
| Topo de bloco | `surfaceTop` | `#1D2325` | hover de linha, topo do bloco-instrumento |
| **Elevado** | `raised` | `#212729` | **linha selecionada**, faixa de estado, hover de pílula |
| Controle | `control` | `#272E31` | botão secundário, campo, keycap |
| Hover de controle | `hover` | `#2E3639` | |
| Pressionado | `pressed` | `#1D2325` | **mais escuro que o repouso** — afunda, não acende |
| Divisor | `line` | `#363F42` | o que separa duas linhas dentro do mesmo cartão |
| Aresta | `edge` | branco a 10% | borda de cartão — luz com alfa, não cinza opaco |
| Luz | `edgeLight` | branco a 14% | hairline interna no topo de painel e de pílula |
| Véu da barra lateral | `sidebarTint` | branco a 2,6% | chapado, por custo — ver abaixo |
| Vidro | `glassPanel` | `#161B1D` a 66% | painel flutuante, sob blur 40 + saturação 165% |
| Linha no vidro | `glassRow` | branco a 10% | seleção **dentro** do painel flutuante |
| Controle no vidro | `glassControl` | branco a 9% | |
| **Accent** | `accent` | `#22C55E` | **ligado, ou ação primária. Mais nada.** |
| Accent claro | `accentLight` | `#6EE7A0` | rótulo e glifo sobre fundo escuro — nunca fundo |
| Dado: tempo em curso | `ember` | `#E8B24A` | reunião, "processando", a barra do dia |
| Dado: arquivo/sistema | `tide` | `#5B9CF6` | informação neutra que ainda precisa de cor |
| Anel de foco | `focusRing` | branco a 34% | **branco, não verde** |
| Texto | `textPrimary` … `textQuaternary` | `#EDF2F0` … `#4C5457` | quatro degraus |
| Erro | `error` | `#EF4444` | superfície a 6%, borda a 22% no cartão destrutivo |

### As três regras que sustentam a paleta

**1. O verde tem dois papéis, e só dois: ligado e ação primária.** Seleção,
foco, rótulo selecionado e aresta deixaram de ser verdes de propósito. Quando
tudo se destaca, nada se destaca — e o accent gasto em seis lugares não dizia
mais "isto está ligado" em lugar nenhum.

**2. Selecionado é elevação e peso, nunca cor.** Era accent a 14% mais uma
aresta verde de 3px à esquerda; agora é a superfície `raised` com uma linha de
luz de 1px no topo (`rowInnerHairline`), mais o texto em `bodyStrong`. O Flutter
não tem sombra interna, então a elevação se desenha com luz.

**3. Os degraus de neutro têm de se ver — e "se ver" é na tela, não na
tabela.** A paleta anterior amontoava cinco papéis entre `#0B` e `#2E`, e o olho
não separava fundo de cartão. Vizinhos guardam pelo menos cinco pontos de
luminância entre si; a borda saltou de `#262626` para luz com alfa.

O degrau de `canvas` para `surface` estava nesses cinco pontos e mesmo assim o
cartão não aparecia, porque o degrau se mede **depois de tudo o que a janela
põe por cima**. O halo verde do topo — accent a 7% — somava uns doze pontos ao
canal verde do fundo, e o canal verde é o que mais pesa na luminância: o fundo
alcançava o cartão exatamente na faixa em que os cartões ficam. O cartão virava
uma mancha cinza sobre um campo esverdeado da mesma claridade, que é como um
"cinza que não fica legal" se parece por dentro. O halo caiu para 3,5%, o
`canvas` desceu para `#0F1315` e a aresta subiu para 10% — três correções para
o mesmo degrau, porque separação de superfície é fundo, luz e contorno juntos.

### Onde o vidro liga, e onde não

**Liga** na janela flutuante e no dropdown: eles vivem segundos.
**Não liga** na barra lateral do Hub nem nos cartões de conteúdo: um
`BackdropFilter` permanente recompõe tudo atrás dele a cada quadro. A barra usa
`sidebarTint` chapado e paga o mesmo papel visual a custo zero.

Sobre o vidro, a escala de neutros não vale: o que passa por trás muda a leitura
de qualquer cinza opaco, e uma linha selecionada pintada de `raised` some quando
o painel abre sobre uma janela clara. Ali a seleção é **branco com alfa**
(`glassRow`), que é a única coisa que se comporta igual sobre qualquer fundo.

Notas de aplicação:

- **Selecionado e hover nunca são a mesma cor.** Selecionado é um degrau acima do hover; se empatam, passar o mouse numa linha vizinha a faz parecer a escolhida. Prendido por teste em `eg_surface_style_test.dart`.
- **`focusRing` é sombra, não borda** (`AppShadows.focusRing`): assim o componente não muda de tamanho ao receber foco. Isso exige fundo opaco sob o anel — um componente transparente em repouso (botão de ícone, item de sidebar) adota a superfície de hover ao ganhar foco.
- **`textSelection`** é o accent a 25%: ali o realce precisa sobreviver ao texto desenhado por cima.
- **A resolução desses estados é uma só, e mora em `EgSurfaceStyle`** (`lib/shared/widgets/eg_surface.dart`). A tabela de precedência está em `components.md`; nenhum widget deve reimplementá-la.
- **Exceção registrada — `EgToggle`:** o switch usa trilho **verde chapado** quando ligado, contrariando a regra de "accent sempre em baixa opacidade". É convenção nativa de macOS: o usuário lê ligado/desligado por essa cor antes de ler qualquer outra pista, e um trilho de baixa opacidade ficaria ambíguo. É a única exceção do design system; qualquer outra precisa da mesma justificativa de convenção do sistema, não de estética. A matriz dele tem duas colunas (ligado e desligado) e quem carrega os estados é o **trilho** — `accent`→`accentHover`→`accentPressed` ligado, `hover`→`line`→`pressed` desligado. A bolinha só diz de que lado está: fazê-la clarear no hover foi tentado e descartado por redundância de affordance.

## Estados de cor (checklist rápido)

Todo elemento interativo precisa de cor definida para, no mínimo:

- `default` — estado de repouso.
- `hover` — leve mudança de superfície ou opacidade, nunca mudança de matiz.
- `active/pressed` — leve escurecimento (ou clareamento em dark mode) em relação ao hover.
- `focus` — anel/contorno usando a cor de destaque, sempre visível quando navegado por teclado.
- `disabled` — redução de opacidade/contraste, nunca remoção total do elemento (a pessoa precisa entender que a opção existe mas está indisponível agora).
- `selected` (quando aplicável, como itens de lista/sidebar) — superfície com a cor de destaque em baixa opacidade, não a cor sólida cobrindo toda a linha.

Veja `motion.md` para como essas transições de estado devem se comportar no tempo, e `components.md` para a aplicação específica em cada tipo de componente.

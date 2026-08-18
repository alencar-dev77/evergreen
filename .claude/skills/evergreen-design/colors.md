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

### Decisão do produto: dark-only até (pelo menos) a v0.2

O Evergreen v0.1 é **dark-only, por decisão explícita** — não por esquecimento. Light mode é **dívida assumida**: a paleta em `app_colors.dart` são cores diretas, não um par claro/escuro, e nenhuma tela foi calibrada para fundo claro.

Consequências práticas enquanto essa decisão valer:

- Não adicione `Brightness`/`ThemeMode`/tokens duplicados "já preparando" o light mode. Preparar sem calibrar produz um light mode de segunda classe, que é exatamente o que a seção abaixo proíbe.
- Não force uma cor a "funcionar nos dois modos" ao custo de ficar morna no escuro. Otimize para o escuro, que é o único modo que existe hoje.
- Quando o light mode entrar (v0.2+), ele é uma tarefa de recalibração inteira — cada papel de superfície, o accent e as cores semânticas —, não um `if (isDark)` espalhado pelos widgets.

### Light mode e dark mode como cidadãos de primeira classe

Quando os dois modos existirem, valem as regras abaixo. O Evergreen roda o dia inteiro na tela de alguém — ele **precisa** funcionar perfeitamente nos dois modos, sem que um pareça "o modo de verdade" e o outro "o modo que faltou polir". Regras práticas:

- Não inverta cores mecanicamente (preto vira branco, branco vira preto). Redesenhe cada papel de superfície com a mesma lógica de profundidade, mas calibrada para a percepção em cada modo — no dark mode, superfícies "elevadas" ficam **mais claras** que a base (o oposto do que a intuição de sombra em light mode sugeriria), porque é assim que o olho humano lê elevação sob luz escura.
- Cor de destaque (accent) deve ter uma variante calibrada para cada modo — a mesma cor pura costuma parecer "gritante" ou "suja" dependendo do fundo; ajuste luminosidade e saturação por modo, mantendo o matiz (hue) reconhecível como o mesmo.
- Teste todo estado de erro/aviso/sucesso nos dois modos — é comum vermelho/amarelo funcionarem bem em light mode e ficarem ilegíveis ou berrantes em dark mode.

### Cor de destaque (accent)

Escolha **uma única cor de destaque primária** para todo o app (o "accent color" no sentido do macOS — pense em como o macOS deixa o usuário escolher uma accent color do sistema e tudo se adapta a ela). Use-a para:

- Botão/ação primária.
- Item ativo/selecionado em listas, sidebar e abas.
- Foco de campo de texto (borda ou anel de foco).
- Links e referências clicáveis dentro de texto.

Não crie uma segunda cor de destaque "para variar". Se precisar de mais expressividade, varie a **opacidade e o peso** da mesma cor de destaque antes de introduzir uma cor nova.

### Cores semânticas (estado, não decoração)

Reserve cores específicas — e só as use nesse contexto — para:

- **Sucesso** — verde, discreto, usado em confirmações pontuais e indicadores de status "ok".
- **Aviso** — âmbar/amarelo escuro, usado para atenção que não é bloqueante.
- **Erro/destrutivo** — vermelho, usado em validação de formulário, ações destrutivas (deletar, remover) e badges de erro.
- **Informação neutra** — normalmente reaproveita o accent em opacidade baixa, não precisa de uma cor própria.

Nunca use essas cores fora do seu significado (por exemplo, nunca use verde só porque "combina" em um botão que não representa sucesso/confirmação).

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
2. **Brilho verde difuso** — um gradiente radial de accent em opacidade muito baixa (~6%), ancorado acima do topo da janela, com falloff largo. Simula o "blur por cima" / luz difusa **sem** `BackdropFilter`, então pode ficar permanente na tela sem custo de render.

Implementação: tokens em `app_colors.dart` (`backgroundTop`, `backgroundDeep`, `surfaceTop`), gradientes compostos em `app_gradients.dart`, aplicados via `EgBackground` (janelas) e pelo parâmetro `gradient` do `EgPanel` (overlay do Pin). Sidebars podem ficar levemente translúcidas (sólido com alpha sobre o gradiente, sem blur) para o brilho atravessar e unificar as regiões.

## Papéis reais implementados (`app_colors.dart`)

Os papéis abstratos acima já têm nome e valor no produto. Use o token, nunca um hex — o único arquivo do repositório autorizado a escrever `Color(0x...)` é o `app_colors.dart`.

| Papel | Token | Valor | Onde aparece |
|---|---|---|---|
| Fundo de janela | `background` | `#0B0B0B` | janela, overlay, barra de dicas |
| Superfície de painel | `surface` | `#141414` | `EgPanel`, sidebar (a 72% de alpha) |
| Campo / card interno | `card` | `#1A1A1A` | inputs, key-caps, badges, botão secundário |
| Hover neutro | `hover` | `#232323` | mouse sobre linha, botão, item de sidebar |
| Pressed | `pressed` | `#2E2E2E` | um degrau acima do hover, enquanto o clique está apertado |
| Borda sutil | `border` | `#262626` | divisores de 1px, contorno de painel |
| Accent | `greenPrimary` | `#22C55E` | ação primária, ícone de fixado, cursor |
| Accent hover | `greenLight` | `#4ADE80` | hover do primário, texto de item selecionado |
| Accent pressed | `greenDeep` | `#16A34A` | pressed do botão primário |
| **Seleção** | `selection` | accent a 14% | linha de lista selecionada, item de sidebar aberto, opção do segmented control |
| **Anel de foco** | `focusRing` | accent a 60% | 2px ao redor do componente focado por teclado |
| Texto primário | `textPrimary` | `#F5F5F5` | conteúdo, títulos |
| Texto secundário | `textSecondary` | `#9CA3AF` | metadados, labels, ícones em repouso |
| **Texto terciário** | `textTertiary` | `#6B7280` | placeholder de busca, timestamp de linha, badge de atalho em repouso |
| Erro / destrutivo | `error` | `#EF4444` | texto do botão "Excluir"/"Limpar" |
| Aviso | `warning` | `#F59E0B` | reservado |
| Véu de modal | `scrim` | preto a 60% | fundo do `EgConfirmDialog` |
| Transparente | `transparent` | — | estado de repouso de superfícies que só aparecem no hover |

Notas de aplicação:

- **`selection` e `hover` nunca são a mesma cor.** Seleção é "onde o teclado está" (accent); hover é "onde o mouse passou" (neutro). Quando os dois coincidem na mesma linha, a seleção vence.
- **`focusRing` é sombra, não borda** (`AppShadows.focusRing`): assim o componente não muda de tamanho ao receber foco. Isso exige fundo opaco sob o anel — um componente transparente em repouso (botão de ícone, item de sidebar) adota a superfície de hover ao ganhar foco.
- **`sidebar`** é o `surface` a 72%: translúcido para o brilho verde do fundo atravessar e unificar sidebar e conteúdo, sem custo de blur. **`textSelection`** é o accent a 25% — mais forte que a `selection` de linha porque ali o realce precisa sobreviver ao texto desenhado por cima.
- **A resolução desses estados é uma só, e mora em `EgSurfaceStyle`** (`lib/shared/widgets/eg_surface.dart`). A tabela de precedência está em `components.md`; nenhum widget deve reimplementá-la.
- **Exceção registrada — `EgToggle`:** o switch usa trilho **verde chapado** quando ligado, contrariando a regra de "accent sempre em baixa opacidade". É convenção nativa de macOS: o usuário lê ligado/desligado por essa cor antes de ler qualquer outra pista, e um trilho a 14% ficaria ambíguo. É a única exceção do design system; qualquer outra precisa da mesma justificativa de convenção do sistema, não de estética. A matriz dele tem duas colunas (ligado e desligado) e quem carrega os estados é o **trilho** — `greenPrimary`→`greenLight`→`greenDeep` ligado, `border`→`hover`→`pressed` desligado. A bolinha só diz de que lado está: fazê-la clarear no hover foi tentado e descartado por redundância de affordance.

## Estados de cor (checklist rápido)

Todo elemento interativo precisa de cor definida para, no mínimo:

- `default` — estado de repouso.
- `hover` — leve mudança de superfície ou opacidade, nunca mudança de matiz.
- `active/pressed` — leve escurecimento (ou clareamento em dark mode) em relação ao hover.
- `focus` — anel/contorno usando a cor de destaque, sempre visível quando navegado por teclado.
- `disabled` — redução de opacidade/contraste, nunca remoção total do elemento (a pessoa precisa entender que a opção existe mas está indisponível agora).
- `selected` (quando aplicável, como itens de lista/sidebar) — superfície com a cor de destaque em baixa opacidade, não a cor sólida cobrindo toda a linha.

Veja `motion.md` para como essas transições de estado devem se comportar no tempo, e `components.md` para a aplicação específica em cada tipo de componente.

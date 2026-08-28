# Anti-Padrões: o que o Evergreen NUNCA faz

Use este arquivo como checklist final antes de considerar qualquer tela, componente ou fluxo "pronto". Se qualquer item abaixo estiver presente, volte e corrija antes de entregar.

## Estrutura e layout

- ❌ **Não centralizar conteúdo de trabalho.** Listas, formulários, painéis de configuração e áreas de conteúdo principal nunca são centralizados na largura da janela — isso é vocabulário de site/documento, não de ferramenta desktop. Ver `spacing.md` para a exceção legítima (modais pequenos).
- ❌ **Não criar layouts de landing page.** Nada de seção "hero", CTA gigante, texto de marketing ("Transforme sua produtividade!"), carrossel de destaques, ou qualquer estrutura pensada para "converter visitante", porque não existe visitante — existe usuário que já decidiu usar o app.
  **Exceção decidida em conversa (v0.8.3+): a apresentação de boas-vindas.** Na
  primeira abertura depois da instalação — e só nela —, o Hub mostra os cinco
  painéis, um por tela, com o print do painel de verdade, duas linhas e o
  atalho. O argumento acima ("não existe visitante") vale para todo o resto do
  app justamente porque esta tela existe: é aqui que a pessoa deixa de ser
  visitante. Ela roda **uma vez por instalação e nunca mais**, atualização
  inclusive, e pular conta como visto — quem fechou respondeu, não adiou.
  A alavanca `kAlwaysShowOnboarding` (em `onboarding_repository.dart`) força a
  apresentação em toda abertura para trabalhar nela; nasce `false` e um teste
  falha se alguém subir com `true`.
- ❌ **Não deixar telas vazias com espaço em excesso.** Se uma tela parece "vazia demais", o problema quase sempre é falta de conteúdo/hierarquia real ali, não falta de padding decorativo ao redor de pouco conteúdo. Ver `components.md` (Empty states) para o padrão correto.
- ❌ **Não empilhar cards dentro de cards.** Se um bloco de conteúdo dentro de um card parece precisar do mesmo tratamento de container do pai, resolva com espaçamento e tipografia, não com mais uma camada de card. Ver `components.md`.
- ❌ **Não usar grid de 12 colunas típico de web design.** O Evergreen é composto por regiões fixas/redimensionáveis (sidebar, conteúdo, painel de detalhe), não por um sistema de colunas fluidas de site responsivo.

## Cor

- ❌ **Não usar gradientes chamativos.** Nada de gradiente multi-hue, diagonal, ou "roxo-para-azul genérico de app de IA" em botões, fundos ou ícones. O único gradiente aceitável é sutilíssimo, para evitar banding em superfícies grandes, imperceptível como "gradiente".
  **Uma exceção, e só uma: o palco da apresentação de boas-vindas**
  (`AppGradients.onboardingStage`), que vai do preto ao verde na diagonal e é
  para ser visto como gradiente. Ele passa porque não é tela de trabalho — é a
  única vez em que o Evergreen se apresenta, e nela o verde da marca é o
  assunto, não um estado. Mesmo assim é contido: para no `greenShade` e não
  chega no accent, para o print que fica em cima continuar sendo a coisa mais
  clara da composição.
- ❌ **Não criar interfaces coloridas demais.** A paleta é 90%+ neutra; cor de destaque e cores semânticas aparecem em contextos pontuais de ação e estado, nunca espalhadas pela tela "para dar vida".
- ❌ **Não usar cor sem significado.** Toda cor fora do neutro precisa representar algo real (ação primária, estado, seleção) — nunca decoração pura.
- ❌ **Não usar mais de uma cor de destaque (accent) no mesmo app.** Varie opacidade/peso da mesma cor antes de introduzir uma segunda.

## Profundidade e superfície

- ❌ **Não usar glassmorphism excessivo.** Blur/vidro fosco é reservado para elementos temporários (popups, barras que ficam sobre conteúdo que rola) — nunca aplicado indiscriminadamente em toda superfície grande e permanente só por estética, tanto por custo de performance quanto por poluição visual.
- ❌ **Não usar sombra decorativa em conteúdo estático.** Sombra é reservada a elementos que genuinamente flutuam e podem ser dispensados (popup, modal, tooltip, dropdown). Cards de conteúdo permanente na tela não precisam de sombra — uma borda sutil ou diferença de superfície já basta.
- ❌ **Não exagerar no border-radius.** Nada de cantos muito arredondados (16px+) em componentes retangulares — isso empurra a estética para "app mobile consumer" em vez de ferramenta desktop profissional. Ver escala em `spacing.md`.

## Ícones e elementos visuais

- ❌ **Não usar muitos ícones.** Um ícone só existe se substituir texto com ganho real de reconhecimento rápido — nunca ícone "para preencher espaço" ao lado de um label que já é autoexplicativo, e nunca um ícone que precisa de tooltip para ser entendido (se precisa, o ícone falhou e deveria ser texto).
- ❌ **Não usar ilustrações grandes e coloridas** em empty states, onboarding ou qualquer tela funcional — isso é linguagem de app consumer/marketing, incompatível com o tom sóbrio do Evergreen.
- ❌ **Não usar emoji como substituto de ícone de sistema** na interface funcional do app (emoji pode aparecer em conteúdo gerado pelo próprio usuário, mas não como parte do chrome/UI do Evergreen).

## Motion

- ❌ **Não usar animações chamativas.** Sem parallax, sem stagger dramático de elementos entrando em cascata, sem bounce/spring exagerado como padrão geral, sem ícones "com vida própria" pulsando/flutuando sem representar um estado real. Ver `motion.md` para as durações e curvas corretas.
- ❌ **Não animar escala em hover/click de botões** ("cresce ao passar o mouse", "encolhe ao clicar") — isso é linguagem de site/app mobile consumer.
- ❌ **Não usar telas de loading dramáticas** com logo animado no meio do uso normal do app.
  **Exceção decidida em conversa (v0.8.3+): a abertura animada do Hub.** O Hub
  ganha uma animação de entrada — a lâmina do ícone girando para fora do cabo
  em 700ms, mais a pausa para ler o nome, ~1,5s no total — que roda **uma vez
  por atualização**: na primeira vez que o Hub abre depois de o binário mudar,
  e nunca mais até a atualização seguinte.
  O que separa isso de uma tela de loading é a frequência, não a pressa: um
  segundo e meio cobrado de quem abre o app quarenta vezes por dia é pedágio;
  cobrado uma vez a cada versão nova, é a marca dizendo que alguma coisa mudou.
  **Esta é a única cena do app fora da escala de durações do `motion.md`**, e é
  fora dela de propósito: o teto de 320ms existe para transição que atrapalha
  quem está no meio de uma tarefa, e aqui não há tarefa esperando. Na primeira
  versão a cena tentou caber na escala (280ms) e ficou no pior dos dois mundos
  — cobrava o tempo da pessoa e mesmo assim a lâmina travava antes de ela
  perceber que algo tinha se movido, sobrando só uma marca parada na tela, que
  é exatamente a tela de logo que esta regra proíbe. Ou a cena é vista, ou não
  existe. Pelo mesmo motivo o giro usa `easeInOutCubic` e não a curva padrão de
  entrada: em 700ms, um `easeOut` gasta o movimento no primeiro terço e o resto
  parece a animação travando; sair do repouso e desacelerar dentro da trava é o
  que faz o *settle* de 60ms ler como o clique do canivete.
  O gatilho é a **data de modificação do executável**
  (`File(Platform.resolvedExecutable).statSync().modified`), guardada em
  `AppSettings` — não a versão do `pubspec`, porque `run_build_copy` reinstala
  sem bumpar e a animação precisa aparecer no ciclo de desenvolvimento também.
  A data é gravada **depois** de a animação terminar, para quem fechar o Hub no
  meio do giro ver de novo. Com `MediaQuery.disableAnimations` ligado, a lâmina
  nasce travada e a data é gravada do mesmo jeito. O estado final da animação é
  o estado normal do ícone, então não existe degrau visual entre a primeira
  abertura e todas as outras.
  É uma vez por **instalação**, não por abertura: abrir o Hub dez vezes no
  mesmo dia toca o giro na primeira.
- ❌ **Não celebrar visualmente ações rotineiras** (confete, animação elaborada de sucesso) para tarefas cotidianas como marcar algo como concluído.

## Tipografia e conteúdo

- ❌ **Não misturar múltiplas famílias de fonte** sem propósito além do par principal + monoespaçada.
- ❌ **Não usar textos de marketing/tom de venda** em nenhuma parte da interface funcional ("Desbloqueie todo o potencial!", "Comece sua jornada!") — a cópia do Evergreen é direta, funcional e nunca performática.
- ❌ **Não usar títulos grandes e decorativos** espalhados pelas telas de trabalho — títulos grandes são raros e reservados a contextos muito específicos (ver `typography.md`).

## Padrões genéricos a evitar deliberadamente

- ❌ **Não seguir "padrões genéricos de IA"** reconhecíveis por: simetria performática sem hierarquia real por trás, redundância de affordance (ícone + texto + cor + sombra para uma ação simples que precisaria só de um desses), espaço em branco sem propósito de agrupamento, falta de opinião editorial visível (tudo com o mesmo peso visual, nada deliberadamente discreto ao lado de algo deliberadamente forte).
- ❌ **Não copiar interfaces de referência ao pé da letra.** Raycast, Linear, Arc, Things, Craft, CleanShot e Maccy (ver `references.md`) são fontes de **princípio**, nunca de pixel a ser reproduzido diretamente — o Evergreen precisa ter identidade própria, não ser uma colagem reconhecível de outros produtos.
- ❌ **Não tratar o dark mode como modo secundário.** Quando os dois modos existirem, ambos são desenhados com o mesmo nível de cuidado (ver `colors.md`) — nunca um "dark mode de inversão mecânica" mal calibrado. Hoje o Evergreen é **dark-only por decisão registrada**: não vale "resolver" isso adicionando um light mode não calibrado.

## Teste final antes de entregar

Antes de considerar qualquer entrega de UI concluída, faça esta pergunta sobre cada decisão visual não trivial: **"eu consigo justificar isso com uma razão funcional, ou a única razão é 'fica bonito'/'é o padrão'?"** Se a única razão for estética pura ou convenção genérica, volte, repense, e prefira a opção mais simples, mais neutra e mais rápida de usar.

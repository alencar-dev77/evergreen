# Referências: Princípios, Não Pixels

Esta skill usa os apps abaixo (e as Human Interface Guidelines da Apple) exclusivamente como fonte de **princípios de design**, nunca como material a ser copiado visualmente. Nenhuma interface do Evergreen deve ser reconhecível como "uma cópia de X" — o objetivo é que alguém familiarizado com todos esses apps sinta uma **qualidade familiar** (rigor, sobriedade, velocidade), não uma semelhança literal de layout, ícone ou paleta.

Ao usar este arquivo, extraia o *porquê* por trás de uma escolha de referência, aplique esse *porquê* ao contexto específico do Evergreen, e desenhe a solução do zero.

## Human Interface Guidelines (Apple)

**Princípio extraído**: consistência com as convenções da plataforma reduz a carga cognitiva a praticamente zero — a pessoa já sabe como um botão, um menu ou um atalho deve se comportar antes mesmo de interagir com o Evergreen, porque já aprendeu isso usando o resto do macOS a vida inteira.

**Como se aplica ao Evergreen**: convenções de teclado (`Cmd`, não `Ctrl`), estrutura de menu de aplicativo, comportamento de janela (redimensionamento, tela cheia, tráfego lights), e o princípio geral de que "clareza, deferência ao conteúdo e profundidade" (os três pilares clássicos da linguagem visual da Apple) devem guiar qualquer decisão onde não exista uma regra explícita nesta skill.

## Raycast

**Princípio extraído**: velocidade percebida através de **ausência de fricção antes da primeira tecla**. A busca aparece instantaneamente, os resultados são ranqueados com inteligência real (não só ordem alfabética), e todo o fluxo é pensado para nunca exigir o mouse.

**Como se aplica ao Evergreen**: o campo de busca central e a paleta de comandos (ver `components.md` e `ux.md`) seguem esse princípio de velocidade e descobribilidade de atalho — mas a paleta visual, ícones e estrutura de resultado do Evergreen são desenhados do zero para o contexto específico do produto, não copiados.

## Linear

**Princípio extraído**: densidade de informação com hierarquia impecável — uma tela pode mostrar muito, desde que peso tipográfico, espaçamento e agrupamento deixem absolutamente claro o que é primário e o que é secundário, sem precisar de cor para fazer esse trabalho.

**Como se aplica ao Evergreen**: a estrutura de três regiões (sidebar + conteúdo + painel de detalhe) descrita em `spacing.md`, e a disciplina de "densidade alta com hierarquia clara" descrita em `ux.md`, vêm desse princípio — a implementação visual específica (cores, radius, tipografia) é a identidade própria do Evergreen.

## Arc Browser

**Princípio extraído**: a interface pode ter personalidade sutil e um toque de leveza (motion cuidadoso, superfícies com profundidade calibrada) sem deixar de ser funcional — "premium" não precisa significar "carregado".

**Como se aplica ao Evergreen**: o conceito de "minimalismo premium com textura" descrito em `philosophy.md` — variação sutil de superfícies, motion cuidadoso em vez de motion abundante — é inspirado nesse equilíbrio, sem herdar nenhuma escolha visual literal do Arc.

## Things 3

**Princípio extraído**: clareza absoluta na hierarquia de uma lista de tarefas através de tipografia e espaçamento, quase sem depender de cor ou ícone — e uma sensação tátil de "objeto bem feito" mesmo sendo extremamente simples.

**Como se aplica ao Evergreen**: o padrão de listas descrito em `components.md` (estrutura de linha, hierarquia por peso tipográfico antes de cor) e a definição de "minimalismo premium, não minimalismo vazio" em `philosophy.md` vêm diretamente dessa observação.

## Craft

**Princípio extraído**: quando o conteúdo é o protagonista (escrita, edição), a interface deve recuar ativamente — barras de ferramentas que só aparecem quando relevantes (ex: ao selecionar texto), tipografia de leitura confortável, e um chrome de app quase invisível ao redor do conteúdo.

**Como se aplica ao Evergreen**: o "modo criação/edição de conteúdo" descrito em `philosophy.md`, e a orientação em `motion.md`/`components.md` de que ferramentas contextuais aparecem sob demanda em vez de permanecerem sempre visíveis.

## CleanShot X

**Princípio extraído**: uma ferramenta utilitária que aparece rapidamente, resolve uma tarefa pontual com controles mínimos e diretos, e sai do caminho — sem exigir nenhuma "exploração" da interface para completar a tarefa mais comum.

**Como se aplica ao Evergreen**: reforça o princípio central de `philosophy.md` de que o Evergreen é "acionado e resolvido", não "visitado e explorado" — relevante especialmente para popups, modais rápidos e fluxos de captura pontual.

## Maccy

**Princípio extraído**: um utilitário extremamente simples pode ser extremamente rápido de usar se a densidade de informação for alta, a navegação por teclado for completa, e a interface não tentar ser "mais" do que a tarefa exige.

**Como se aplica ao Evergreen**: reforça a densidade alta recomendada para o "modo comando/captura rápida" em `philosophy.md` e `spacing.md`, e o princípio geral de que simplicidade não significa poucos elementos, significa hierarquia clara.

## Como usar este arquivo na prática

Quando estiver desenhando algo e sentir a tentação de "abrir o app X de referência e replicar o componente", pare — em vez disso, pergunte: *qual princípio esse app está demonstrando aqui, e como esse princípio se aplica ao contexto específico desta tela do Evergreen?* A resposta a essa pergunta deve ser articulável em uma frase antes de qualquer pixel ser desenhado. Se você não consegue nomear o princípio, provavelmente está prestes a copiar em vez de se inspirar.

# Componentes

Este arquivo define o comportamento e a aparência padrão de cada tipo de componente do Evergreen. Para cada um, a regra geral é: **escolha sempre o componente mais simples que resolve o problema.** Uma lista resolve mais casos do que uma tabela; texto resolve mais casos do que um badge; um badge resolve mais casos do que um card.

## Inventário `Eg*` (o que já existe)

Antes de desenhar um componente novo, procure aqui. Módulos novos devem **reusar** esta gramática em vez de recriar uma paralela — é o que faz os três módulos parecerem o mesmo aplicativo. Todos vivem em `lib/shared/widgets/`.

| Componente | Arquivo | Papel | Estados cobertos |
|---|---|---|---|
| `EgHoverable` | `eg_hoverable.dart` | primitiva de interação: entrega `EgInteraction` (hover/pressed/focus) ao builder | é a fonte dos estados dos demais |
| `EgSurfaceStyle` | `eg_surface.dart` | **a matriz de estado**: uma coluna por papel de superfície (`row`, `ghost`, `card`, `segment`, `primary`, `secondary`, `destructive`) | resolve fundo, conteúdo, borda e anel de foco |
| `EgSurface` | `eg_surface.dart` | a caixa já pintada pela matriz, recebendo o estado de fora | todos os da matriz |
| `EgInteractiveSurface` | `eg_surface.dart` | `EgHoverable` + `EgSurface`: o que todo elemento clicável deveria usar | default · hover · pressed · focus · selected · disabled |
| `EgButton` | `eg_button.dart` | botão em 3 variantes (`primary`, `secondary`, `destructive`) | default · hover · pressed · focus · disabled |
| `EgIconButton` | `eg_button.dart` | botão só de ícone, 36×36, com `tooltip` opcional | default · hover · pressed · focus · disabled |
| `EgToggle` | `eg_toggle.dart` | switch de preferência | default · hover · pressed · focus · disabled · on/off |
| `EgSegmentedControl` | `eg_segmented_control.dart` | escolha única entre 3–4 opções curtas; ← → quando focado | default · hover · pressed · focus · selected |
| `EgSearchField` | `eg_search_field.dart` | campo de busca (`bare` para a linha do topo do overlay) | default · focus (borda accent) · placeholder |
| `EgTextField` | `eg_text_field.dart` | campo de texto de uma linha que a pessoa escreve e confirma (atividade e resumo do Focus) | default · focus (borda accent) · disabled |
| `EgHintBar` / `EgHint` | `eg_hint_bar.dart` | rodapé de atalhos de um painel operado por teclado | — |
| `EgPanel` | `eg_panel.dart` | superfície flutuante com borda, radius e sombra | `elevated` on/off |
| `EgIconBadge` | `eg_panel.dart` | quadrado arredondado que abriga um ícone | — |
| `EgConfirmDialog` | `eg_confirm_dialog.dart` | confirmação de ação irreversível (360px, ações à direita, Esc = cancelar) | — |
| `EgSettingsSection` | `eg_settings_section.dart` | agrupa linhas de configuração sob um label em caps | — |
| `EgSettingsRow` | `eg_settings_row.dart` | linha de configuração: rótulo + descrição + controle | `showDivider` on/off |
| `EgNavTile` | `eg_nav_tile.dart` | item de navegação: badge de ícone + título + linha de apoio | default · hover · pressed · focus · selected |
| `EgOverlayShell` | `eg_overlay_shell.dart` | casca dos painéis flutuantes: entrada, blur, clique fora, centralização | — |
| `EgSectionLabel` | `eg_section_label.dart` | label de grupo em caixa alta | — |
| `EgKeyCap` / `EgShortcutDisplay` | `eg_key_cap.dart` | tecla e sequência de teclas | — |
| `EgEmptyState` | `eg_empty_state.dart` | estado vazio discreto (ícone pequeno + título + mensagem) | — |
| `EgCountdown` | `eg_countdown.dart` | bloco de painel que conta tempo: situação em caps + número grande + progresso | `isMuted` on/off |
| `EgIcon` | `eg_icon.dart` | ícone de path customizado (não Material Icons) | — |
| `EgBackground` | `eg_background.dart` | fundo de janela com vinheta + brilho verde | — |

Regras de manutenção deste inventário:

- Componente novo compartilhado nasce com prefixo `Eg`, em `lib/shared/widgets/`, e entra nesta tabela junto do commit que o cria.
- Estado de interação vem do `EgHoverable`, nunca de um `MouseRegion` próprio — é o que garante que hover, pressed e foco se comportem igual em todo o app.
- **A aparência de cada estado vem da matriz (`EgSurfaceStyle`), nunca de uma cadeia de `if`s escrita no widget.** Se o componente precisa de uma combinação que a matriz não tem, ele compõe uma `EgSurfaceStyle` própria a partir dos tokens (é o que o cartão do Leaf faz com a vaga livre e com o cartão em edição) — não reescreve a ordem de precedência. Antes da matriz a mesma cadeia existia copiada em seis arquivos, e as cópias já tinham divergido: um componente sem `pressed`, outro sem reação ao foco, e a ordem entre "selecionado" e "pressionado" mudando de um para o outro.
- Componente específico de um módulo (por exemplo `PinListItem`) **não** ganha prefixo `Eg` e não entra aqui; se um segundo módulo precisar dele, aí sim ele é promovido a `Eg*`.

## Padrões de tela já estabelecidos (reusar, não reinventar)

Estas decisões foram tomadas no v0.1 e valem como padrão do produto. Um módulo novo que precise da mesma coisa usa o mesmo arranjo:

- **Hub = sidebar de módulos + painel de detalhe.** A sidebar lista todos os módulos (inclusive os não lançados, esmaecidos, com a versão prevista no lugar da tagline); o detalhe abre com um cabeçalho compacto (nome + tagline) e as configurações abaixo. Os módulos ficam **colados no topo** da sidebar, sem cabeçalho de grupo acima deles: são eles que a pessoa vem procurar, e cada linha acima empurra o último módulo para o meio da janela.
- **Toda tela do Hub começa no topo, cheia ou vazia.** A área de detalhe rola, e um `SingleChildScrollView` encolhe até a altura do conteúdo quando ele cabe na janela — o `Row` do Hub precisa esticar (`CrossAxisAlignment.stretch`), senão a tela de um módulo curto abre com o texto no meio da janela enquanto as compridas abrem no topo. Duas telas do mesmo aplicativo não podem começar em alturas diferentes.
- **Preferências são `EgSettingsSection` + `EgSettingsRow`.** Seção com label em caps, linhas com rótulo à esquerda e controle à direita, divisor sutil entre linhas e nenhum na última. Módulo novo herda a mesma densidade e alinhamento de graça.
- **Configuração é escrita na hora.** Não existe botão "Salvar" em tela de preferência: mexer no controle já persiste. Também não existe confirmação de "salvo com sucesso" — a mudança visível no controle já é o feedback.
- **A marca da sidebar é a entrada do aplicativo, e mora no rodapé.** Clicar no logo do Evergreen abre as preferências do app (iniciar com o macOS, atalho do Hub, sobre), com os mesmos estados de seleção dos módulos. Um segundo item escrito "Evergreen" logo abaixo do logo seria o mesmo rótulo duas vezes na mesma lista. Fica embaixo, junto da versão, porque preferência de aplicativo é onde se vai de vez em quando — o topo pertence ao que se usa todo dia.
- **Preferência de app não mora em tela de módulo.** Se a configuração vale para o Evergreen inteiro, ela pertence à tela do aplicativo — não à do módulo que por acaso nasceu primeiro.
- **Registro de módulo é o enum `EvergreenModule` + `_settingsFor`.** Adicionar um módulo é adicionar um valor ao enum e ligar sua tela de configuração no `switch`; nada de lista paralela de navegação.
- **Nome dado pelo usuário vem à frente do dado, sem escondê-lo.** No Pin o apelido ocupa o lugar do título da linha e o conteúdo continua atrás dele, menor e em `text/tertiary`, no mesmo parágrafo — o corte por ellipsis come o conteúdo primeiro e nunca o apelido. Substituir o conteúdo por completo faria a lista prometer algo que a cópia não cumpre; mostrar os dois em colunas separadas viraria tabela.
- **Lista longa se agrupa com `EgSectionLabel`,** não com card nem fundo colorido (no Pin: "FIXADOS" e "RECENTES").
- **Painel operado por teclado leva uma barra de dicas no rodapé** (`EgHintBar`) com os atalhos daquele contexto, variando conforme o estado da tela. É documentação embutida no lugar onde a dúvida aparece. A dica que não pode sumir (tipicamente o `esc`) vai no `trailing`, ancorada à direita.
- **Painel flutuante é um só, compartilhado.** Pin, Focus, Leaf, Awake e Echo dividem a janela 0 e trocam de conteúdo por `OverlayPanel`; um módulo novo com atalho global entra ali, não em uma janela nova. Consequência de design: cada painel escolhe a própria largura (Pin 420/560, Focus 380, Awake e Echo 380 — mesmo arranjo do Focus, mesma largura; Leaf 528/778, a única que acompanha o conteúdo — e a única cuja largura é calculada, não escolhida: são os cartões, os vãos, o respiro e a borda do `EgPanel` somados, porque um pixel a menos recorta a última coluna), mas nenhum escolhe onde nasce, e nenhum implementa a própria casca: entrada, blur, clique fora e centralização vêm do `EgOverlayShell`. O tamanho da janela 0 (920x800) é ditado pelo maior painel e cresce sem mexer nos outros: todos são centralizados nela, que é transparente.
- **Cartão em grade só quando os itens são comparáveis lado a lado e poucos.** O Leaf é a exceção à preferência por lista: nove anotações curtas que precisam ser lidas *todas de uma vez*, sem rolar, não são uma lista — são um mural. A grade é **contígua e encolhe**: apagar um cartão faz os seguintes subirem uma vaga e o painel diminuir, com a mudança de tamanho animada nos dois eixos. A alternativa (vagas fixas, buraco preservado, `⌘N` estável para sempre) foi implementada e descartada no uso — um mural que não diminui quando se joga papel fora parece quebrado, e o ganho de memória muscular não paga olhar para vagas vazias. **Estabilidade de atalho numérico só vale a pena quando a lista é longa demais para ser lida de relance** (é o caso do Pin, não o do Leaf).
- **Painel que muda de tamanho usa `AnimatedSize`, não corte seco.** Um salto de 200px lê-se como "piscou", não como "encolheu". Ancorar no centro (`alignment: center`), a mesma âncora com que o painel se posiciona na janela, para que a parede do Leaf com uma anotação e com nove ocupem o mesmo ponto da tela; e envolver o conteúdo num viewport sem rolagem para que o quadro intermediário seja recortado em silêncio em vez de acusar estouro de layout.
- **Painel flutuante abre sempre no mesmo ponto da tela, seja qual for a altura dele.** A janela 0 nasce com o centro a 42% da altura útil da tela do cursor (um pouco acima do centro, como o Spotlight — o centro exato parece baixo demais para algo que se lê de relance) e cada painel se centraliza dentro dela. Foi assim que o Leaf deixou de abrir grudado no topo: enquanto cada painel escolhia a própria fração de âncora, um painel alto só cabia na tela nascendo mais alto, e o mesmo atalho apertado duas vezes seguidas em módulos diferentes jogava o conteúdo em alturas diferentes. A janela é presa dentro da área útil para que a parede cheia do Leaf, que ocupa quase toda a altura dela, nunca saia pela borda de baixo. Exceção legítima à regra de não centralizar de `spacing.md`: a referência aqui é a tela inteira, um ponto fixo, não a largura variável de um conteúdo.
- **Janela que aparece por atalho abre na tela onde está o cursor.** Vale para o painel flutuante (`OverlayWindow`) e para o Hub (`HubWindowChannel`): com dois monitores, uma janela que abre no outro monitor é indistinguível de um aplicativo travado — ela ainda rouba o foco do teclado, e quem apertou o atalho fica digitando no vazio. O Hub só é reposicionado quando vem de escondido; arrastá-lo para um monitor e vê-lo pular de volta no próximo atalho seria pior que o problema.
- **Trocar de painel nunca mostra o painel anterior.** A janela guarda o último quadro desenhado e o reexibe antes de o Flutter desenhar o novo, então `OverlayWindow.hide` apaga o painel e espera um quadro antes de esconder. Piscar o módulo errado por um quadro é o tipo de detalhe que faz a suíte parecer três apps mal colados em vez de um.
- **Módulo que só tem um interruptor ainda tem painel.** O Awake poderia viver só no menu da barra, mas o painel é onde a duração é escolhida no momento de ligar — e é o que mantém a promessa de que todo módulo se opera pelo teclado, do atalho global ao Enter.
- **Lista com detalhe nunca expande a linha; o que muda é para onde o detalhe vai.** Expandir a linha empurra todo o resto da tela para baixo a cada clique, então a escolha é entre duas superfícies, decidida pelo **tamanho do que há para ler**:
  - **Diálogo de consulta**, quando o detalhe são algumas linhas que se leem e se fecham — o histórico do Focus (`FocusSessionDialog`): a linha responde "quando, quanto e em quê", e as anotações e o resumo abrem por cima.
  - **Região dedicada, com a janela crescendo para caber**, quando o detalhe é um documento — a reunião do Echo (`HubDetailRegion` + `EchoReader`): a lista continua larga na área de conteúdo, e abrir uma reunião faz a **janela do Hub crescer 480px para o lado** (`HubWindowChannel.setDetailWidth`), com a leitura ocupando a altura inteira.

    Os três desenhos anteriores e por que caíram: empilhado sob a lista, meia hora de transcrição empurrava as reuniões para fora da tela; num diálogo, trocar de reunião obrigava a fechar e reabrir; dividindo a área de conteúdo com a lista, a leitura ficava espremida em ~350px, que é pior que não ter região nenhuma. **A regra que sobrou: espaço para um documento não sai de espaço que já estava ocupado — sai da janela.**

    O ciclo da região é curto e fechado: abre no clique do item, fecha por `esc`, pelo ✕, ao trocar de módulo e quando o item deixa de existir. Uma região que fica aberta sozinha é uma coluna encostada na tela errada — e a janela, que cresceu para caber nela, não volta.
  Quando o detalhe tem duas faces (resumo e transcrição), elas se alternam num `EgSegmentedControl` — **uma de cada vez**. Dois documentos longos no mesmo scroll é a definição de "informação demais numa tela só".
- **Lista de conteúdo se agrupa por dia.** O dia é do grupo (`EgSectionLabel` com "Hoje"/"Ontem"/"23 jul", via `DayGroups`), e a linha fica com a **hora**. Repetir a data em toda linha foi o que fez o histórico do Focus escrever "Hoje ·" cinco vezes na mesma tela.
- **Linha de lista tem altura fixa e colunas fixas.** Uma linha que cresce quando tem metadado e encolhe quando não tem deixa a lista serrilhada; um número que muda de posição a cada linha não dá para comparar correndo o olho. Hora à esquerda, nome no meio, número à direita — e o acessório ("1 anotação · resumo") entra no mesmo parágrafo do nome, atrás dele, para o corte por ellipsis comer o acessório primeiro (é a mesma solução do apelido do Pin).
- **Ação destrutiva não encosta na lista.** "Limpar histórico" colado na última sessão, com um divisor por cima, lia-se como mais uma linha — com um botão vermelho do lado. Vai separada por um respiro, sem divisor.
- **Gráfico só quando ele responde o que o número não responde.** A faixa de sete barras do Focus (`FocusWeekStrip`) existe porque "1h 35min hoje" não diz se a semana está indo; sem eixo, sem grade, sem legenda de valor, e com accent em um dia só — hoje. Um gráfico que só ilustra o número que já está escrito ao lado é decoração, e cai na regra de `anti-patterns.md`.
- **Rótulo de botão descreve o que ele faz, nunca o que o usuário conseguiu.** No fim de uma sessão do Focus o botão é "Encerrar" (fecha o ciclo) e não "Concluir", que se lia como "concluí a tarefa" — uma afirmação sobre o trabalho que o app não tem como saber. Se o produto não registra o desfecho, a microcopy não pode insinuar que registra.
- **Controle desabilitado mostra o valor efetivo, não o guardado.** Quando "Utilizar apenas Pomodoro" anula as duas perguntas, os toggles delas aparecem **desligados** e apagados — não ligados e apagados. Um controle ligado promete um comportamento; se ele não vai acontecer, exibi-lo ligado é mentira, e a opacidade sozinha não desfaz a promessa. Desligar o modo devolve as escolhas guardadas.
- **O que é título não se repete no corpo.** O diálogo de detalhe usa a atividade como título, então ela sai da lista de anotações — a mesma frase duas vezes na mesma tela é ruído, não reforço.
- **Um painel que muda de estado mantém o esqueleto.** No Focus, partida/contando/concluído usam o mesmo bloco (rótulo da fase → número grande → ação principal): o que muda é o conteúdo, não o layout, e o olho não precisa reencontrar nada.

## A matriz de estado (`EgSurfaceStyle`)

Precedência, do mais forte para o mais fraco — vale para **todo** componente interativo do app:

| Estado | Vence quem | Por quê |
|---|---|---|
| `disabled` | todos | o controle não responde: nenhum outro estado é verdade |
| `selected` | pressed, hover, focus | é onde o teclado está, a informação mais durável da tela |
| `pressed` | hover, focus | feedback do clique acontecendo agora |
| `hover` = `focus` | rest | mesma superfície: o anel de foco precisa de fundo opaco sob ele |
| `rest` | — | repouso |

Duas consequências que não se negociam: `hover` e `focus` compartilham a superfície (quem os distingue é o anel, que só o teclado acende), e `selected` **nunca** é a mesma cor que `hover` (seleção é accent em baixa opacidade; hover é neutro).

Colunas disponíveis: `row` (linha de lista, item de sidebar), `ghost` (botão de ícone — sem superfície em repouso, então é o conteúdo que reage), `card` (superfície própria em repouso), `segment` (pílula do segmented control), `primary`, `secondary` e `destructive` (botões).

A tabela inteira, desenhada, mora no golden `test/goldens/design_state_matrix.png` — a folha de estados do design system, com as sete colunas em seis estados e os componentes reais abaixo, hover e pressed inclusive. Regenerar com `flutter test --run-skipped -t preview --update-goldens`.

## Botões

- **Hierarquia de botão**: primário (preenchido, cor de destaque, um único por contexto/tela), secundário (borda ou superfície neutra elevada, sem preenchimento colorido), terciário/texto (sem borda nem fundo, só texto — usado para ações de baixa prioridade, tipo "Cancelar").
- Nunca mais de um botão primário visível ao mesmo tempo no mesmo contexto — isso força uma decisão editorial real sobre qual é *a* ação mais importante daquela tela.
- Botões destrutivos (deletar, remover, descartar) usam a cor semântica de erro, mas ainda com moderação — normalmente como botão secundário/com borda em vez de preenchido, reservando o preenchimento vermelho sólido só para confirmações finais em modais de risco alto.
- Tamanho padrão: altura 28–32px, padding horizontal 12–16px, radius 6–8px (ver `spacing.md`).
- Ícone dentro de botão é opcional e só deve existir se adicionar clareza real — nunca ícone + texto redundantes só por preenchimento visual.
- Estado disabled reduz opacidade (~40–50%) e remove qualquer sombra/elevação, deixando claro visualmente que a ação não está disponível agora.

## Campos de busca

O campo de busca é provavelmente o componente mais importante do Evergreen dado o DNA "Raycast/Maccy" do produto — deve parecer instantâneo e central à experiência, sem parecer um formulário de website.

- Fundo levemente diferente da superfície ao redor (um degrau, não um contraste forte), borda sutil ou ausente em repouso, borda com cor de destaque ao ganhar foco.
- Ícone de lupa à esquerda, discreto (cor `text/tertiary`), nunca colorido.
- Placeholder claro e específico ao contexto (nunca genérico tipo "Buscar...", prefira algo como "Buscar tarefas, projetos ou tags"), sempre em `text/tertiary`.
- Resultado aparece **enquanto a pessoa digita** (busca instantânea, sem botão "buscar" separado) sempre que tecnicamente viável — essa é uma expectativa herdada diretamente do Raycast e do Spotlight do próprio macOS.
- Atalho de teclado para focar a busca deve estar sempre disponível e, quando fizer sentido, exibido discretamente dentro do próprio campo (ex: um badge pequeno de atalho alinhado à direita, tipo "⌘K"), seguindo o padrão de `ux.md`.

## Sidebars

- Largura fixa ou redimensionável dentro de um intervalo definido (ex: 200–320px), nunca fluida livremente sem limites.
- Fundo levemente distinto da área de conteúdo principal (superfície elevada ou levemente translúcida com blur, ver `colors.md`), criando separação sem precisar de uma borda grossa.
- Itens de navegação em lista vertical, densidade média (36–40px de altura por item), com ícone opcional à esquerda (só se ajudar reconhecimento rápido, não decoração) e label em `text/primary`.
- Item ativo/selecionado usa a cor de destaque em baixa opacidade como fundo da linha inteira (não só sublinhado, não só o texto colorido) — ver `colors.md` para estados.
- Seções dentro da sidebar são separadas por um label pequeno em caps (ver `typography.md`) e um espaçamento de grupo (16–24px), nunca por uma linha divisória grossa.
- Sidebar deve poder ser recolhida/expandida via atalho de teclado, com uma transição curta de slide (ver `motion.md`).

## Listas

O componente mais usado no Evergreen — praticamente todo conteúdo real do app (tarefas, itens, resultados, histórico) vive dentro de uma lista.

- Cada linha é uma unidade clicável inteira (não apenas o texto — ver `spacing.md` sobre área de clique), com hover sutil de superfície.
- Estrutura padrão de linha: elemento à esquerda (ícone/checkbox/avatar, opcional), bloco de texto central (título em `text/primary`, metadado opcional em `text/secondary` abaixo ou ao lado), elementos à direita (badge de status, timestamp, ação contextual que só aparece no hover).
- Ações secundárias por linha (editar, deletar, mais opções) só aparecem visualmente **no hover da linha**, mantendo a lista limpa em repouso — outro comportamento característico de listas macOS bem feitas (Mail, Finder, Things).
- Divisores entre linhas são opcionais e, quando existem, extremamente sutis (`border/subtle`) — muitas vezes o próprio espaçamento e a mudança de superfície no hover já bastam para separar itens, sem precisar de linha alguma.
- Listas longas devem suportar seleção múltipla (Shift/Cmd+clique) e navegação completa por teclado (setas para mover, Enter para abrir/confirmar, ver `ux.md`).
- Agrupamento (ex: "Hoje", "Ontem", "Esta semana") usa o mesmo padrão de label pequeno em caps das sidebars, nunca um card ou fundo colorido para separar grupos.

## Tabelas

Use tabela apenas quando há genuinamente múltiplas colunas de dados comparáveis linha a linha (ex: uma visão de configurações avançadas, um histórico com várias propriedades). Se os dados têm essencialmente uma dimensão principal (título) e metadados secundários, use lista, não tabela — é mais comum precisar de lista do que de tabela no Evergreen.

- Cabeçalho de coluna discreto (`text/secondary`, peso medium, tamanho pequeno), sem fundo colorido ou sombra separando do corpo.
- Alinhamento de coluna consistente com o tipo de dado (texto à esquerda, números à direita ou centralizados com algarismos tabulares).
- Linha em hover recebe leve mudança de superfície, igual ao padrão de listas.
- Sem zebra-striping (linhas alternadas coloridas) por padrão — isso tende a ficar "carregado" em uma paleta já discreta; se a densidade de dados realmente exigir, use uma diferença extremamente sutil, quase imperceptível conscientemente.
- Redimensionamento de coluna, quando suportado, deve ter feedback visual claro mas discreto (linha de arraste fina na cor de destaque).

## Popups e menus de contexto

- Aparecem ancorados ao elemento que os disparou (não centralizados na tela), com uma pequena seta/indicador de origem quando apropriado ao contexto.
- Superfície `surface/overlay` com radius 8–10px e sombra funcional (a única categoria de sombra que deve ser proeminente no Evergreen, porque aqui a sombra comunica genuinamente "isso está flutuando por cima e vai desaparecer").
- Itens de menu seguem o mesmo padrão de linha de lista, densidade alta (28–32px por item), com atalho de teclado alinhado à direita quando existir (ver `ux.md`).
- Fecham instantaneamente ao clicar fora, pressionar Escape, ou selecionar uma opção — sem exigir um botão "fechar" explícito na maioria dos casos.
- Aparecem/somem com fade + leve escala/translação mínima (ver `motion.md`), nunca com slide longo ou bounce.

## Dropdowns / Selects

- Visualmente equivalentes a um botão secundário em repouso, com um pequeno chevron indicando que abre opções.
- Ao abrir, comporta-se como um popup ancorado (ver acima), com a opção atualmente selecionada visualmente destacada (fundo com a cor de destaque em baixa opacidade) dentro da lista de opções.
- Suporta navegação completa por teclado (setas + Enter, digitar para pular para a opção correspondente).

## Modais / Dialogs

Modais no Evergreen são reservados para decisões que genuinamente interrompem o fluxo — confirmações destrutivas, formulários curtos que precisam de foco total, configurações que não cabem em um popup simples. Eles não são o padrão default para "mostrar mais informação"; um painel lateral de detalhe é geralmente preferível a um modal quando a informação é consultiva, não uma decisão.

- Centralizado na janela (exceção legítima à regra geral de não centralizar, ver `spacing.md`), com um overlay de fundo escurecido sutilmente (não um blackout total).
- Largura contida (raramente mais que ~480–560px para modais de conteúdo padrão; modais de confirmação são ainda menores, ~320–400px).
- Estrutura: título curto e direto (sem ponto final, sem tom de marketing), corpo objetivo, ações no rodapé alinhadas à direita com o botão primário mais à direita e o secundário/cancelar à esquerda dele (convenção nativa macOS).
- Modais de confirmação destrutiva devem deixar claro na cópia qual é a consequência irreversível (ex: "Esta ação não pode ser desfeita"), e o botão de confirmação usa a cor semântica de erro apenas se a ação for de fato irreversível/destrutiva.
- Fecham com Escape sempre, exceto em casos raros onde isso seria genuinamente perigoso (ex: uma ação crítica em progresso).

## Menus contextuais (clique direito)

- Seguem exatamente o padrão de popups/menus descrito acima.
- Agrupam ações relacionadas com um divisor sutil entre grupos (ex: ações de edição, depois um divisor, depois ações destrutivas no final da lista).
- Ações destrutivas (deletar, remover) ficam sempre no fim da lista e usam a cor semântica de erro no texto/ícone, nunca fundo vermelho sólido no item inteiro (isso seria chamativo demais para um menu de contexto).

## Badges e indicadores

- Badges são pequenos, com radius 4–6px (ou totalmente arredondados quando forem numéricos/circulares, ex: contador de notificação), padding horizontal mínimo (6–8px), texto pequeno (10–11px) em peso medium.
- Cor de badge segue estritamente o sistema semântico (`colors.md`) — nunca uma cor arbitrária "só para diferenciar visualmente" sem que ela represente um estado real (status, prioridade, categoria).
- Prefira fundo em baixa opacidade da cor semântica com texto na cor semântica em versão mais saturada/escura, em vez de fundo sólido saturado com texto branco — o primeiro padrão é mais discreto e combina melhor com a paleta majoritariamente neutra do Evergreen.
- Indicadores de status simples (ponto colorido, sem texto) são preferíveis a badges com texto sempre que o significado já for aprendido pelo usuário (ex: um ponto verde para "online/ativo" depois que o padrão foi estabelecido uma vez na interface).

## Loading

- Spinner pequeno (16–20px), monocromático (usando `text/secondary` ou a cor de destaque em versão discreta), nunca colorido de forma chamativa ou com múltiplas cores.
- Aparece só depois de um pequeno atraso (ver `motion.md`) para operações que podem terminar rápido o suficiente para não precisar de indicador algum.
- Para operações mais longas com progresso mensurável, uma barra de progresso fina (2–3px de altura) é preferível a um spinner indeterminado, porque comunica informação real (quanto falta) em vez de apenas "algo está acontecendo".
- Nunca usar tela cheia de loading no meio do uso do app — se uma operação bloqueia a tela inteira por mais que um instante muito breve, repense a arquitetura antes de aceitar isso como "normal" e só estilizar o spinner.

## Notificações / Toasts

- Aparecem em uma posição consistente e previsível (geralmente canto superior direito ou próximo à barra de título, seguindo convenções nativas do macOS), nunca centralizadas na tela.
- Curtas, objetivas, sem ícone decorativo além de um indicador semântico discreto quando aplicável (sucesso/erro/aviso).
- Desaparecem automaticamente após poucos segundos (a menos que exijam uma ação da pessoa, caso em que se comportam mais como um popup persistente com botão de dispensar).
- Nunca empilhar mais que 2–3 notificações simultâneas visíveis — se isso acontece com frequência, o problema é de frequência de eventos, não de estilo de notificação.

## Empty states

Devem ser raros no Evergreen (ver `philosophy.md`), mas quando existem:

- Mensagem curta e funcional (o que fazer a seguir), nunca um parágrafo longo explicando o conceito do app.
- Sem ilustração grande e colorida — no máximo um ícone discreto do próprio sistema de ícones do app, em `text/tertiary`, do mesmo tamanho que teria em qualquer outro contexto (nunca um ícone gigante centralizado, isso é padrão de app mobile/web consumer).
- Nunca ocupar a tela inteira com espaço vazio ao redor de uma mensagem pequena — mesmo um empty state deve respeitar a densidade e a composição de regiões fixas da tela (ver `spacing.md`), aparecendo dentro da área de conteúdo normal, não como uma "tela especial" separada.
- Se houver uma ação clara para resolver o estado vazio (ex: "criar o primeiro item"), essa ação é um botão secundário discreto, não um botão primário gigante e colorido — o vazio não é uma oportunidade de venda, é apenas um estado transitório do trabalho da pessoa.

## Cards (usar apenas quando genuinamente necessário)

Cards — um container com fundo, borda e/ou sombra ao redor de um bloco de conteúdo — são o componente mais fácil de abusar, e o Evergreen deve resistir ativamente a essa tentação. Prefira lista, tabela ou apenas agrupamento por espaçamento antes de recorrer a um card.

Um card é apropriado quando:

- O conteúdo é genuinamente um objeto autocontido que a pessoa vai comparar visualmente lado a lado com outros do mesmo tipo (ex: uma grade de opções de tema/aparência nas configurações).
- Existe uma necessidade real de separação visual forte entre dois blocos de configuração muito diferentes na mesma tela.

Quando um card for usado:

- Borda sutil (`border/subtle`) é preferível a sombra como método de separação; use sombra apenas se o card também tiver alguma interatividade de "flutuar" (ex: arrastar).
- Nunca aninhar cards dentro de cards — se um bloco de conteúdo dentro de um card parece precisar do mesmo tratamento visual do card pai, isso é sinal de que a hierarquia deveria ser resolvida com espaçamento e tipografia, não com mais um container.
- Radius consistente com a escala definida em `spacing.md` (8px para cards de tamanho médio), nunca radius alto de app consumer.
- Um grid de cards (quando genuinamente necessário) deve manter espaçamento consistente e denso o suficiente para não parecer uma vitrine de produtos — 12–16px de gap entre cards é geralmente suficiente, não 32px+.

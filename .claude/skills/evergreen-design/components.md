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
| `EgButton` | `eg_button.dart` | botão em 3 variantes (`primary`, `secondary`, `destructive`) | default · hover · pressed · focus · disabled · `isLoading` |
| `EgIconButton` | `eg_button.dart` | botão só de ícone, 36×36, com `tooltip` opcional | default · hover · pressed · focus · disabled |
| `EgToggle` | `eg_toggle.dart` | switch de preferência | default · hover · pressed · focus · disabled · on/off |
| `EgShortcutRecorder` | `eg_shortcut_recorder.dart` | os key-caps de um atalho global + o botão que põe a tela à escuta; devolve a combinação apertada e não decide nada | repouso · gravando |
| `EgSegmentedControl` | `eg_segmented_control.dart` | escolha única entre 3–4 opções curtas; ← → quando focado; `bare` tira a caixa (fila de filtros do Pin); sem largura quebra linha, a não ser que tenha `iconOf` — aí as opções não escolhidas viram o ícone e a fila fica numa linha (o Pin com todos os tipos, onde os ícones são os mesmos da lista) | default · hover · pressed · focus · selected |
| `EgSearchField` | `eg_search_field.dart` | campo de busca (`bare` para a linha do topo do overlay) | default · focus (borda accent) · placeholder |
| `EgTextField` | `eg_text_field.dart` | campo de texto de uma linha que a pessoa escreve e confirma (atividade e resumo do Focus); `bare` + `style` para renomear no lugar um título (o nome da reunião do Echo), no degrau dele | default · focus (borda accent) · disabled |
| `EgHintBar` / `EgHint` | `eg_hint_bar.dart` | rodapé de atalhos de um painel operado por teclado | — |
| `EgPanel` | `eg_panel.dart` | superfície flutuante com borda, radius e sombra | `elevated` on/off |
| `EgIconBadge` | `eg_panel.dart` | quadrado arredondado que abriga um ícone | — |
| `EgConfirmDialog` | `eg_confirm_dialog.dart` | confirmação de ação irreversível (360px, ações à direita, Esc = cancelar) | — |
| `EgSettingsPage` | `eg_settings_section.dart` | a pilha de tópicos de uma tela de preferência; dá o vão entre eles | — |
| `EgSettingsCard` | `eg_settings_card.dart` | o cartão de um assunto: rótulo fora, linhas dentro, divisores por conta dele | `tone: destructive` tinge fundo e borda de vermelho |
| `EgScreenHeader` | `eg_screen_header.dart` | o topo de uma tela do Hub: título em `display`, pílula do interruptor mestre e abas | — |
| `EgStatusStrip` | `eg_status_strip.dart` | a faixa que diz o que está acontecendo, **sem controle nenhum** | clicar abre o painel |
| `EgStatCard` / `EgStatRow` | `eg_stat_card.dart` | número grande com etiqueta em cima e comparação embaixo | — |
| `EgPill` / `EgFilterPills` / `EgTogglePill` | `eg_pill.dart`, `eg_toggle_pill.dart` | estado, filtro de lista e interruptor com nome | — |
| `EgShortcutGrid` | `eg_shortcut_grid.dart` | todas as teclas do app numa grade de duas colunas | — |
| `EgSettingsRow` | `eg_settings_row.dart` | linha de configuração: rótulo + descrição + controle | `showDivider` on/off · `.toggle` · `.field` |
| `EgBrandMark` | `eg_brand_mark.dart` | a marca do Evergreen — o canivete, com a lâmina em qualquer ponto entre recolhida e travada | `openness` 0→1 |
| `EgNavTile` | `eg_nav_tile.dart` | item de navegação: badge de ícone + título + linha de apoio | default · hover · pressed · focus · selected |
| `EgOverlayShell` | `eg_overlay_shell.dart` | casca dos painéis flutuantes: entrada, blur, clique fora, centralização | — |
| `EgSectionLabel` | `eg_section_label.dart` | label de grupo em caixa alta | — |
| `EgDayHeader` | `eg_day_header.dart` | o cabeçalho de um dia numa lista de histórico: o dia à esquerda, o somado dele à direita | — |
| `EgKeyCap` / `EgShortcutDisplay` | `eg_key_cap.dart` | tecla e sequência de teclas | — |
| `EgEmptyState` | `eg_empty_state.dart` | estado vazio discreto (ícone pequeno + título + mensagem) | — |
| `EgCountdown` | `eg_countdown.dart` | bloco de painel que conta tempo: situação em caps + número grande + progresso | `isMuted` on/off |
| `EgSpinner` | `eg_spinner.dart` | indicador de trabalho em curso: 16px por padrão, traço de 2px, monocromático | `size` · `color` |
| `EgIcon` | `eg_icon.dart` | ícone de path customizado (não Material Icons) | — |
| `EgBackground` | `eg_background.dart` | fundo de janela com vinheta + brilho verde | — |

Regras de manutenção deste inventário:

- Componente novo compartilhado nasce com prefixo `Eg`, em `lib/shared/widgets/`, e entra nesta tabela junto do commit que o cria.
- **Botão que dispara trabalho demorado usa `isLoading` — nunca sai da tela.** Trocar o botão por nada enquanto a ação corre tira do lugar o único elemento que a pessoa estava olhando: a linha sobe, o que estava ao lado escorrega para debaixo do cursor, e não sobra nada dizendo que algo acontece. Carregando, o rótulo continua segurando a largura e o spinner ocupa o centro dele, então o botão não muda de tamanho. Isso **não** é o estado desabilitado: ocupado não esmaece, porque o botão não está indisponível — está trabalhando. Era o defeito do "Refazer resumo" do Echo até a v0.4.10.
- **Progresso com número ganha de spinner sempre que o número existe.** Se a operação acontece em partes contáveis, a tela diz "bloco 2 de 4" em vez de girar uma ampulheta — e diz isso **sem apagar** o conteúdo anterior, quando há um (refazer um resumo mantém o resumo antigo legível enquanto o novo não chega). O spinner é o que sobra quando não há nada a contar.
- Estado de interação vem do `EgHoverable`, nunca de um `MouseRegion` próprio — é o que garante que hover, pressed e foco se comportem igual em todo o app.
- **A aparência de cada estado vem da matriz (`EgSurfaceStyle`), nunca de uma cadeia de `if`s escrita no widget.** Se o componente precisa de uma combinação que a matriz não tem, ele compõe uma `EgSurfaceStyle` própria a partir dos tokens (é o que o cartão do Leaf faz com a vaga livre e com o cartão em edição) — não reescreve a ordem de precedência. Antes da matriz a mesma cadeia existia copiada em seis arquivos, e as cópias já tinham divergido: um componente sem `pressed`, outro sem reação ao foco, e a ordem entre "selecionado" e "pressionado" mudando de um para o outro.
- Componente específico de um módulo (por exemplo `PinListItem`) **não** ganha prefixo `Eg` e não entra aqui; se um segundo módulo precisar dele, aí sim ele é promovido a `Eg*`.

## Padrões de tela já estabelecidos (reusar, não reinventar)

Estas decisões foram tomadas no v0.1 e valem como padrão do produto. Um módulo novo que precise da mesma coisa usa o mesmo arranjo:

- **Hub = sidebar de módulos + painel de detalhe.** A sidebar lista todos os módulos (inclusive os não lançados, esmaecidos, com a versão prevista no lugar da tagline); o detalhe abre com um cabeçalho compacto (nome + tagline) e as configurações abaixo. Os módulos ficam **colados no topo** da sidebar, sem cabeçalho de grupo acima deles: são eles que a pessoa vem procurar, e cada linha acima empurra o último módulo para o meio da janela.
- **Toda tela do Hub começa no topo, cheia ou vazia.** A área de detalhe rola, e um `SingleChildScrollView` encolhe até a altura do conteúdo quando ele cabe na janela — o `Row` do Hub precisa esticar (`CrossAxisAlignment.stretch`), senão a tela de um módulo curto abre com o texto no meio da janela enquanto as compridas abrem no topo. Duas telas do mesmo aplicativo não podem começar em alturas diferentes.
- **Preferências são `EgSettingsPage` + `EgSettingsCard` + `EgSettingsRow`.** O rótulo do assunto fica **fora** do cartão (dentro ele seria mais uma linha); as linhas ficam dentro, e **os divisores são do cartão**, não das linhas — uma linha que decide sozinha se tem divisor embaixo obriga cada tela a saber qual é a última. O respiro também é do cartão: tudo o que não é `EgSettingsRow` recebe recuo lateral e vertical dele.
- **A `EgSettingsPage` é uma coluna só, sempre.** Foram duas — par à esquerda, ímpar à direita — e o preço era o zigue-zague: o assunto seguinte ficava *ao lado* do atual e não abaixo dele, de modo que correr a tela de cima a baixo deixava de ser um movimento e passava a ser um vaivém. Meia largura era ainda onde as listas (as reuniões do Echo, os destinos do Nest) não cabiam, e o x de cada cartão mudava quando a região de leitura estreitava o conteúdo. A rolagem que uma coluna traz é o preço aceito, e é o menor dos dois: **rolar é previsível, procurar não.** O `banner` fica acima da pilha, e não como primeiro cartão: é a faixa de estado, que responde pela tela inteira e não por um assunto dela.
- **A linha de configuração tem 38 pt (46 com explicação), e é piso, não trava.** Quem **se mede** primeiro é o **controle**, não o rótulo. O rótulo guarda um piso de 116 px — e fica com **todo** o vão que sobra, para o controle parar sempre na borda do cartão: frouxo, ele encolhia até o texto e trazia o controle junto, e um cartão de cinco interruptores virava uma escadinha, cada um num x diferente conforme o tamanho da explicação.
- **Seletor não quebra em duas fileiras: ele desce.** Uma fila de opções em dois andares deixa de se ler como uma escolha entre poucas coisas — "PT-BR PT-PT EN" em cima e "ES" embaixo parece um item esquecido, não a quarta opção. Quando o controle não cabe ao lado do texto (piso do rótulo respeitado), ele vai **inteiro** para baixo do rótulo, encostado à esquerda, com a largura do cartão para si. Isso não sai de um `Row` com `Flexible`: a decisão depende de quanto o controle pediria se ninguém o apertasse, e quem pergunta isso é o render object da própria linha. As duas regras são medidas por `test/shared/eg_settings_row_test.dart`.
- **Abas onde há mais de um assunto** (Pin, Focus, Echo, Nest), montadas pelo `EgScreenHeader`. Módulo de um assunto só não tem aba: uma aba sozinha é a promessa de que existe outra.
- **A ordem dos tópicos de uma tela de preferência é fixa**, e vale para módulo existente ou novo:
  0. **O módulo, ligado ou desligado** — o interruptor mestre, montado pelo Hub e não pela tela (`ModuleSwitchSection` em `_content`), de modo que um módulo novo já nasce com ele. É o único tópico acima da lista, porque não é uma preferência do módulo: é a pergunta que decide se as preferências do módulo importam. Desligado, tudo abaixo dele fica apagado e sem resposta (`ModuleGate`). Ver `ux.md`.
  1. **O que aconteceu** — a lista do módulo (reuniões do Echo, sessões do Focus). Quem abre o módulo quer primeiro saber o que ele registrou, não mexer em ajuste.
  2. **O que ele faz** — os tópicos de comportamento, e dentro de cada um **os interruptores primeiro**: um `EgToggle` é a pergunta de sim ou não que decide se o resto do tópico importa. Seletores depois, campos de texto por último (são os mais altos, e afundam o que vem depois deles).
  3. **Limites e ações destrutivas** — o quanto se guarda, o "limpar". O limite mora junto da lista que ele governa, não num tópico só dele: uma seção inteira para uma pergunta é como a tela do Echo chegou a seis títulos para responder cinco coisas.
  4. **Atalho global** — sempre o penúltimo, e literalmente o mesmo widget em todas as telas: `GlobalShortcutSection(slot: ...)`, com os key-caps, o botão "Alterar" que grava uma combinação nova e a linha "Restaurar padrão" que só aparece quando há o que restaurar. Não escreva a seção à mão; ela era escrita sete vezes e virou um widget quando o atalho deixou de ser constante. **E é o único lugar da tela que imprime a tecla** — o outro é a barra lateral, fora dela. Ver `ux.md`.
  5. **Permissões** — sempre por último. Liberação é coisa de uma vez só: dois botões que se apertam no primeiro dia e nunca mais. No topo, empurravam para baixo tudo o que se ajusta no dia a dia, e a tela abria pedindo permissão em vez de mostrar o conteúdo. A exceção é o aviso de permissão **condicional** (o do auto-colar do Pin), que só aparece quando há problema e mora colado no interruptor que o causou — ele não é um tópico, é a consequência de uma linha.
- **Pergunta de primeira vez não é onboarding.** O Evergreen tem uma só — o nome de quem usa — e ela é a primeira linha da tela do aplicativo, com o cursor dentro, entregue pelo fim da abertura animada. Sem modal, sem carrossel, sem tela dedicada: é a mesma linha que fica ali para sempre, só com a descrição mais longa enquanto ainda não foi respondida. Respondida, vira linha comum. E ela é sempre pulável — o app inteiro funciona com ela em branco.
- **Campo de texto em preferência é `EgSettingsRow.field`**, não um rótulo com um campo solto embaixo: o controle desce para baixo do rótulo e ocupa a linha toda. Quem decide é o tamanho da resposta — um seletor cabe ao lado do rótulo, um texto de três linhas não. E quando uma tela tem dois campos, eles ficam **um debaixo do outro**, não um em cada ponta dela.
- **Configuração é escrita na hora.** Não existe botão "Salvar" em tela de preferência: mexer no controle já persiste. Também não existe confirmação de "salvo com sucesso" — a mudança visível no controle já é o feedback.
- **A marca da sidebar é a entrada do aplicativo, e mora no rodapé.** Clicar no logo do Evergreen abre as preferências do app (iniciar com o macOS, atalho do Hub, sobre), com os mesmos estados de seleção dos módulos. Um segundo item escrito "Evergreen" logo abaixo do logo seria o mesmo rótulo duas vezes na mesma lista. Fica embaixo, junto da versão, porque preferência de aplicativo é onde se vai de vez em quando — o topo pertence ao que se usa todo dia.
- **Quem abre o Hub de longe pode dizer onde ele deve cair.** Abrir a janela e *chegar* em algum lugar dela são duas coisas: o "Abrir no Hub" do painel do Echo pedia a janela e caía onde ela estivesse parada, então quem acabou de gravar uma reunião ia dar nas preferências do Pin. O destino é gasto ao ser lido (`HubDestination`) — é o pedido de **uma** abertura, não uma preferência de onde o Hub abre.
- **Preferência que a janela 0 obedece avisa a janela 0.** Toda tela de preferência grava na hora, sem botão de salvar — mas gravar no disco não avisa ninguém, e quem captura a área de transferência, segura a trava e escuta o atalho é a janela 0, com a própria cópia em memória. Desligar um tipo do Pin era escrito e ignorado: a tela mostrava desligado e o painel continuava guardando. Quem muda uma preferência **daquele** tipo chama o `reapply` do `ModuleSettingsHost`, e a janela 0 relê. O painel ainda relê ao abrir, de cinto: se o canal falhar, ele abre certo mesmo assim.
- **Desligar um tipo tira ele do Pin — da lista e da fila de filtros —, sem apagar nada.** O que a tela de preferências desliga tem de sumir do painel, senão ela diz uma coisa e o painel mostra outra. O que já está no banco fica: religar devolve o histórico inteiro, e apagar de vez continua sendo o cartão de apagar histórico, que pergunta antes.
- **Preferência de app não mora em tela de módulo.** Se a configuração vale para o Evergreen inteiro, ela pertence à tela do aplicativo — não à do módulo que por acaso nasceu primeiro.
- **Registro de módulo é o enum `EvergreenModule` + `_settingsFor`.** Adicionar um módulo é adicionar um valor ao enum e ligar sua tela de configuração no `switch`; nada de lista paralela de navegação.
- **Nome dado pelo usuário vem à frente do dado, sem escondê-lo.** No Pin o apelido ocupa o lugar do título da linha e o conteúdo continua atrás dele, menor e em `text/tertiary`, no mesmo parágrafo — o corte por ellipsis come o conteúdo primeiro e nunca o apelido. Substituir o conteúdo por completo faria a lista prometer algo que a cópia não cumpre; mostrar os dois em colunas separadas viraria tabela.
- **Filtro de lista é uma fila de pílulas logo abaixo da busca, e só mostra o que existe.** No Pin as opções saem dos tipos presentes no histórico, não do enum inteiro: um filtro que resultaria em zero é uma promessa vazia, e as sete pílulas juntas não caberiam nos 420px do painel. Sem caixa em volta (seria card dentro de card) e sem foco próprio — o teclado ali é da busca, e quem anda pela fila é o `⌘←`/`⌘→`. O filtro é recorte da vez, não preferência: sai junto da busca a cada abertura, e o `Esc` o desfaz antes de fechar o painel — ele esconde itens, e sair de um painel sem desfazer o que estava escondido é sair sem saber o que ficou para trás. Com um tipo só no histórico a fila nem aparece. **Comando não tem pílula** desde que a imagem entrou: o tipo continua (é dele que o Track conta o dia, e o ícone de terminal segue na linha), mas o que se procura num gerenciador de área de transferência é a captura de ontem, não o `git status`.
- **Imagem é mais uma linha da lista, não outra lista.** A miniatura entra no lugar do ícone de tipo, do mesmo tamanho e recortada no quadrado; a linha não cresce e não vira grade. O nome é o do arquivo, ou "Imagem 1280×720" quando ela não tem um. No preview (`Tab`) a imagem toma o lugar do texto, cabendo no cartão, e embaixo vem de onde ela veio: o caminho (selecionável), o site e o tamanho. Sem o arquivo no disco, a linha fica e o glifo de imagem volta no lugar da miniatura.
- **Lista longa se agrupa com `EgSectionLabel`,** não com card nem fundo colorido (no Pin: "FIXADOS" e "RECENTES").
- **Painel operado por teclado leva uma barra de dicas no rodapé** (`EgHintBar`) com os atalhos daquele contexto, variando conforme o estado da tela. É documentação embutida no lugar onde a dúvida aparece. A dica que não pode sumir (tipicamente o `esc`) vai no `trailing`, ancorada à direita. Uma dica com `onTap` vira também o alvo de mouse daquela tecla — reservado para a tecla que não tem outro alvo na tela (ver `ux.md`); o realce é a cor do rótulo, nunca uma superfície nova atrás dele.
- **Painel com duas listas empilhadas ordena pela frase que ele responde.** O Nest responde "o que está na prateleira, e para onde vai": em cima a pilha, embaixo as pastas. Os destinos ficam no rodapé por duas razões que se somam — são o **fim** do gesto, e são a parte **estável** da tela: a prateleira muda a cada arraste, as pastas favoritas ficam paradas por meses, e a lista que não muda em cima empurraria a que muda para baixo da dobra. As duas se distinguem por forma, não por posição: a linha de pasta leva uma marca verde à esquerda, senão a segunda lista se lê como a continuação da primeira.
- **Cabeçalho de coleção mostra a coleção, não o primeiro item dela.** A capa da prateleira é a miniatura do primeiro arquivo com a contagem no canto — como a foto de cima num maço —, e o texto ao lado responde o que a lista não responde de relance: quantos são, quanto pesam, de onde vieram. O primeiro **continua na lista**, clicável: um cabeçalho que *fosse* o primeiro item o tiraria de lá, e com ele a chance de escolher só ele. A contagem fica **sobre** a miniatura, não ao lado — ali ela diz "isto é um monte"; ao lado, seria mais um número numa linha de números.
- **Ordem que a máquina obedece é ordem que a tela mostra.** A prateleira sai na ordem em que encheu, então cada linha leva o seu lugar na fila à direita — e o número cede o lugar ao botão de tirar quando o mouse chega, porque ali só cabe um. Sem isso, "a pilha guarda a ordem" é uma promessa que só o código conhece.
- **O estado vazio também carrega o resultado da última ação.** No Nest, mandar a prateleira embora esvazia a lista, e o `EgEmptyState` que ocupa o lugar dela diz "12 arquivos copiados para Recibos · ⌘Z desfaz" em vez do convite de sempre. É a mesma superfície para as duas coisas de propósito: o lugar onde a lista estava é exatamente onde o olho já está quando ela some, e uma faixa de aviso à parte apareceria por dois segundos num painel que ficou vazio de qualquer jeito.
- **Painel flutuante é um só, compartilhado.** Pin, Focus, Leaf, Awake, Echo e Nest dividem a janela 0 e trocam de conteúdo por `OverlayPanel`; um módulo novo com atalho global entra ali, não em uma janela nova. Consequência de design: cada painel escolhe a própria largura (Pin 420/560 e Nest 420 — uma lista de nomes de arquivo pede a mesma coluna que uma lista de itens copiados; Focus 380, Awake e Echo 380 — mesmo arranjo do Focus, mesma largura; Leaf 528/778, a única que acompanha o conteúdo — e a única cuja largura é calculada, não escolhida: são os cartões, os vãos, o respiro e a borda do `EgPanel` somados, porque um pixel a menos recorta a última coluna), mas nenhum escolhe onde nasce, e nenhum implementa a própria casca: entrada, blur, clique fora e centralização vêm do `EgOverlayShell`. O tamanho da janela 0 (920x800) é ditado pelo maior painel e cresce sem mexer nos outros: todos são centralizados nela, que é transparente.
- **Cartão em grade só quando os itens são comparáveis lado a lado e poucos.** O Leaf é a exceção à preferência por lista: nove anotações curtas que precisam ser lidas *todas de uma vez*, sem rolar, não são uma lista — são um mural. A grade é **contígua e fixa**: apagar um cartão faz os seguintes subirem uma vaga (a parede não tem buraco), mas as nove vagas continuam desenhadas — as vazias em contorno tracejado, com o número. A parede encolhia junto, e isso foi implementado e descartado no uso: com a grade mudando de tamanho a cada gesto, o número de uma vaga só passava a existir quando ela era ocupada, e `7` não queria dizer nada antes de haver sete cartões. **O endereço fixo é o que faz o atalho de número ser decorável** — e num mural de nove, decorar é o ponto. O tracejado é o que impede a vaga vazia de parecer um cartão em branco.
- **Copiar de um mural não fecha o mural.** No Pin, copiar é o fim do gesto e o painel some: ali se procura um item num histórico de centenas. No Leaf são nove vagas que se sabem de cor, e quem copia costuma copiar dois seguidos — o endereço e o telefone. O que o sumiço dizia ("copiei") passa a ser dito por um aviso no próprio cartão, e o `esc` continua sendo a saída.
- **Painel que muda de tamanho usa `AnimatedSize`, não corte seco.** Um salto de 200px lê-se como "piscou", não como "encolheu". Ancorar no centro (`alignment: center`), a mesma âncora com que o painel se posiciona na janela, para que a parede do Leaf com uma anotação e com nove ocupem o mesmo ponto da tela; e envolver o conteúdo num viewport sem rolagem para que o quadro intermediário seja recortado em silêncio em vez de acusar estouro de layout.
- **Painel flutuante abre sempre no mesmo ponto da tela, seja qual for a altura dele.** A janela 0 nasce com o centro a 42% da altura útil da tela do cursor (um pouco acima do centro, como o Spotlight — o centro exato parece baixo demais para algo que se lê de relance) e cada painel se centraliza dentro dela. Foi assim que o Leaf deixou de abrir grudado no topo: enquanto cada painel escolhia a própria fração de âncora, um painel alto só cabia na tela nascendo mais alto, e o mesmo atalho apertado duas vezes seguidas em módulos diferentes jogava o conteúdo em alturas diferentes. A janela é presa dentro da área útil para que a parede cheia do Leaf, que ocupa quase toda a altura dela, nunca saia pela borda de baixo. Exceção legítima à regra de não centralizar de `spacing.md`: a referência aqui é a tela inteira, um ponto fixo, não a largura variável de um conteúdo.
- **Janela que aparece por atalho abre na tela onde está o cursor.** Vale para o painel flutuante (`OverlayWindow`) e para o Hub (`HubWindowChannel`): com dois monitores, uma janela que abre no outro monitor é indistinguível de um aplicativo travado — ela ainda rouba o foco do teclado, e quem apertou o atalho fica digitando no vazio. O Hub só é reposicionado quando vem de escondido; arrastá-lo para um monitor e vê-lo pular de volta no próximo atalho seria pior que o problema.
- **Trocar de painel nunca mostra o painel anterior.** A janela guarda o último quadro desenhado e o reexibe antes de o Flutter desenhar o novo, então `OverlayWindow.hide` apaga o painel e espera um quadro antes de esconder. Piscar o módulo errado por um quadro é o tipo de detalhe que faz a suíte parecer três apps mal colados em vez de um.
- **O painel de um módulo mostra o instrumento dele, não um relatório sobre ele.** No Focus é o anel: o tempo **dentro** do progresso, num mostrador só. Eram duas coisas soltas — número grande no alto, linha de 2px alguns blocos abaixo —, e para saber quanto faltava era preciso ler o relógio e depois procurar a linha, que sozinha não dizia de quê. O anel acende o que **falta**, não o que passou: a pergunta do painel é "quanto falta", e ele esvazia como ampulheta (a tela de conclusão é a exceção, e passa o anel cheio — ali o círculo fechado quer dizer "a volta inteira", não "sobrou tudo"). O mesmo anel nos três estados, pelo mesmo motivo de sempre: o número não muda de lugar quando a tela troca de estado.
- **Painel de captura mostra o que está entrando, por faixa.** Gravando, o painel do Echo deixa de ser um cronômetro e vira um gravador: dois equalizadores — "Você" em accent, "Sistema" em `tide` —, cada barra uma **banda de frequência medida** pelo próprio gravador (FFT sobre os últimos 32 ms, dez vezes por segundo). Nada ali é animação decorativa; barra sem medida seria enfeite fingindo ser instrumento. A pergunta de quem abre o painel no meio de uma reunião não é "quanto tempo já deu" (o relógio continua ali, do tamanho de um relógio, no canto), é "está entrando som?" — e faixa muda é o defeito mais caro do módulo, porque só aparece no fim, quando o áudio já foi. Silêncio não some da tela: vira a pista apagada da barra, senão uma faixa muda ficaria indistinguível de uma faixa que não existe.
- **Medidor de som fica parado e pula; ele não anda para o lado.** A primeira versão era uma fita: cada barra um instante passado, a fila correndo para a esquerda. Parecia um arquivo de áudio sendo reproduzido — e o que se quer saber é o **agora**, não os últimos dois segundos. Um equalizador responde isso numa imagem só, e é o que justifica medir por banda: com um número por faixa, todas as barras teriam a mesma altura, e desenhá-las diferentes seria inventar. **Se o desenho pede variedade que o dado não tem, ou se mede mais, ou se desenha menos.** A altura interpola em 100 ms (o intervalo entre duas medidas) — sem isso o equalizador treme em degraus em vez de subir.
- **O ponto de "gravando" não pisca.** Ele muda de estado, não de brilho: cheio gravando, vazado pausado. Movimento periférico permanente ao lado de uma reunião é exatamente o que tira a atenção de quem está tentando prestar atenção em outra pessoa.
- **Texto ao vivo mostra a última fala, não o acumulado.** Ele é a prova de que o Echo está entendendo, não um documento para acompanhar — ler a reunião enquanto ela acontece é o oposto de estar nela. O que vale sai do arquivo, depois.
- **A ação mais importante da tela nem sempre é verde.** "Pausar" é `EgButton.neutralStrong` — branca, texto escuro: o accent quer dizer **ligado** ou **ação primária**, e pausar não é nem uma coisa nem outra. Pelo mesmo motivo "Encerrar" deixou de ser vermelho: a sessão encerrada vai para o histórico com o que foi focado, e o vermelho prometia um risco que não existe. Destrutivo é o que **apaga**.
- **Módulo que só tem um interruptor ainda tem painel.** O Awake poderia viver só no menu da barra, mas o painel é onde a duração é escolhida no momento de ligar — e é o que mantém a promessa de que todo módulo se opera pelo teclado, do atalho global ao Enter.
- **Lista com detalhe nunca expande a linha; o que muda é para onde o detalhe vai.** Expandir a linha empurra todo o resto da tela para baixo a cada clique, então a escolha é entre duas superfícies, decidida pelo **tamanho do que há para ler**:
  - **Diálogo de consulta**, quando o detalhe são algumas linhas que se leem e se fecham — o histórico do Focus (`FocusSessionDialog`): a linha responde "quando, quanto e em quê", e as anotações e o resumo abrem por cima.
  - **Região dedicada, com a janela crescendo para caber**, quando o detalhe é um documento — a reunião do Echo (`HubDetailRegion` + `EchoReader`): a lista continua larga na área de conteúdo, e abrir uma reunião faz a **janela do Hub crescer 480px para o lado** (`HubWindowChannel.setDetailWidth`), com a leitura ocupando a altura inteira.

    Os três desenhos anteriores e por que caíram: empilhado sob a lista, meia hora de transcrição empurrava as reuniões para fora da tela; num diálogo, trocar de reunião obrigava a fechar e reabrir; dividindo a área de conteúdo com a lista, a leitura ficava espremida em ~350px, que é pior que não ter região nenhuma. **A regra que sobrou: espaço para um documento não sai de espaço que já estava ocupado — sai da janela.**

    A região se anuncia: `EgSectionLabel('Leitura')` no topo, com o ✕ **na linha da etiqueta**, não na do título. As duas coisas são da região; o título é do que está aberto dentro dela — alinhado com o título, o ✕ dava a impressão de fechar a reunião, e não a leitura. É a casca (`HubDetailRegion`) que desenha isso, então vale para todo leitor: hoje o do Echo e o do Focus.

    O ciclo da região é curto e fechado: abre no clique do item, fecha por `esc`, pelo ✕, ao trocar de módulo e quando o item deixa de existir. Uma região que fica aberta sozinha é uma coluna encostada na tela errada — e a janela, que cresceu para caber nela, não volta.
  Quando o detalhe tem duas faces (resumo e transcrição), elas se alternam num `EgSegmentedControl` — **uma de cada vez**. Dois documentos longos no mesmo scroll é a definição de "informação demais numa tela só".
- **Ação que age sobre o documento aberto mora na linha do seletor; ação que age sobre o item mora no rodapé.** Na leitura do Echo, "Copiar" e "Exportar" ficam à direita do `EgSegmentedControl` que escolhe entre resumo e transcrição, e "Resumir"/"Apagar" continuam no rodapé. O alvo dos dois primeiros muda junto com a aba, e vê-los na mesma linha que a aba é o que torna isso óbvio sem uma palavra escrita — no rodapé, ao lado de "Apagar", eles pareceriam agir sobre a reunião inteira. Consequência de largura: o seletor mais dois botões de texto não cabem sempre nos 480px da região, então a linha é um **`Wrap` com `spaceBetween`**, não um `Row` — onde há largura é uma linha só com as ações à direita, onde não há elas descem em vez de estourar o layout. É a mesma saída que o próprio `EgSegmentedControl` usa na fila dele. Botão de ícone caberia com folga e foi descartado pela regra de sempre: se o ícone precisa de tooltip, o ícone falhou.
- **Confirmação de ação instantânea é texto curto ao lado do botão, com prazo.** "Resumo copiado" em `footnote`, três segundos, e some também ao trocar de aba ou de item — a confirmação é da coisa que estava aberta. Nunca um toast (peso demais para uma ação que não pode dar errado, e não há canto livre sobre um documento) e nunca permanente: o cartão do Leaf pode manter o "copiado" porque o painel dele fecha em seguida; uma região que fica aberta meia hora estaria afirmando algo que já não está acontecendo. Se a confirmação natural for longa — o nome de um arquivo —, ela não cabe: diga o que aconteceu e deixe o nome para quem o mostra melhor (a janela do Finder que abriu com ele selecionado).
- **Lista de conteúdo se agrupa por dia, e o dia mostra o próprio total.** O dia é do grupo (`EgDayHeader` com "Hoje"/"Ontem"/"23 jul", via `DayGroups`), e a linha fica com a **hora**. Repetir a data em toda linha foi o que fez o histórico do Focus escrever "Hoje ·" cinco vezes na mesma tela. O somado do dia vai no **cabeçalho**, à direita, alinhado com a coluna de duração que ele soma: quem corre o olho por dias está comparando dias, e a comparação tem de acontecer na mesma altura em que o dia é nomeado — no pé do grupo, o número de segunda ficaria a doze linhas do de terça. É o mesmo cabeçalho nas duas listas que agrupam por dia (sessões do Focus, reuniões do Echo).
- **Linha de lista tem altura fixa e colunas fixas** — fixa *naquela lista*, não no aplicativo inteiro. Uma linha que cresce quando tem metadado e encolhe quando não tem deixa a lista serrilhada; um número que muda de posição a cada linha não dá para comparar correndo o olho. Nome no meio, número à direita, e o acessório em texto menor junto do nome.
- **Duas alturas de linha, e o que decide é ter ou não um estado que muda sozinho.** A sessão do Focus é uma linha de 34: ela acabou, e o que ela é já está escrito. A reunião do Echo é uma linha de 52, em duas linhas de texto, porque ela tem um estado posterior à gravação — transcrita e sem resumo, sendo resumida agora, resumo pronto —, e é esse estado que decide se vale abrir. Ele vivia atrás do nome, como um "resumida" cinza que o corte por ellipsis comia primeiro em qualquer título comprido. Na segunda linha ele fica ao lado da **hora**, que desceu junto: hora e estado são o que distingue duas reuniões do mesmo dia. Em curso é `ember`, como todo "processando" do app — nunca accent, que ali diria "ligado".
- **O clique do mouse numa lista abre o detalhe; ele nunca executa a ação final.** No Pin, clicar numa linha seleciona e abre o preview — de onde se copia, apelida, fixa ou exclui vendo o conteúdo inteiro. O duplo clique que copiava e fechava caiu junto: o painel muda de largura ao abrir o preview, e o segundo toque cairia numa linha que já saiu de baixo do cursor — ou no botão de excluir que acabou de aparecer ali. Quem quer o caminho curto usa o teclado (Enter, `⌘1`–`⌘5`), que é onde ele sempre esteve.
- **Ação destrutiva não encosta na lista.** "Limpar histórico" colado na última sessão, com um divisor por cima, lia-se como mais uma linha — com um botão vermelho do lado. Vai separada por um respiro, sem divisor.
- **Gráfico só quando ele responde o que o número não responde.** A faixa de sete barras do Focus (`FocusWeekStrip`) existe porque "1h 35min hoje" não diz se a semana está indo; sem eixo, sem grade, sem legenda de valor, e com accent em um dia só — hoje. Um gráfico que só ilustra o número que já está escrito ao lado é decoração, e cai na regra de `anti-patterns.md`.
- **Rótulo de botão descreve o que ele faz, nunca o que o usuário conseguiu.** No fim de uma sessão do Focus o botão é "Encerrar" (fecha o ciclo) e não "Concluir", que se lia como "concluí a tarefa" — uma afirmação sobre o trabalho que o app não tem como saber. Se o produto não registra o desfecho, a microcopy não pode insinuar que registra.
- **A tela só afirma o que o aplicativo sabe.** O Echo grava duas faixas — o seu microfone e o áudio do Mac —, e isso é certeza; as vozes do outro lado ("Pessoa 1", "Pessoa 2") são separadas por um modelo de timbre, e isso é palpite. Então a lista e o cabeçalho da leitura dizem "sua voz e a reunião" ou "só a reunião", nunca "3 vozes": um número ali seria bonito, seria consistente com o que outros apps mostram, e afirmaria o palpite como fato na primeira reunião em que duas pessoas soam parecido. O palpite aparece só na transcrição, ao lado do que cada voz disse — onde dá para conferir. Antes de desenhar um dado, pergunte de onde ele sai, e se ele é certeza ou palpite.
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

**A assinatura da seleção é o véu de accent sobre a superfície elevada**, mais a linha de luz de 1px no topo (`EgSurfaceStyle.innerHairline`) e o texto em `bodyStrong` — **elevação, peso e cor, nesta ordem**, com o verde em opacidade baixa (16%, ou 24% sobre o vidro). Vale para **tudo o que responde "qual é a da vez?"**: linha de lista do Pin, item de sidebar, aba de tela, histórico do Focus, reunião do Echo, cartão do Leaf, linha do Nest e a pílula do segmented control. A pílula fica de fora de uma coisa só — a linha de luz no topo: em 60px de largura ela viraria a metade de cima do componente. Ali o véu e o peso do rótulo respondem sozinhos.

A linha é desenhada como `foregroundDecoration` porque uma borda com um lado diferente dos outros não aceita raio de canto, e ela precisa acompanhar o arredondamento da peça. `hairlineAlways: true` acende sem depender de seleção — é o caso da faixa de estado, que **nasce** elevada.

Era accent a 14% mais uma aresta verde de 3px à esquerda. Trocar a cor pela luz é o que devolveu significado ao verde: ele voltou a dizer só "ligado" e "ação primária".

Colunas disponíveis: `row` (linha de lista, item de sidebar), `ghost` (botão de ícone — sem superfície em repouso, então é o conteúdo que reage), `card` (superfície própria em repouso), `segment` (pílula do segmented control), `primary`, `secondary` e `destructive` (botões).

A tabela inteira, desenhada, mora no golden `test/goldens/design_state_matrix.png` — a folha de estados do design system, com as sete colunas em seis estados e os componentes reais abaixo, hover e pressed inclusive. Regenerar com `flutter test --run-skipped -t preview --update-goldens`.

## A marca

O Evergreen tem **um** desenho de marca: o canivete de `lib/shared/widgets/eg_brand_mark.dart`, com a lâmina em qualquer ponto entre recolhida e travada. Ele aparece em quatro lugares, e nos quatro é o mesmo código:

- a abertura do Hub (`EgBrandMark`, com a lâmina girando);
- o ícone do aplicativo (`app_icon_*.png`, laje escura + marca em dois verdes);
- o ícone da barra de menus (`tray_icon.png`, preto chapado sobre alfa — imagem de *template*, que o macOS inverte sozinho);
- o glifo de 16px da barra lateral (`EgIconData.evergreen`, numa cor só).

Os `.png` são **gerados**, não desenhados: `flutter test --run-skipped -t assets test/tools/brand_assets_test.dart`. Não existe `.svg` paralelo, e essa é a regra, não um detalhe de implementação — o pinheiro tinha um, e foi assim que ele continuou no ícone do aplicativo e na barra de menus meses depois de a marca já ser outra. Marca nova, ou ajuste na lâmina: mexa no Dart e reexporte.

Nos tamanhos pequenos, lâmina e cabo vão na **mesma cor**: o que separa os dois ali é a silhueta e o furo do rebite, não o contraste entre os dois verdes.

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
- Atalho de teclado para focar a busca deve estar sempre disponível e, quando fizer sentido, exibido discretamente dentro do próprio campo (ex: um badge pequeno de atalho alinhado à direita, tipo "⌘K"), seguindo o padrão de `ux.md`. No `EgSearchField` é o `shortcut:`, e ele só aparece com o campo **vazio e sem foco** — com o cursor dentro o atalho já foi usado, e com texto o espaço é do que se digitou.
- Fora do painel flutuante (`bare: false`) o campo é o poço do `EgTextField` (`canvasDeep`), com a aresta neutra em repouso e o verde **só com o foco**. Era verde o tempo todo, o que dizia "estou com o teclado" sem estar.
- **Busca que atravessa itens mora acima deles, nunca dentro de um.** A do Echo procura em todas as reuniões de uma vez, no topo do cartão "Reuniões": quase nunca se sabe *em qual* reunião algo foi dito. Os resultados substituem a lista enquanto há texto — a reunião numa linha, os trechos dela embaixo, com quem falou e o minuto numa coluna fixa —, e o que não coube é contado ("mais 4 trechos, grifados na leitura"), nunca escondido.
- **Dois grifos, e cada um tem o seu lugar.** Em lista o grifo é a cor da letra (accent), como no Pin: ele aparece em muitas linhas, e um fundo em cada uma viraria um mosaico. Dentro de um texto que se lê, é o fundo `findMark`: na transcrição a cor da letra já é do áudio, e as duas marcas precisam caber na mesma palavra.
- Abrir um resultado leva **ao trecho**, não à reunião: a face certa, a fala à vista, o áudio parado onde a palavra soa (sem tocar — tocar sozinho seria áudio começando sem ninguém pedir). O pedido é de um gesto só: escolher a reunião pela lista depois esquece o trecho da busca.

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
- **A bolinha do modelo local mora no rodapé da barra lateral**, à direita de "tudo local · nada sai daqui": verde (`accent`) com um modelo na memória do LM Studio, `textQuaternary` sem nenhum, e ausente com o Apple Intelligence. O nome do modelo vai no tooltip (o mesmo balão do `EgIconButton`) e no rótulo de leitor de tela. Na barra de menus ela não seria verde — o macOS não colore texto ali —, e na linha "Modelo local" só seria vista por quem fosse até a tela do aplicativo.

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

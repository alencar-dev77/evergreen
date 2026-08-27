# UX: Interação e Fluxo

## Princípio central

O Evergreen é desenhado **primeiro para teclado, depois para mouse/trackpad**. Toda ação frequente precisa ter um caminho de teclado; o mouse existe para descoberta inicial, seleção livre e casos onde apontar é genuinamente mais rápido que lembrar um atalho (ex: clicar em um item específico numa lista longa e não ordenada).

Isso é uma inversão consciente do padrão típico de design de produto (que costuma desenhar para mouse/toque primeiro e "adicionar atalhos depois"). No Evergreen, o atalho vem primeiro na concepção da tela — depois se desenha o alvo de clique correspondente.

## Atalhos de teclado

- Todo comando destrutivo, de navegação principal ou de ação primária tem um atalho global ou contextual — e esse atalho é **descoberto pela própria interface**, não escondido: exibido discretamente ao lado do item de menu correspondente, dentro de tooltips (quando existirem) e, quando fizer sentido, diretamente no componente (ex: badge de atalho dentro do campo de busca).
- Convenções do macOS são respeitadas sempre: `Cmd` para ações primárias (não `Ctrl`), `Cmd+,` para preferências, `Cmd+W` para fechar janela/aba, `Cmd+N` para novo item, `Esc` para cancelar/fechar overlay, setas para navegar listas, `Enter`/`Return` para confirmar/abrir o item focado.
- Atalhos de um único caractere sem modificador (ex: apenas "j"/"k" para navegar, como em apps inspirados em vim) são aceitáveis **apenas quando o foco estiver claramente em um contexto de navegação de lista** e nunca quando o foco estiver em um campo de texto — nesse caso o caractere deve ser digitado normalmente como texto.
- A paleta de comandos (command palette, se o Evergreen tiver uma, no espírito Raycast/Linear) é o hub central de descobribilidade de atalhos: cada ação nela listada mostra seu atalho correspondente ao lado, ensinando o atalho organicamente pelo uso repetido.

### Mapa de atalhos implementado

| Atalho | Contexto | Ação |
|---|---|---|
| `⌘⇧C` | global | abre o overlay do Pin |
| `↑` `↓` | overlay | move a seleção (funciona com o foco no campo de busca) |
| `Enter` | overlay | copia o item selecionado e fecha |
| `Tab` | overlay | abre **e fecha** o preview — é o único caminho de volta dele |
| clique | overlay | seleciona a linha **e abre o preview** — o mouse não copia: quem copia é o botão "Copiar" de lá dentro |
| `←` `→` | overlay | anda pela fila de filtros por tipo (Tudo · Textos · Links · E-mails · Telefones · CPF · Comandos) — o outro eixo das setas, com ↑↓ na lista |
| `⌘←` `⌘→` | overlay | o mesmo, para quem já tinha a memória muscular de antes |
| `Esc` | overlay | com filtro ativo, desfaz o filtro; em qualquer outro caso fecha o overlay — o preview **não** consome o Esc |
| `⌘P` | overlay | fixa/desafixa o selecionado |
| `⌥↑` `⌥↓` | overlay | reordena o fixado selecionado dentro do grupo; nas pontas e fora dos fixados, não faz nada |
| `⌘⌫` | overlay | apaga o selecionado, mantendo o overlay aberto e a seleção no vizinho |
| `⌘R` | overlay | abre o preview e leva o cursor ao apelido do item selecionado |
| `Enter` | apelido em edição | guarda o apelido e devolve o teclado à lista |
| `Esc` | apelido em edição | descarta o que foi digitado e devolve o teclado à lista |
| `⌘,` | overlay | abre as preferências (Hub) e fecha o overlay |
| `⌘1`–`⌘5` | overlay | copia direto o N-ésimo **recente** |
| `⌥1`–`⌥5` | overlay | copia direto o N-ésimo **fixado** |
| `⌘⇧F` | global | abre o painel do Focus |
| `⌘⇧D` | global | abre o painel do Leaf |
| `⌘⇧X` | global | abre o painel do Awake (sem mnemônico: `⌘⇧A` é "Aplicativos" no Finder e `⌘⇧D` foi para o Leaf — não colidir vale mais que lembrar o nome) |
| `⌘+` | Leaf | abre um cartão em branco na primeira vaga livre |
| `Enter` | Leaf | edita o cartão selecionado — ou anota, quando a vaga selecionada é a livre |
| `←` `→` `↑` `↓` | Leaf | move a seleção pela grade, parando nas bordas |
| `⌘1`–`⌘9` | Leaf | copia a anotação daquela vaga e fecha o painel |
| `⌘⌫` | Leaf | tira o cartão selecionado; os seguintes sobem uma vaga e a parede encolhe |
| `⌘Z` | Leaf | devolve o último cartão apagado à vaga em que ele estava — enquanto o painel estiver aberto e houver vaga |
| `Enter` | cartão em edição | guarda a anotação e devolve o teclado à parede |
| `⇧⏎` | cartão em edição | quebra a linha dentro do cartão |
| `Esc` | cartão em edição | descarta o que foi digitado (um cartão novo não chega a existir) |
| `Enter` | Awake | liga a trava (e fecha o painel) ou desliga (e fica) |
| `←` `→` | Awake | troca a duração, com o seletor focado |
| `Esc` | Awake | fecha o painel; a trava continua como está |
| `⌘⇧,` | global | abre as preferências (Hub) |
| `Esc` | Hub | sai do campo de texto que estiver em edição; sem campo, fecha a região de leitura; sem região, esconde a janela |
| `⌘⇧E` | global | abre o painel do Echo (`E` de Echo: `⌘⇧T` e `⌘⇧R` roubariam "reabrir aba" e "recarregar" de todo navegador, e reunião acontece dentro do navegador) |
| `Enter` | Echo | a ação daquele estado: gravar, parar e transcrever, abrir no Hub |
| `⌘.` | Echo | descarta a gravação em curso e joga o áudio fora |
| `Esc` | Echo | fecha o painel; a gravação **continua** |
| `Enter` | Focus | executa a ação principal daquele estado (iniciar, iniciar a pausa, voltar ao foco); durante a sessão, anota a observação digitada |
| `space` | Focus | pausa/retoma — desligado enquanto o campo de anotação tem o foco (espaço volta a ser espaço) |
| `⌘.` | Focus | encerra a fase em andamento |
| `⌘+` | Focus | +5 min na sessão — só na reta final (≤5 min restantes) e uma única vez por sessão |
| `Esc` | Focus | fecha o painel; com o ciclo concluído, encerra o ciclo antes de sair |
| `⌘,` | Focus | abre as preferências (Hub) |

**A regra do Esc, que vale para qualquer janela ou painel do Evergreen:** ele
desfaz uma coisa por vez, do mais interno para o mais externo, e a última delas
é sempre sair. Entram na fila os estados que **escondem** informação (o filtro
por tipo do Pin) ou que **prendem o teclado** (um campo em edição, a região de
leitura do Hub). Não entra o que apenas mostra mais do que já estava à vista —
o preview do Pin é aberto e fechado pelo Tab. Foi o clique que decidiu isso:
desde que ele passou a abrir o preview, um Esc gasto em recolhê-lo virou o
caminho comum de quem só queria ir embora.

Quatro convenções que valem para qualquer painel novo:

- **O atalho global é um interruptor — para painel flutuante.** Apertá-lo com o
  mesmo painel à vista fecha; com outro painel à vista, troca o conteúdo sem
  piscar a janela. Janela comum (o Hub) não alterna: o atalho abre e traz para
  a frente, como qualquer app do macOS.
- **Atalho global nunca toma uma tecla que os outros apps usam.** `⌘,` é a
  convenção de preferências do sistema e por isso *não* pode ser global — ele
  viraria as preferências do Evergreen em cima das de todo mundo. O prefixo
  `⌘⇧` é o espaço da casa: `⌘⇧C`, `⌘⇧F`, `⌘⇧D`, `⌘⇧X`, `⌘⇧,`.
- **`Enter` é sempre o botão primário da tela**, e o rodapé anuncia isso com o
  verbo daquele estado ("iniciar", "pausa"). Se uma tela não tem proposta, ela
  não tem primário nem dica de Enter.
- **Fechar o painel não cancela o que está em curso.** Por isso a dica do Focus
  em sessão diz "fechar", e não "sair" — e a contagem passa para a barra de
  menus, que é onde o macOS espera encontrar um estado de segundo plano.
- **Clicar fora fecha o painel — menos quando o painel é o trabalho.** O padrão
  vale para os cinco: o painel é de passagem, e quem clica fora quer o que está
  fora. O Echo é a exceção, e só enquanto grava ou transcreve: ali o conteúdo
  nasce *durante* a reunião, e fechar ao clicar na reunião esconderia justamente
  o texto que se quer acompanhar. Esc e o botão continuam fechando — o que sai é
  o fechamento que ninguém pediu. Um painel novo só ganha essa exceção se tiver
  conteúdo que muda sozinho enquanto a pessoa olha para outra coisa.
- **Arrastar é para o painel que disputa espaço com outra janela.** O Echo é o
  único, e pelo mesmo motivo: ele fica na frente de uma reunião que estava ali
  primeiro. Pega-se pelo fundo do painel, sem alça visível — arrastar janela
  pelo corpo é idioma do macOS, e uma alça desenhada seria affordance
  redundante para um gesto que já se tenta por instinto. A posição não persiste:
  a próxima abertura recentraliza, que é o que mantém os cinco previsíveis.

Dois detalhes de convenção que valem para atalhos futuros:

- **Modificador obrigatório quando um campo de texto tem o foco — menos para as setas.** No overlay a busca está sempre focada, então excluir é `⌘⌫` e não `Delete` puro: um Backspace solto precisa continuar apagando o texto digitado. As setas são a exceção, e por serem os dois eixos do que está desenhado: ↑↓ andam pela lista, ←→ andam pela fila de tipos logo acima dela. O que elas custam é o cursor dentro da busca, que numa consulta de três letras se corrige apagando — e `⌥←`/`⌥→` continuam saltando por palavra. Ação que não é navegação continua exigindo modificadora.
- **Painel aberto é painel com teclado, sem exceção.** Um painel pode aparecer sem que nada peça o foco — trocar de painel com a janela já na tela não dispara `didBecomeKey`, e sem `onWindowFocus` não há `onShow`. Sem nó focado, nenhum `Shortcuts` é consultado: o painel fica na tela e cada tecla vira o bipe do macOS. A `EgOverlayShell` é quem garante isso agora, para os cinco painéis: se o foco escapa do painel visível, ela o devolve — ao nó do módulo, quando ele tem um, ou ao nó próprio dela. Quem desenha painel novo não precisa lembrar disso; quem tira um campo de texto da árvore, também não.
- **Enter confirma, `⇧⏎` quebra a linha — e o Enter é interceptado acima do campo.** No Leaf o `Shortcuts` do painel consome o Enter antes de ele virar texto; com o Shift junto a combinação não casa com nada no mapa, desce até o campo e quebra a linha. Vale para qualquer campo de várias linhas que precise confirmar por teclado: registrar o Enter no mapa do painel resolve as duas teclas de uma vez, enquanto o `onSubmitted`/`textInputAction` do campo só resolveria uma.
- **Foco de campo que aparece por mudança de estado se pede à mão.** `autofocus` só vale quando **nada** no escopo tem o foco, e um painel operado por teclado sempre tem (é o nó que recebe os atalhos). Um cartão que abre para escrever precisa de `requestFocus` no quadro seguinte — sem isso ele nasce esperando um clique, e a primeira letra digitada se perde.
- **Campo que a pessoa escreve e confirma esvazia o mapa de atalhos enquanto tem o foco.** No apelido do Pin sobram duas teclas — Enter guarda, Esc descarta — e o rodapé passa a falar só delas. Setas, `⌘⌫` e os números pertencem ao texto que está sendo digitado; um atalho que os roubasse tornaria o campo inutilizável. É a mesma regra que já desligava o `space` do Focus com o cursor na anotação, agora valendo para o mapa inteiro.
- **Editar não é confirmar: sair do campo guarda.** O apelido é gravado quando o campo perde o foco, por qualquer caminho (Enter, clicar em outra linha, fechar o painel) — só o Esc desfaz. Painel que some do olho não pode levar junto o que a pessoa acabou de escrever.
- **Ação destrutiva sem pergunta precisa de desfazer.** No Leaf, esvaziar o
  campo apaga a anotação: é a forma mais direta de dizer "isso aqui já era", e
  também a mais fácil de fazer sem querer (⌘A, Delete, um clique fora). A saída
  não é um diálogo de confirmação — ele cobraria uma pergunta em todas as vezes
  em que o gesto foi de propósito, que são a maioria —, e sim o `⌘Z` clássico do
  macOS: o cartão fica ao alcance dele até o painel fechar. Confirmação modal
  continua sendo para o que não tem volta (restaurar um backup, limpar o
  histórico); desfazer é para o que tem.
- **Dica de rodapé que aparece por um estado passageiro é clicável.** Nenhuma
  ação do Evergreen é só de teclado, e desenhar um botão para uma tecla que
  existe entre apagar um cartão e fechar o painel encheria a tela de affordance
  que some. A dica já está no lugar certo, dizendo a coisa certa, na hora certa
  — o `onTap` do `EgHint` a torna o alvo de mouse daquela tecla, com o rótulo
  clareando sob o ponteiro. Vale só para o que **não tem** outro alvo na tela: a
  dica de `enter` continua sendo legenda, porque o cartão já está ali para ser
  clicado.
- **Descartar não pode morar no Esc.** No Echo o Esc fecha o painel e a reunião
  segue gravando — é o que a pessoa quer ao voltar para a chamada. Jogar fora
  meia hora de reunião precisa de modificadora (`⌘.`), como qualquer ação
  destrutiva. Vale para todo painel que tenha algo em curso que custe caro
  perder.
- **O menu da barra ensina os atalhos globais.** Cada item mostra o seu ao lado
  do rótulo — é o único lugar permanente do app na tela, e quem clica ali com o
  mouse é justamente quem ainda não decorou a tecla.
- **Nem todo atalho cabe na barra de dicas.** A barra mostra o subconjunto relevante ao estado atual (`⌘⌫ excluir` só aparece com o preview aberto, onde há largura para ele e onde a exclusão é a ação em foco). Descobribilidade não é "mostrar tudo": é mostrar a coisa certa no momento em que a dúvida existe.
- **O modificador nomeia a camada.** No overlay, `⌥` é sempre "os fixados": ele alcança os fixados no `⌥1..⌥5` e os reordena no `⌥↑`/`⌥↓`. Um atalho novo que atue sobre os fixados nasce em `⌥`; um que atue sobre a lista inteira, em `⌘`.
- **Atalho que só vale numa parte da lista se anuncia só ali.** `⌥↑↓ mover` entra no rodapé quando a seleção está num fixado que tem com quem trocar de lugar, e sai quando ela desce para os recentes — a fronteira entre os grupos é exatamente onde a capacidade muda, e anunciá-lo o tempo todo prometeria algo que a maior parte da lista não cumpre. A largura sai da dica mais evidente do rodapé (`enter`, que já era exibido sem rótulo), não do `tab ver`.

### Decisão do produto: atalho global não é reconfigurável na v0.1

A linha "Abrir Pin" nas preferências é **exibição-somente**: mostra `⌘⇧C` em key-caps e não aceita rebinding. Rebinding exige captura de tecla, validação de conflito com o sistema e persistência do novo atalho — trabalho que fica para uma versão futura.

Enquanto isso valer, a linha continua na tela em vez de ser omitida: ela ensina o atalho, que é a função mais importante dela. Não a transforme em algo que *pareça* editável (campo, botão "alterar") sem implementar a captura de verdade.

## Navegação por teclado dentro de listas e menus

- Setas para cima/baixo movem a seleção item a item; `Enter` confirma/abre o item selecionado; `Esc` fecha o contexto (popup, busca, modal) sem executar ação.
- Ao digitar em um campo de busca acoplado a uma lista de resultados, as setas devem continuar navegando a lista mesmo com o foco no campo de texto (padrão Spotlight/Raycast) — a pessoa não deve precisar clicar na lista para poder navegá-la.
- `Tab`/`Shift+Tab` seguem a ordem lógica de leitura da tela (esquerda para direita, cima para baixo) para navegação geral entre campos/controles fora do contexto de uma lista específica.
- Seleção múltipla via `Shift+clique` (intervalo) e `Cmd+clique` (itens individuais) sempre que a lista suportar ações em lote.

## Mouse e trackpad

- Embora o teclado seja prioridade de concepção, toda ação de teclado precisa ter um equivalente de mouse igualmente descobrível — nunca um recurso "só de atalho" sem nenhuma forma de acioná-lo visualmente (isso quebra descobribilidade para quem ainda não decorou os atalhos).
- Gestos de trackpad nativos do macOS (scroll com inércia, swipe para voltar quando aplicável, pinça se houver zoom) devem se comportar exatamente como o sistema espera — nunca reimplementar física de scroll customizada que "sente diferente" do resto do macOS.
- Hover é tratado como informação, não apenas como acionador de clique — hover revela ações secundárias contextuais (ver `components.md`, seção Listas) porque isso é como o mouse "pergunta" o que está disponível sem exigir clique.
- Menu de clique direito (contexto) deve estar disponível em praticamente todo objeto de conteúdo relevante (item de lista, texto selecionado, elemento de configuração) como forma alternativa de descobrir ações menos frequentes.

## Densidade de informação e velocidade de uso

- Prefira mostrar mais informação relevante por tela a exigir mais navegação/cliques para chegar à mesma informação — isso é uma das razões centrais para a densidade alta descrita em `spacing.md`.
- Toda tela deve ser pensada em termos de "quantos passos entre abrir o app e completar a tarefa mais comum daquela tela" — se esse número está alto, o problema é de arquitetura de informação antes de ser um problema visual.
- Estado é preservado entre usos sempre que fizer sentido (última aba ativa, última posição de scroll, filtros aplicados) — a pessoa não deve reconfigurar o contexto toda vez que reabre o app, já que o Evergreen é reaberto dezenas de vezes ao dia.

## Busca

- A busca é tratada como um mecanismo de navegação primário, não como um recurso acessório — sempre que a quantidade de conteúdo justificar, um atalho global (tipicamente `Cmd+K` ou equivalente) deve abrir busca/paleta de comando de qualquer lugar do app.
- Resultados de busca são ranqueados por relevância real (correspondência de texto, frequência/recência de uso), não apenas ordem alfabética ou de criação.
- Buscar deve funcionar mesmo com termos parciais e fora de ordem (fuzzy matching) sempre que tecnicamente viável — a expectativa herdada do Spotlight/Raycast é que a pessoa não precisa digitar o termo exato desde o início.

## Menus e organização de comandos

- Menus (de barra de menu do sistema, contextuais ou dropdown) organizam comandos por frequência de uso e por agrupamento lógico, com os mais comuns no topo — nunca em ordem puramente alfabética se isso esconder o comando mais usado no meio de uma lista longa.
- Comandos destrutivos ficam sempre visualmente separados (divisor) e no fim do menu, nunca misturados com comandos neutros no meio da lista.

## Dialogs e interrupção de fluxo

- Um dialog modal só deve interromper o fluxo quando a decisão for genuinamente bloqueante (confirmação destrutiva, erro que impede continuar, formulário curto que precisa de foco total) — ver `components.md` para a forma visual.
- Sempre que possível, prefira **feedback inline** (mensagem de erro ao lado do campo, badge de status atualizado, notificação discreta) a um modal, porque modais custam mais atenção e mais cliques para dispensar do que a maioria das situações realmente exige.

## Feedback visual

- Toda ação do usuário produz uma resposta visual perceptível dentro de ~100ms, mesmo que a operação real (rede, disco) demore mais — um estado otimista (mostrar o resultado esperado imediatamente, com possibilidade de reverter caso a operação subjacente falhe) é preferível a fazer a pessoa esperar visualmente por uma confirmação de rede antes de ver qualquer mudança.
- Erros são comunicados no contexto exato de onde a ação falhou (ao lado do campo, dentro do item de lista, em vez de um alerta genérico no topo da tela desconectado da causa), sempre que tecnicamente possível.
- Confirmações de sucesso para ações rotineiras (salvar, marcar como concluído) são discretas e rápidas (mudança de estado visual do próprio item, ou uma notificação breve) — nunca uma celebração visual grande (confete, animação elaborada) para uma ação de trabalho cotidiano; isso quebraria o tom sóbrio e funcional do produto.

## Onboarding e primeira execução

- Onboarding, quando necessário, é mínimo — idealmente resolvido dentro do próprio fluxo real de uso (ex: um empty state com uma única sugestão de ação) em vez de um carrossel de telas explicativas antes de deixar a pessoa usar o app.
- Se um passo de configuração inicial for genuinamente necessário (ex: conceder uma permissão do macOS), ele deve ser pontual, específico e sair do caminho assim que resolvido — nunca uma sequência longa de telas "de boas-vindas" com ilustrações.

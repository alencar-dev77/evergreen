# O Nest — as decisões da prateleira de arquivos

> Preferências do aplicativo → Nest.

Este documento guarda o que foi decidido e o que foi descartado no módulo que
junta arquivos de várias pastas e manda todos para uma só. A parte mais cara
dele é sobre uma porta de entrada que **existiu e saiu**: o recorte da tela.

## O recorte da tela: tentado, e removido

A prateleira precisa ser invocada com o **botão do mouse já pressionado**, no
meio de um arraste. É o gesto inteiro do módulo: a pessoa pega um arquivo no
Finder e, a caminho de lugar nenhum, decide juntá-lo a outros. Um atalho de
teclado nesse instante é desconfortável, e um alvo visível permanente na tela é
ruído numa suíte cujo primeiro princípio é não aparecer.

O recorte parecia a resposta: um alvo que já está lá, no caminho de quem arrasta
para cima, e que **não custa pixel** — o espaço está ocupado pelo hardware.

Custou uma exceção à regra que sustenta a arquitetura de janelas desde a v0.1
(**só a janela 0 pode ser transparente, sem chrome e sempre no topo**, ver
[focus-janela-compartilhada.md](focus-janela-compartilhada.md)) e **nunca
funcionou uma única vez**. Três rodadas de conserto, três hipóteses plausíveis,
e o arquivo continuou voando de volta para a origem:

1. **O caminho do arraste.** A janela usava uma `NSView` registrada como
   destino; trocamos pelo delegate da janela, que é o caminho provado no painel.
2. **A janela não pintava um pixel.** Uma janela não-opaca cuja superfície nunca
   foi desenhada pode ser tratada como buraco pelo servidor de janelas — um
   `fill` a 1% de alfa descartava a hipótese.
3. **O alvo era invisível e minúsculo** (uns 200x32 pt), então errar e acertar
   eram indistinguíveis. Passou a se anunciar durante o arraste: a janela crescia
   28 pt para baixo — porque **o recorte é um furo físico no painel e não tem
   pixel para acender** — e desenhava uma faixa.

Nem a faixa apareceu. Isso descarta a entrega do evento como causa e aponta para
a janela em si: nível, geometria, ou alguma coisa que o macOS 26 faz com aquela
faixa da tela e que não está documentada. Depurar mais fundo exigiria tempo
desproporcional ao que a porta entrega, **porque ela ficou redundante**: o
chacoalhar faz a mesma coisa, em qualquer Mac, sem janela extra e sem exceção
nenhuma à regra da casa.

Então o recorte saiu inteiro — janela, preferência, canal e detecção de
hardware. A regra da v0.1 voltou a ser absoluta: **só a janela 0**.

### O que vale guardar, se um dia isto voltar

- **Não existe API de recorte.** De macOS 12 em diante o que existe é
  `screen.safeAreaInsets.top > 0` para saber se há um, e
  `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` para achar onde ele começa e
  termina — o que sobra entre as duas é o recorte. Nada de tabela de modelos de
  Mac.
- **As duas propriedades auxiliares são opcionais**, e tratar nulo como zero faz
  a largura virar a tela inteira: um alvo de arraste invisível cobrindo a barra
  de menus, com os cliques dela bloqueados junto. Qualquer volta precisa da rede
  contra isso.
- **Uma janela sempre no topo não é o custo que a regra da casa teme.** O que a
  regra protege é engine e superfície viva; uma `NSWindow` sem engine é barata.
  O que derrubou esta não foi o custo — foi não funcionar.

## Quem recebe o arraste: duas tentativas erradas antes da certa

As duas erradas falhavam do mesmo jeito — o arquivo caía, nada acontecia,
nenhum erro em lugar nenhum:

**1. Uma `NSView` transparente por cima do Flutter**, registrada para
`.fileURL`, com `hitTest` devolvendo `nil` para não roubar os cliques do painel.
O AppKit procura o destino de um arraste pelo **mesmo `hitTest` do mouse**: view
invisível ao clique é invisível ao arraste. E o caminho oposto — devolver a view
no `hitTest` — engoliria todos os cliques do painel. Não há posição na
hierarquia que resolva os dois.

**2. A própria janela**, com os métodos do `NSDraggingDestination` escritos
nela. `NSWindow` não implementa esse protocolo: o `NSWindow.h` do SDK declara só
o `registerForDraggedTypes:`, e quem recebe as mensagens é o **delegate** da
janela. Compila, registra e não chega nada.

**A certa é o delegate.** A janela 0 já tem o delegate do `window_manager`, que
é quem avisa o Flutter sobre foco e fechamento; o `NestWindowDropDelegate` se
põe na frente dele e devolve todo o resto pelo encaminhamento do ObjC
(`responds(to:)` **e** `forwardingTarget(for:)` — o AppKit pergunta antes de
enviar, então as duas metades são necessárias).

A janela do recorte chegou a repetir a tentativa 1 por analogia, corrigindo o
que se sabia estar errado nela, e também não recebeu nada. A lição não é sobre
AppKit: **o caminho que funciona é o que já foi visto funcionando** — havia um
caminho provado a três metros de distância, e o outro foi escrito por
raciocínio.

O delegate é reinstalado a cada abertura do painel, não só na montagem: se o
`window_manager` reescrever o delegate da janela algum dia, o arraste voltaria a
não funcionar em silêncio — e este é o tipo de falha que só aparece com um
arquivo na mão.

## A saída: as duas convivem

A prateleira entrega os arquivos por dois caminhos, e nenhum substitui o outro:

- **As pastas favoritas** (`⌘1..⌘9`), para o destino que se repete toda semana —
  operável sem tirar a mão do teclado, e com desfazer, porque é o Evergreen que
  copia ou move.
- **Arrastar a lista para fora**, para o destino de hoje: uma pasta qualquer no
  Finder, o campo de anexo de um e-mail, a área de trabalho. Puxar qualquer
  linha leva a prateleira inteira, como o `⌘1`.

O arraste para fora é uma `NSDraggingSession` começada pela view do Flutter
(`NestChannel.beginDrag`), com um `file URL` por item. Três consequências que
não são detalhe de implementação:

- **Quem copia ou move é o destino, não nós.** O Evergreen entrega a lista e a
  operação declarada; o Finder faz o resto.
- **Por isso não há desfazer neste caminho** — o Evergreen não fica sabendo para
  onde os arquivos foram. Quem desfaz é o `⌘Z` do próprio Finder. O Track
  continua contando, porque a linha dele nunca teve caminho nenhum.
- **A operação é a do painel**, não a do sistema: `NestDragSource` declara `.copy`
  ou `.move` conforme o que está escrito em cima da lista (a preferência,
  invertida pelo `⌥`). Declarar `[.copy, .move]` devolveria a decisão à
  modificadora do sistema, e aí o rótulo "COPIAR PARA" valeria para metade dos
  caminhos do módulo.

### Soltar em cima da própria prateleira é desistir

Fora do painel, o relógio do cursor já faz a janela sumir para o mouse, e é isso
que deixa o arquivo chegar ao Finder. **Sobre** o painel ela continua
interceptando — e o `NestDrop` recusa o arraste quando a origem dele é o próprio
`NestDragSource`. O cursor mostra que ali não dá, os arquivos voltam para a
prateleira e nada acontece.

A recusa faz duas coisas ao mesmo tempo, e a segunda é a que não é óbvia: sem
ela, largar o arquivo em cima do painel o largaria na **janela que estava
atrás** — a prateleira fica por cima de tudo, e um destino invisível é pior que
nenhum.

### A prateleira se move

`draggable: true` na casca: arrastar pelo **fundo** do painel move a janela,
porque às vezes o arquivo que se quer ver está justamente atrás dela. Puxar **a
lista** é outra coisa — leva os arquivos embora —, e ganha da primeira por estar
mais fundo na árvore de widgets: na arena de gestos do Flutter, o reconhecedor
mais profundo é o primeiro a entrar e vence a varredura.

### Escolher estreita, não seleciona

A prateleira recém-cheia vem com **nada** escolhido, e sem escolha sai a
prateleira inteira — a promessa do módulo, e o que a barra de dicas diz
("copiar tudo"). Clicar escolhe uma linha, `⌘` acrescenta uma a uma, `⇧` estende
do cursor até ali; a partir daí sai só o escolhido, e a dica passa a dizer
quantos ("copiar 2"). Vale para os dois caminhos de saída.

O contrário — nascer com tudo escolhido, para "tudo" ser um estado visível — foi
desenhado e descartado ao ver a tela: com todas as linhas em accent, o realce de
escolha para de significar alguma coisa, porque não sobra nada para contrastar
com ele. A lista vira um bloco verde só.

## E o bug que estava por baixo dos outros dois

Nada disso aparecia, porque havia um terceiro problema escondendo os dois
primeiros: **o canal do Flutter era guardado numa referência fraca e morria
sozinho.**

Um `FlutterMethodChannel` não é retido por ninguém. O `binaryMessenger` guarda o
*bloco* que atende as chamadas vindas do Dart, não o objeto. Com um `weak var`,
o canal era desalocado assim que o `register` terminava — e o efeito é
perfeitamente assimétrico: tudo o que vem **do** Dart continuava funcionando
(escolher pasta, ligar o chacoalhar, ligar o destino de arraste), enquanto
tudo o que ia **para** o Dart caía no vazio. O arquivo era aceito pelo AppKit, o
`invokeMethod` era chamado num `nil`, e a prateleira nunca via nada chegar.

O `PasteboardWatcherChannel` do Pin tem o mesmo `weak` e escapa por acidente: o
bloco dele menciona `channel`, então a closure o retém. Copiar aquele arranjo
sem copiar essa linha é o caminho direto para o mesmo dia perdido.

Por isso `report(paths:)` agora escreve no Console quando não há canal. Falha
silenciosa é o defeito deste módulo inteiro — três voltas de depuração, três
causas diferentes, e nenhuma delas com uma mensagem de erro.

## O clique tinha de atravessar a janela

A janela 0 é bem maior que qualquer painel (ela cabe o maior deles mais a
sombra), e o resto dela é transparente **mas ainda captura clique**. Nos outros
painéis isso é uma funcionalidade: é o "clicar fora fecha".

No Nest é fatal. A prateleira existe para ir buscar arquivos em outro
aplicativo, e com ela aberta não se conseguia nem clicar numa janela do Finder
atrás — o módulo inteiro ficava sem entrada.

O arranjo: enquanto o painel do Nest está na tela, o Dart informa ao lado nativo
o retângulo em que ele está desenhado (`setInteractiveRect`, medido a cada
quadro porque a altura acompanha o conteúdo), e o nativo liga
`ignoresMouseEvents` sempre que o cursor está fora dele. Fora do painel a janela
deixa de existir para o mouse; dentro, ela é a de sempre.

Quem segue o cursor é um `Timer` de 30 Hz, e não `addGlobalMonitorForEvents`:
durante uma sessão de arraste do sistema — que é exatamente quando isto precisa
funcionar — o monitor global não recebe os movimentos, e a janela ficaria
atravessável justamente na hora de soltar o arquivo nela. `NSEvent.mouseLocation`
é uma consulta, não um evento: responde certo durante o arraste e não custa
permissão nenhuma.

A consequência de produto: **o painel do Nest não fecha ao perder o foco, nunca**
— nem vazio, que é justamente o estado de quem vai buscar o primeiro arquivo.
Fecha pelo `esc`, pelo atalho global e pelo menu da barra.

## Chacoalhar acabou dando

O gesto entrou depois, e o que o destravou foi uma descoberta feita depurando
outra coisa — a mesma que fez o `followCursor` virar um relógio:

**Durante uma sessão de arraste do sistema, o AppKit não entrega os movimentos
do mouse a monitor nenhum.** Ou seja, o monitor global de `.leftMouseDragged`
que "exigiria uma permissão" não teria funcionado de qualquer forma: ele fica
mudo exatamente durante o gesto que deveria observar.

O que funciona é perguntar em vez de escutar. `NSEvent.mouseLocation` e
`NSEvent.pressedMouseButtons` são propriedades — respondem certo com o botão
apertado, no meio do arraste, e não custam permissão nenhuma. Um relógio de
60 Hz lendo as duas é a detecção inteira.

Sobra um evento a apanhar: o instante em que o botão **desce**, que é o que faz
o relógio começar. Esse acontece *antes* de a sessão de arraste existir, então
um monitor global comum o recebe — e monitor global de mouse, diferente do de
teclado, não pede Acessibilidade. Com o botão solto não há relógio rodando: em
repouso o custo é um bloco parado esperando um clique.

**O filtro é o que separa o gesto do ruído.** Chacoalhar o mouse à toa,
arrastar uma janela pela barra de título ou puxar um slider não podem abrir a
prateleira. Quem responde "tem arquivo na mão?" é a área de transferência de
arraste (`NSPasteboard(name: .drag)`), e são duas perguntas, nunca uma: o tipo
do conteúdo **e** o `changeCount` ter mudado depois de o botão descer. O tipo
sozinho sobra de um arraste que terminou faz cinco minutos.

**A conta do chacoalhar não tem eixo privilegiado.** Contar inversões de sinal
em `dx` é o caminho óbvio e erra o gesto real, que é tão diagonal quanto
horizontal. Em vez disso: entre duas amostras há um vetor; enquanto ele
concordar com a perna atual (produto escalar positivo) a perna cresce, e quando
discordar com a perna já longa o bastante (~45 pt), conta-se uma inversão. Três
inversões em 0,6 s são um chacoalhar.

**A prateleira nasce debaixo do cursor**, e é a única porta do aplicativo em que
o painel vai até a pessoa. Não é capricho: quem já está com o arquivo na mão não
deve ter de levá-lo até o centro da tela depois de chamar a prateleira — o
arquivo chega em cima dela e basta soltar. Como o painel é centralizado *dentro*
da janela 0, centrar a janela no cursor centra o painel nele; o resto é prender
a janela dentro da borda da tela (`OverlayWindow.positionForCursor`).

**E o risco assumido é o que o recorte evitava**: a janela aparece no meio de
uma sessão de arraste, em vez de já estar lá. O que salva é que o AppKit refaz a
busca pelo destino a cada movimento do mouse, e quem acabou de chacoalhar está
movendo o mouse. Este é o ponto frágil do gesto — se um dia ele falhar de vez em
quando, é aqui que se olha primeiro.

## O que ficou de fora

A versão bonita da porta que saiu é a do NotchNook: o recorte **cresce** e vira
a prateleira, com os cantos arredondados continuando o desenho do hardware. Isso
exige um engine Flutter residente a mais e a geometria animada de fora — uma
segunda superfície viva, que é exatamente o que a regra da casa proíbe. Se um
dia valer a pena, é uma conversa nova.

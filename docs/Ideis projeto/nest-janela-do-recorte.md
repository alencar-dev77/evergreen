# A janela do recorte — a segunda janela sempre no topo

> Preferências do aplicativo → Nest → "Receber arquivos pelo recorte da tela".

O Evergreen tem uma regra que sustenta a arquitetura de janelas desde a v0.1:
**só a janela 0 pode ser transparente, sem chrome e sempre no topo**. Ela existe
porque cada janela flutuante a mais é um engine Flutter a mais vivo o tempo
inteiro, e porque cinco painéis dividindo uma janela é o que faz o atalho global
abrir instantaneamente. Está registrada em
[focus-janela-compartilhada.md](focus-janela-compartilhada.md).

O Nest abre uma exceção a ela. Vale a pena explicar por que, e por que a exceção
é menor do que parece.

## O problema que só o recorte resolve

A prateleira precisa ser invocada com o **botão do mouse já pressionado**, no
meio de um arraste. É o gesto inteiro do módulo: a pessoa pega um arquivo no
Finder e, a caminho de lugar nenhum, decide juntá-lo a outros.

As alternativas:

- **Chacoalhar o mouse**, como o Dropover. Exige um monitor global de
  `.leftMouseDragged` — outra permissão a pedir, para um gesto que nem todo
  mundo descobre.
- **Um atalho de teclado durante o arraste.** Funciona (`RegisterEventHotKey`
  entrega a tecla no meio de uma sessão de arraste), mas apertar `⌘⇧S` com o
  polegar segurando o botão do trackpad é desconfortável o bastante para que
  ninguém faça duas vezes.
- **Um alvo permanente na tela.** Uma janelinha visível, sempre ali, é o que os
  apps de prateleira do macOS acabam fazendo — e é ruído permanente numa suíte
  cujo primeiro princípio é não aparecer.

O recorte é a quarta opção, e ele já é um alvo permanente que **não custa
pixel**: o espaço está ocupado pelo hardware, está no caminho de quem arrasta
para cima, e não há nada embaixo dele para receber cliques.

## O que a exceção realmente é

A `NestNotchWindow` é uma `NSPanel` sem borda, no nível acima da barra de menus,
com `collectionBehavior` de atravessar Spaces. Até aqui, uma segunda janela
sempre no topo.

Mas ela **não desenha nada e não tem engine Flutter**. Ela se registra para
`.fileURL` e só sabe uma coisa: recebeu arquivos, avisa o Dart. A regra que a
v0.1 escreveu era sobre superfície viva: engine, quadros desenhados, blur
recomposto. Disso, a janela do recorte não tem nada. O custo é uma `NSWindow`
vazia no servidor de janelas.

Por isso a regra continua valendo com uma vírgula: **só a janela 0 desenha.**

## Não existe API de recorte

O que existe, de macOS 12 em diante:

| O que se quer | O que se pergunta |
|---|---|
| Tem recorte? | `screen.safeAreaInsets.top > 0` |
| Onde ele começa | `screen.auxiliaryTopLeftArea?.width` |
| Onde ele termina | `screen.frame.width - esquerda - direita` |

Nada de tabela de modelos de Mac: a medida vem do sistema, e num Mac sem recorte
ela é zero. Abaixo do macOS 12 as três propriedades não existem, e o resultado é
o mesmo — a janela não nasce, e a linha **some** da tela de preferências em vez
de ficar apagada. Um controle desabilitado diz "isto existe, mas não para você";
aqui a resposta certa é a tela não mencionar uma escolha que aquela máquina não
tem. É a mesma decisão da bandeira `themes`, com a diferença de que esta é
resolvida em tempo de execução, por máquina, e não na hora de compilar.

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

**A certa é o delegate.** A janela do recorte não tem outro, e usa uma
`NestDropView` como `contentView` — ali nada mais precisa do mouse, então a view
pode responder ao `hitTest` normalmente. A janela 0 já tem o delegate do
`window_manager`, que é quem avisa o Flutter sobre foco e fechamento; o
`NestWindowDropDelegate` se põe na frente dele e devolve todo o resto pelo
encaminhamento do ObjC (`responds(to:)` **e** `forwardingTarget(for:)` — o
AppKit pergunta antes de enviar, então as duas metades são necessárias).

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
(escolher pasta, perguntar pelo recorte, ligar o destino de arraste), enquanto
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

## Dois detalhes que custaram para acertar

**`ignoresMouseEvents` do recorte fica `false`.** Ligá-lo mataria o drop junto
com o clique. É seguro deixá-lo desligado porque o retângulo do recorte não tem
nada clicável embaixo — o macOS não põe controle nenhum ali.

**A janela se reposiciona em `didChangeScreenParametersNotification`.** Fechar a
tampa, ligar um monitor externo ou trocar a tela principal muda qual `NSScreen`
tem recorte, e às vezes tira o recorte de cena. Sem esse aviso, a janela ficaria
ancorada numa geometria que não existe mais, recebendo arquivos num canto
qualquer da tela.

**O painel abre *depois* do drop, não durante.** Seria mais bonito abrir a
prateleira no `draggingEntered` e deixar o arquivo cair dentro dela. É frágil:
uma janela que aparece no meio de uma sessão de arraste nem sempre entra no hit
test do AppKit, e o gesto falharia de vez em quando — que é pior que nunca
funcionar. O recorte conclui o drop sozinho; o painel é a consequência.

## O que ficou de fora

A versão bonita disto é a do NotchNook: o recorte **cresce** e vira a
prateleira, com os cantos arredondados continuando o desenho do hardware. Isso
exige um terceiro engine Flutter residente e a geometria animada de fora, e aí
sim seria uma segunda superfície viva — a exceção que esta decisão evitou. Se um
dia valer a pena, é uma conversa nova, não uma extensão desta.

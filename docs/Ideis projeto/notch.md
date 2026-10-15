# O notch — a prateleira que sai dele e a ilha do que está rodando

> Status: **implementado**. Planejado na issue #98.

Os MacBooks com o recorte da câmera ganharam dois usos dele no Evergreen, e os
dois são de natureza diferente:

- **Porta**: o Nest. Levar um arquivo até o notch e parar em cima dele chama a
  prateleira, que sai do recorte.
- **Vitrine**: o Echo e o Focus. Enquanto uma reunião grava ou uma sessão de
  foco corre, o que está acontecendo aparece em volta do recorte — e, com o
  mouse em cima, a ilha abre com pausar e parar.

O princípio que vale para os dois é o mesmo: **o notch não mostra nada o tempo
todo.** Sem arquivo na mão e sem nada rodando, ele é o recorte de sempre.

Em Mac sem recorte — ou com a tampa fechada e só o monitor externo — **nada
disto existe**: sem "notch virtual", sem linha de preferência nas telas, sem
mudança de comportamento. O Evergreen fica exatamente como era.

## Onde está o recorte

Não há API de recorte. O que existe (macOS 12+) é `safeAreaInsets.top > 0` e as
duas faixas do topo, `auxiliaryTopLeftArea` e `auxiliaryTopRightArea`: o recorte
é o que sobra entre elas (`NotchGeometry`, em `NotchIsland.swift`).

Duas redes, porque o documento do Nest pediu: **as faixas são opcionais e nulo
não é zero** (uma faixa nula tratada como largura zero faria o recorte virar a
tela inteira, um alvo invisível sobre a barra de menus), e um recorte com mais
da metade da largura da tela é descartado como resposta errada. A conta usa só
as larguras das faixas, nunca a posição delas — a documentação não diz em que
espaço de coordenadas elas vêm.

## A porta: a prateleira sai do notch

O recorte já foi tentado uma vez como porta do Nest e saiu — ver
[nest-prateleira-de-arquivos.md](nest-prateleira-de-arquivos.md). Aquela versão
punha **uma janela própria** no recorte para receber o arraste, e ela nunca
recebeu nada. Esta não tenta receber o arraste no recorte:

1. **A detecção é por consulta**, a mesma do chacoalhar. O `NestDragMonitor`
   (antes `NestShakeMonitor`) já perguntava a 60 Hz onde está o cursor, se o
   botão está apertado e se há arquivo na mão; agora pergunta também "o cursor
   está no recorte?". Os dois gestos dividem o mesmo relógio, e o primeiro que
   reconhecer trava o outro naquele aperto de botão.
2. **Quem recebe o arquivo é a janela 0**, pelo caminho que já funciona (o
   delegate da janela). Ela só é posta em outro lugar: com o topo no topo da
   tela, centrada no recorte (`OverlayWindowChannel.positionAtNotch`). A
   prateleira aparece logo abaixo da barra de menus, e o arquivo, que já estava
   ali em cima, desce até ela.

Os números, ajustados na mão:

- **Encostar no topo, dentro da largura do recorte, dispara na hora.** A
  primeira versão pedia 200 ms parado lá em cima e nunca funcionou: um arraste
  que encosta na borda de cima abre o **Mission Control**, e o macOS ganhava a
  corrida. Na borda, em cima do furo, não há menu nem destino a confundir.
- **A zona desce 48 pt abaixo da barra de menus**, com 150 ms de cursor
  **parado** (6 pt de tremor). Quem mira o recorte chega por baixo dele, e a
  prateleira sai antes de o cursor alcançar a borda — e o Mission Control com
  ela. É parado, e não tempo dentro da faixa, porque a faixa é a das abas de um
  navegador maximizado: deslizar o arquivo por elas passaria dos 150 ms.
- **A borda só é parede quando é parede.** Com um monitor posto acima do
  MacBook, o cursor atravessa o topo a caminho dele; aí a borda não dispara
  sozinha, e vale a espera de parado como em qualquer ponto da zona.
- **Nada conta antes de haver arquivo na mão**, nem o relógio da espera — o
  ícone de documento de uma janela maximizada cai nesta faixa, e um relógio
  começado antes do arraste já teria vencido quando ele nascesse.
- **60 pt de folga de cada lado** do recorte — a largura das asas da ilha. O cursor não entra no furo — ele
  para na borda —, e mirar a largura exata de algo sem pixel é pedir precisão
  que ninguém tem segurando um arquivo.

**Desistir recolhe.** Se o arraste que chamou a prateleira acaba sem nada
solto nela — de volta no Finder, ou em lugar nenhum —, ela some sozinha
(`EvergreenBootstrap._closeNestIfUnused`). A pergunta é "algum arquivo foi
solto nela?" (`onDropped`), e não "passou por cima?" — a janela 0 inteira é
destino de arraste e está encostada no recorte, então "por cima" acende no
primeiro movimento — nem "ela tem itens?":
os itens só entram depois de cada arquivo ser lido do disco, e cinquenta
arquivos de um volume de rede deixariam a prateleira vazia por mais tempo que
qualquer espera. Cada arraste que chega ao notch ganha um número, e o fim de um
arraste só fecha a prateleira que **ele** abriu — nunca uma aberta de propósito
pelo atalho. Durante esse arraste a ilha sai do caminho do mouse: ela fica
acima da janela 0, e abrir com o cursor em cima cobriria o topo da prateleira.

**A entrada é uma pílula preta.** Ela nasce com a largura do recorte, encostada
no topo da tela, cresce até o tamanho do painel e se dissolve nele enquanto o
painel aparece por baixo (`_NotchReveal`, na `EgOverlayShell`, 260 ms). O
painel não se mexe durante a entrada — quem se move é a pílula —, então a
prateleira recebe arquivo desde o primeiro quadro. Com "reduzir movimento", sem
animação.

**É a terceira porta do Nest**, e a regra que dizia "não há terceira porta"
mudou de propósito: o que derrubou o recorte da primeira vez foi a janela
própria que não recebia nada, e esta porta não tem janela própria.

## A pilha mora no notch

A prateleira que sai do notch não é a prateleira inteira: é **a pilha**
(`NestNotchPile`) — preta, encostada no topo da tela, com os ombros côncavos da
ilha, mostrando o monte (capa, contagem, peso, de onde veio), as quatro
primeiras pastas favoritas como fichas (`⌘1 Clientes`) e "Abrir prateleira".
Só o que se faz de passagem: mandar tudo para uma pasta, ou arrastar a pilha
para fora. Escolher um a um, tirar, desfazer e o resto ficam na prateleira
completa, a um clique. **Quem decide o formato é a âncora do notch**
(`OverlayWindow.notchAnchor`): saindo do recorte, a pilha; no lugar de sempre,
a prateleira. "Abrir prateleira" só reposiciona a janela, e a âncora some com o
reposicionamento.

**Uma regra cobre todos os caminhos:** com notch, **enquanto a prateleira tem
arquivo, fechar o Nest nunca o faz sumir — ele recolhe para o notch.** A ilha
mostra a bandeja numa asa e a contagem na outra sempre que há arquivo e o
painel do Nest não está na tela (`NotchActivity.nest`). Esc, mouse saindo,
atalho: nenhum caminho precisa de caso especial, porque esconder a janela já é
o que traz a pilha de volta ao notch. Esvaziou (tudo enviado, ou tirado), a
ilha do Nest some.

| Situação | O que acontece |
|---|---|
| Arquivo levado ao notch, solto, mouse fora | A pilha recolhe para a ilha em 1,5 s |
| Mouse em cima da ilha do Nest | A pilha sai do notch; mouse fora, recolhe |
| `⌘⇧R` com arquivos | A pilha pelo notch, com o teclado; recolhe em 3 s se o mouse não for até ela |
| `⌘⇧R` com a prateleira vazia | A prateleira de sempre, no centro |
| Chacoalhar | A prateleira embaixo do cursor, como antes; fechada com arquivos, vai para o notch |
| Mac sem notch, ou "Abrir pelo notch" desligado | Tudo como antes |

- **Duas janelas, uma de cada lado.** A ilha recolhida é nativa; a pilha
  aberta é a janela 0 — a que recebe o arraste do Finder e deixa arrastar a
  pilha para fora. O mouse em cima da ilha do Nest não abre a ilha: pede a
  pilha ao Dart (`opensOnHover`).
- **Quando recolher** vem do relógio nativo que já segue o cursor para o
  clique atravessar a janela (`NestChannel.onPointerInside`). Com o botão do
  mouse apertado conta como dentro: o arquivo a caminho passa por fora da
  pilha, pela barra de menus.
- **O teclado só pelo atalho.** Pelo mouse ou pelo arraste a pilha aparece sem
  pegar o teclado (`OverlayWindowChannel.show(keyboard: false)`) — passar pelo
  notch não pode roubar as teclas de quem digita em outro app. Um clique nela a
  torna key, como qualquer painel.
- **Prioridade na ilha: Echo > Nest > Focus.** A pilha é curta e precisa ser
  vista; o foco dura 25 minutos e aguenta ceder a vez. Com o Echo gravando, a
  pilha fica escondida, e o `⌘⇧R` continua mostrando.

## A vitrine: a ilha do notch

### Por que uma segunda janela

A regra da casa é **só a janela 0** — ver
[focus-janela-compartilhada.md](focus-janela-compartilhada.md). A ilha é a
exceção, e a exceção foi pesada:

- **A janela 0 não serve.** Ela é compartilhada: abrir o Pin no meio da
  reunião a tiraria do recorte, e a vitrine sumiria justamente enquanto a
  pessoa trabalha.
- **O que a regra protege é engine e superfície viva**, e a ilha não tem
  nenhum dos dois. É AppKit puro — uma `NSPanel` com meia dúzia de views, sem
  Flutter —, e só existe na tela enquanto algo está rodando. O próprio
  documento do Nest já tinha registrado: *uma `NSWindow` sem engine é barata*.
- **Por que não em Flutter.** Uma ilha em Flutter exigiria um segundo engine
  residente e sempre no topo, que é o custo real que a regra existe para evitar.

### O Dart diz o quê, o Swift só desenha

O texto da interface continua morando num lugar só. O Dart monta cada
`NotchActivity` pronta — título, detalhe, relógio já formatado, botões com
rótulo — e manda a lista pelo canal `notch_island`; as cores vêm dos tokens
(`EgPalette`, incluindo o papel novo `notch`, o preto do hardware). O
`NotchIsland.swift` não sabe o que é uma reunião.

**A lista vai inteira, em ordem de prioridade**, e não só a primeira: a reunião
ganha do foco (uma gravação esquecida é o erro mais caro, e as asas não cabem
duas coisas), mas quem desligou o Echo no notch ainda quer ver o Focus quando
os dois rodam. Quem sabe o que está ligado no notch é o lado nativo, porque o
Hub — outro engine — o avisa direto, como o chacoalhar.

**As cores vêm dos tokens; as medidas, não.** Os tamanhos de fonte, raios,
respiros e a duração da ilha moram no Swift, porque são medidas de *uma peça
do sistema* — a altura da barra de menus e o recorte é que ditam —, e não
degraus da escala do Evergreen. É a única exceção à regra dos literais, e ela
vale só para a ilha. Os números ficam junto do que eles medem, no
`NotchIslandController` e na `NotchIslandView`.

### O desenho

- **Recolhida**, a ilha é o recorte alongado: uma pílula da cor do hardware,
  com cantos de baixo contínuos e **ombros côncavos no topo** — a borda da tela
  entra na pílula por uma curva, como entra no recorte. Numa asa o sinal de
  vida (o ponto de gravação e quatro barras do som, ou o anel do tempo do
  foco); na outra o relógio, em algarismos de largura fixa.
- **Com o mouse em cima** (150 ms de intenção, para quem só passa a caminho de
  um ícone), ela abre para baixo: título, detalhe, relógio; o equalizador das
  duas faixas (verde a sua voz, azul o sistema — as cores do painel do Echo) ou
  a barra de progresso do foco; e os botões. Clicar fora dos botões abre o
  painel do módulo. Fecha 250 ms depois de o cursor sair.
- **O equalizador é medida, nunca animação**, e é interpolado: a medida chega a
  cada 100 ms, e entre duas medidas as barras andam no ritmo da tela
  (`CADisplayLink`, 120 Hz num ProMotion), parado sempre que não há barra a
  mover.
- **A janela tem o tamanho do que está desenhado.** Uma janela do tamanho do
  painel aberto o tempo todo engoliria os cliques do topo de qualquer app
  embaixo (abas do navegador, barra de ferramentas). Ela cresce antes de a
  pílula crescer e encolhe depois de ela voltar.
- **Nunca vira key.** A ilha é de mouse, e uma janela que tomasse o teclado no
  meio da reunião roubaria a digitação do chat dela.

### A transcrição presa

Quando a gravação transcreve ao vivo, a ilha aberta ganha um terceiro botão,
**"Transcrição"**. Ele a prende num terceiro tamanho, mais largo (520 pt) e mais
fundo, com o texto ao vivo entre o título e os botões, e o mouse sair deixa de
fechá-la. **"Recolher"**, no lugar do mesmo botão, solta: ela volta a ser a
aberta pelo mouse e fecha como fecharia. Parar a gravação recolhe tudo.

- **Só para quem pediu o texto ao vivo.** A gravação guarda no começo se
  transcreve (`EchoRecorderState.isTranscribingLive`) — ligar a preferência no
  meio da reunião não dá texto a ela —, e sem isso o botão não existe.
- **Os trechos chegam fechados.** O lado nativo só manda resultado final
  (`isFinal`), então nada se reescreve enquanto se lê. O mais novo vem em texto
  principal, embaixo; os de antes sobem, apagam, e o topo se dissolve num
  degradê em vez de cortar a letra. Vão os quatro últimos — três linhas cabem.
- **O custo**: presa, ela cobre um pedaço do topo da tela — com a reunião no
  navegador, as abas. Foi a pessoa que prendeu, e recolher é um clique.
- **Pausar e parar continuam à mão** com ela presa: ninguém deveria precisar
  recolher a transcrição para parar a gravação.

### O custo assumido

Recolhida, a ilha avança 56 pt de cada lado do recorte, e **cobre os ícones da
barra de menus que caírem ali enquanto algo roda**. É o custo de todo app do
gênero; as asas são estreitas de propósito — cabe o sinal de vida e o relógio,
e mais nada.

### O que fica de fora

- **O Awake.** A trava já tem o lugar dela na barra de menus, e o notch é para
  o que se acompanha. Decisão do dono do produto, revisitável.
- **O Echo transcrevendo.** A ilha é sobre o que está acontecendo agora; a
  reunião que acabou aparece no Hub.
- **O Focus concluído.** Quem decide o que vem depois é o painel, e a
  notificação já avisou. "Encerrar" na ilha abre o painel, porque é lá que o
  Focus pergunta o resumo.
- **Uma grade de módulos ao passar o mouse.** Foi considerada e descartada:
  passar o cursor perto do notch não é intenção — ele passa ali o tempo todo —,
  e cada módulo já abre por atalho, menu e Hub.

## Preferências

Uma linha por módulo, na tela dele, e **só em Mac com recorte**: "Abrir pelo
notch" no Nest, "Mostrar no notch" no Echo e no Focus. Todas nascem ligadas, e
só o desligado é gravado (`notch.<id>`), como nas preferências de módulo.
Desligar o Nest desliga as três portas dele — atalho, chacoalhar e notch.

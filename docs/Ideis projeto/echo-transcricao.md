# Echo: por que a transcrição é toda nativa

> Decisão tomada em 14/08/2026, ao implementar o módulo.
> Registrada porque o `AGENTS.md` manda preferir Flutter puro e documentar em
> `docs/` toda vez que uma alternativa nativa vencer.

---

## O que o módulo faz

Grava a reunião, transcreve, e resume quando pedido. Tudo na máquina.

O Dart manda começar, parar e pedir. O *como* é todo Swift, em
`macos/Runner/EchoChannel.swift` — e são três coisas nativas por três motivos
diferentes, não uma só.

## As três partes nativas

### 1. Capturar o áudio — `ScreenCaptureKit`

O microfone sozinho grava só você, o que não é uma reunião. A fala das outras
pessoas sai pelos alto-falantes, e capturar isso no macOS exige `SCStream` com
`capturesAudio` (ou um driver virtual tipo BlackHole, que é pior: obriga a
pessoa a instalar um kext).

`excludesCurrentProcessAudio` impede o Evergreen de gravar a si mesmo.

#### O microfone não vem pela `SCStream` — e já veio

O desenho original usava `captureMicrophone` (macOS 15+): **uma única
`SCStream` entregando as duas faixas como saídas distintas** — `.audio` para o
sistema, `.microphone` para você. Uma permissão, um fluxo, sem mixagem. É o
caminho óbvio, e funcionou nas primeiras reuniões.

Depois parou de entregar, sem que nada no código tivesse mudado. O que o log do
sistema mostra, numa gravação em que só a faixa do sistema saiu:

- `tccd` responde **Allow** para `kTCCServiceMicrophone`;
- o `replayd` registra `hasMicrophoneAccessWithAuditToken: TCC Allow`,
  `SCMicAudioCaptureSession startCaptureSession`, `micCaptureSessionCount=1`, e
  a `AVCaptureSession` interna dele entra em `running -> 1` com o
  `AVCaptureDeviceInput` do microfone interno;
- o `coreaudiod` registra sinal na entrada durante a gravação inteira;
- e **nenhum bloco de tipo `.microphone` chega ao processo**. O arquivo da faixa
  nunca chega a ser criado.

Reproduzido em duas builds e duas configurações de `SCStreamConfiguration`
diferentes, com a faixa do sistema gravando normalmente ao lado. Não há erro
para tratar: a API inicia, diz que está capturando, e não entrega.

Hoje o microfone vem de um `AVAudioEngine` com tap no `inputNode` — o caminho
de sempre para gravar entrada no macOS, anterior ao `captureMicrophone`,
independente do `ScreenCaptureKit` e sem piso de sistema. As duas faixas
continuam separadas, que é o que sustenta saber quem falou; muda só quem
entrega uma delas.

O tap usa o formato do próprio dispositivo (`format: nil`) em vez de pedir um:
pedir um formato que o dispositivo não tem é o tipo de desencontro que faz a
entrada não entregar nada. A conversão para o formato do transcritor acontece
depois, igual para as duas faixas.

A entrada é aberta **crua**, sem o processamento de voz do sistema. Ele esteve
aqui de agosto a outubro de 2026 e saiu por mexer na reunião dos outros apps —
ver "Por que o processamento de voz saiu", adiante.

O motor é **religado sozinho** quando o microfone muda de formato no meio da
gravação. O `AVAudioEngine` para ao receber `AVAudioEngineConfigurationChange`
e não volta, e a troca acontece sem ninguém mexer em nada: basta o app da
reunião ligar o processamento de voz dele depois de o Echo começar, e o
microfone interno passa de um canal para três. Medido: o tap para de receber
blocos naquele segundo, e o resto da reunião sairia sem a sua voz.

Religar é **subir um motor novo**, não o mesmo: o motor que já rodou guarda o
formato antigo e continua entregando um canal só, que é uma cápsula crua
qualquer. O conversor da faixa é refeito quando o formato muda, e a escolha da
cápsula também. Cada troca deixa a faixa sem blocos pelo tempo de subir o motor
(150 a 400 ms medidos). Nos testes isso custou uma palavra. O buraco é medido
pelo relógio de cada bloco e **escrito como silêncio**: a faixa do microfone é
contígua, e sem o silêncio tudo o que se disse depois da troca ficaria adiantado
em relação à faixa do sistema. No áudio guardado, que mistura as duas, a
resposta sairia antes da pergunta.

O religamento só vale para a gravação em que o aviso nasceu (`micGeneration`).
O `stop` para o microfone antes da primeira espera, e um religamento atrasado
desiste em vez de subir um motor depois do fim. As faixas são fechadas dentro da
fila do áudio, e um bloco que chegue depois disso é descartado. Antes, um bloco
atrasado recriava o arquivo por cima da faixa gravada.

As cápsulas cruas chegam 35 a 40 dB abaixo do canal que o Mac trata, e o
transcritor perdeu o trecho inteiro gravado assim. Por isso, sempre que a
entrada tem mais de um canal, a faixa do Echo ganha volume (`EchoMicGain`): o
ganho segue o pico, nunca estoura, desce na hora e sobe devagar. O teto é de
+30 dB, para não transformar ruído de fundo em chiado. O caso comum de vários
canais é o microfone interno em cápsulas; uma interface USB de vários canais
cai na mesma regra. O canal único passa sem ganho nenhum.

#### A gravação sobrevive à troca de fone

> Acrescentado em 28/10/2026, depois de uma reunião (27/10) em que o fone
> entrou aos 1min53 e as duas faixas ficaram em silêncio digital dos 2min03 até
> o fim — 31 minutos (#157).

Três coisas, e nenhuma delas mexe em dispositivo, formato ou volume de nada —
o que o app da reunião manda da sua voz continua sendo o microfone que ele
escolheu:

- **O Echo não abre microfone Bluetooth quando o Mac tem um embutido**
  (`EchoAudioDevices.recordingInput`). Conectar um AirPods faz dele a entrada
  padrão, e abrir a entrada de um fone Bluetooth força o fone para o perfil de
  chamada para o Mac inteiro: o som da reunião que você ouve piora e engasga, e
  cada troca de perfil derruba o motor do microfone de novo. O app da reunião
  pode estar usando outro microfone, e aí quem forçava a troca era só o Echo. O
  embutido ouve a sua voz do mesmo jeito. A exceção é a tampa fechada: aí o Mac
  corta o embutido por hardware, e ele entregaria silêncio a reunião inteira.
- **O microfone é religado só quando parou de verdade**, com mais paciência (cinco
  tentativas em ~6 s, em vez de três em 1 s: um fone trocando de perfil leva
  segundos). O aviso de troca de formato chega em rajada com Bluetooth, e
  religar a cada um era derrubar e subir o microfone sem parar.
- **A captura do computador é religada** quando a saída de som padrão muda,
  quando a `SCStream` para sozinha (menos quando quem parou foi a pessoa, pelo
  menu do sistema) e, como rede, por um vigia (`EchoRecorder.watch`) que
  pergunta uma vez por segundo há quanto tempo cada faixa não recebe nada:
  microfone parado por 2 s, ou computador por 5 s, é religado. Religar é trocar
  a `SCStream` mantendo a mesma saída e os mesmos arquivos. Cada religamento
  que não resolve dobra a espera do próximo (o microfone até 1 min, o
  computador até 5 min) — sem isso, um Mac sem microfone, ou o computador
  calado porque nada toca, viravam um religamento a cada poucos segundos, e
  uma entrada Bluetooth religada sem parar mexeria no fone de todo mundo.

**As duas faixas têm o mesmo relógio.** Cada uma começava no primeiro bloco
dela, e o microfone sobe depois da captura do computador: na reunião de 27/10 a
sua faixa saía 120 ms adiantada, e o eco aparecia na transcrição *antes* da
fala que o causou. Hoje as duas contam do instante em que a gravação foi
montada, e **as duas** preenchem buraco com silêncio pelo relógio de cada bloco
(na do computador, pelo carimbo da `SCStream`). Antes só o microfone fazia isso,
e um buraco na do computador encurtava a faixa e adiantava tudo o que vinha
depois. A pausa é descontada dos dois relógios, e não vira buraco.

#### E a gravação avisa quando uma faixa fica muda

Era possível — e aconteceu — a reunião sair sem a metade de quem estava
falando, e nada na tela dizer isso. Cada faixa agora é contada e medida
enquanto grava (quadros escritos e pico de amplitude), e o resultado do `stop`
carrega os dois números. Com eles dá para separar as três coisas que antes
chegavam à tela como a mesma reunião vazia:

- a faixa que **não recebeu bloco nenhum** — a captura não veio;
- a faixa que recebeu **só zeros** — o som não estava lá;
- as duas com som, e a transcrição vazia mesmo assim — aí o problema é do
  reconhecimento, e a tela não inventa uma causa.

O caminho do arquivo só é devolvido ao Dart quando existe áudio nele. Antes ia
sempre, e o transcritor recebia o caminho de um arquivo que nunca foi criado.

### 2. Transcrever — `SpeechAnalyzer` (macOS 26)

`SFSpeechRecognizer`, a API antiga, foi feita para ditado curto: tem limite por
requisição e exige reiniciar a sessão. Para uma reunião de meia hora é briga.

O `SpeechAnalyzer` do macOS 26 é feito para áudio longo, roda no dispositivo e
tem uma conveniência decisiva: `analyzeSequence(from: audioFile)` transcreve um
arquivo inteiro de uma vez. Cada `Result` traz `range: CMTimeRange`, e é dele
que sai o relógio de cada fala.

#### O que chega no modelo importa mais que o formato do arquivo

> Acrescentado em 20/08/2026, depois de reunião transcrita com palavra trocada
> demais — inclusive em PT-BR, e inclusive comparada lado a lado com o Notas e
> o Gravador, que saíam melhor no mesmo Mac.

A causa **não era o idioma** (ele sempre viajou intacto das preferências até o
`SpeechTranscriber`) nem o tamanho do arquivo. Era o sinal que a gente entregava
ao modelo, e são três coisas distintas:

**1. A mixagem do arranjo de microfones.** O microfone interno do MacBook são
três cápsulas separadas por centímetros. Somá-las e dividir por três — que foi o
que salvou a faixa de sair muda — soma sinais que chegaram com atrasos
diferentes: é filtro pente, com vales bem no meio da banda da fala. Modelo de
fala com fonema borrado não erra "um pouco"; ele troca a palavra inteira pela
vizinha mais provável do idioma.

A resposta de agosto foi ligar `setVoiceProcessingEnabled(true)`. Ele saiu em
outubro (ver a seção seguinte). Hoje a faixa do microfone nunca soma cápsulas:
quando o microfone entrega mais de um canal, o Echo **escolhe uma**, a que ouviu
mais alto no primeiro bloco acima de −54 dBFS, e fica com ela até o fim
(`EchoStreamOutput.capsule`). Uma cápsula sozinha não tem com quem se defasar.

#### Por que o processamento de voz saiu

> Acrescentado em 20/10/2026, depois de uma reunião em que a pessoa do outro
> lado disse que a voz de quem gravava estava "longe", e voltou a ouvir nítido
> no instante em que o Echo foi desligado.

O processamento de voz não fica dentro do app que o liga. Medido num MacBook
Pro M5, macOS 27, com um segundo processo fazendo o papel do app da reunião:

- **O microfone muda para todo mundo.** Sem ninguém usando o processamento, o
  microfone interno entrega um canal só, que o próprio Mac já trata (feixe na
  direção de quem fala, sala abafada). Com um cliente de processamento ativo,
  ele passa a entregar as três cápsulas cruas a todos os outros apps, e volta a
  um canal quando o cliente sai. O app da reunião ficava com o som sem
  tratamento, distante e com a sala junto: era a voz "longe".
- **O som dos outros apps abaixa**, porque o macOS trata quem liga o
  processamento como quem está numa chamada. Com `.min`, o piso da API, a queda
  medida foi de 3 a 9 dB. E a atenuação **não sai junto com o processamento**:
  o que já estava tocando continuou baixo até o app recomeçar a tocar.
- **Um app que lê o microfone cru, sem processamento, não muda nada nos outros**:
  nem no nível do microfone deles, nem no som que sai.

E o que o processamento entregava ao Echo não fez falta. A mesma fala em
português, tocada no alto-falante e transcrita pelo `SpeechTranscriber`, errou
uma ou duas palavras em 38 nas quatro situações: com processamento, com o canal
tratado pelo Mac, com uma cápsula crua e com as três somadas. Num sinal limpo o
filtro pente das três somadas não apareceu, e a escolha de uma cápsula continua
sendo a conta certa. O cancelamento de eco passou a ser do Echo, depois da
reunião — ver a seção seguinte.

Uma primeira tentativa de tirá-lo, em agosto, durou um dia: o problema da época
era só o som abaixando, e o `.min` foi a teste antes de ser descartado. O
microfone dos outros apps mudando de formato não tinha sido visto.

**2. A reamostragem.** Descer de 48 kHz para 16 kHz é exatamente o tipo de
conversão em que o filtro importa: o que estiver acima de 8 kHz e não for
barrado antes **não some**, volta rebatido para dentro da banda da fala. O
`AVAudioConverter` saía na qualidade padrão, que é um meio-termo pensado para
tempo real. Agora sai em `AVAudioQuality.max` com o algoritmo `Mastering` — a
conversão é de um bloco de 4.096 quadros por vez, com a máquina praticamente
parada, e o filtro caro não custa nada que se perceba.

**3. As opções do transcritor, escritas uma a uma.** Um `Preset` é uma constante
opaca — não dá para ler o que ele liga, e existe uma opção que não pode entrar
por acidente: `.fastResults`, que troca precisão por latência. Num arquivo já
gravado não há pressa nenhuma. Pelo mesmo raciocínio ao contrário, a transcrição
ao vivo deixou de pedir `.volatileResults`: o painel só mostra frase fechada, e
pedir as revisões parciais era gastar processador durante a chamada para
descartar o resultado.

#### O eco da caixa de som sai no som, depois da reunião

> Acrescentado em 28/10/2026, depois de uma reunião pelo alto-falante do Mac
> em que a fala dos outros saiu duas vezes na transcrição e tocou dobrada no
> player (#156).

Sem o processamento de voz, nada mais tirava o eco: com a reunião na caixa, o
microfone ouve de volta o que o computador toca, uns 50 ms depois. O
`CrossTalkFilter`, que ficou sozinho, compara texto, e texto reconhecido duas
vezes nunca sai igual — "Interno" e "Interna", "1234567890" e "1234 5678 90",
uma frase inteira de um lado e três pedaços do outro. E o player soma as duas
faixas: o eco tocava junto, como uma voz dobrada.

Agora o `EchoCanceller` (`macos/Runner/EchoCanceller.swift`) limpa a faixa do
microfone no `stop`, antes de qualquer um ler o arquivo — a transcrição e o
áudio guardado. A faixa do computador é a referência, porque é o que foi tocado
antes de virar som no ar. Em três passadas pelos dois arquivos:

1. **o atraso**, por janela de 10 s, pela correlação do contorno de volume nos
   trechos em que o computador fala, e uma **reta** por cima (Theil–Sen): com a
   caixa numa interface USB e o microfone no Mac, cada aparelho tem o próprio
   relógio, e o atraso anda — 100 milionésimos são 360 ms por hora. Depois,
   refinado até a amostra a cada 10 s pela correlação de fase. A reta também
   protege o fone: sem eco, cada janela acha um atraso ao acaso, e atrasos ao
   acaso não ficam numa reta;
2. **onde há eco**: a mesma correlação numa janela de 10 s em volta de cada
   instante. De fone, o computador fala e o microfone não acompanha;
3. **a forma e o volume do eco** — a forma por frequência é da caixa e fica; o
   volume é do ganho da cápsula e de onde o som sai, e muda.

Com isso, cada quadro de 16 ms é julgado inteiro: se o microfone não passa do
eco esperado, ou se passa pouco e tem a mesma estrutura fina da referência
(coerência), ele desce ao **chão de ruído** do microfone; senão passa como
entrou. A decisão final é a da maioria entre ele e os dois vizinhos.

O que foi medido e descartado no caminho:

- **Tirar o eco frequência por frequência dentro de um quadro com você.**
  Parecia o meio-termo certo, e apagava a frase dita por cima de alguém para o
  reconhecimento, mesmo com 6 dB de folga sobre o eco.
- **Atenuar uma quantidade fixa de dB.** O reconhecimento normaliza o volume:
  eco 30 dB abaixo do original, mas acima do fundo da sala, ainda saía
  transcrito. Por isso o piso é o fundo da sala.
- **Um atraso só para a reunião inteira.** Com 37 ms de deriva em seis minutos,
  o eco voltava a passar na maior parte do tempo.
- **Filtro adaptativo que subtrai a onda** (o caminho clássico): diverge
  justamente quando os dois falam juntos, e a caixa do notebook distorce.

Calibrado com fala sintética em português (o `say`), eco simulado de caixa de
notebook — atraso, sala, distorção, o ganho da cápsula subindo e descendo,
deriva de relógio — e o próprio `SpeechTranscriber` antes e depois. Resultado:
a fala da reunião sumiu da sua faixa (eco 35 a 45 dB abaixo); a sua fala
sozinha saiu idêntica, porque onde o computador cala não há decisão; de fone,
nada foi tocado; a fala por cima se salvou com você mais alto que o eco. **No
mesmo volume do eco, ela se perde** — é o limite de quem não tem a onda do
eco, e o `CrossTalkFilter`, agora palavra a palavra, segue de rede para o que
escapar — menos quando o som mediu que não havia eco (fone): aí não há o que
procurar no texto, e procurar só arriscaria tirar um "bom dia" seu dito junto
com alguém. Uma hora de reunião custa uns 5 s, no `stop`.

O atraso aceito vai de −48 ms a +800 ms. O lado negativo é só a diferença de
latência entre as duas capturas: eco de caixa nunca chega ao microfone antes
de a referência tocar. Aceitar mais seria perigoso — quando alguém do outro
lado não tem cancelamento de eco, a *sua* voz volta pela faixa do computador
uns 250 ms depois de você, e o cancelador a tomaria por eco. Testado: com a
sua voz voltando assim, a sua faixa sai idêntica.

**Nada disto toca no microfone ao vivo.** Roda sobre a cópia do Echo, no disco,
depois de a gravação parar. O que o processamento de voz fazia de errado era
justamente mexer no que os outros ouviam da sua voz.

#### Por que **não** gravar em qualidade melhor

A pergunta é natural — o áudio é apagado no fim, então por que economizar? A
resposta é que não haveria ganho nenhum: o `SpeechTranscriber` consome 16 kHz, e
gravar a 48 kHz só faz o próprio framework reamostrar para 16 kHz antes de
ouvir. Seriam 6× o disco para entregar o mesmo sinal. A fala humana termina
abaixo dos 8 kHz, que é justamente o teto que 16 kHz preserva.

| Formato | Uma hora, as duas faixas |
|---|---|
| Hoje — 16 kHz mono | ~230 MB |
| 16 kHz Float32 mono | ~460 MB |
| 48 kHz Float32 mono | ~1,4 GB |
| Cru, sem converter | ~2,8 GB |

E há um contra que só aparece no volume alto: a pasta é `Caches`, e o macOS tem
licença para esvaziá-la quando o disco aperta. Com 230 MB isso nunca acontece;
com 3 GB num disco cheio, o sistema pode apagar a gravação no meio dela.

O que mudou no formato foi outra coisa: em vez de uma constante escrita à mão a
partir de uma medição feita uma vez, quem responde é o próprio analisador
(`bestAvailableAudioFormat`). O formato preferido pode mudar entre versões do
sistema, e entregar um que ele não aceita não devolve erro — aborta o processo
lá dentro. A constante antiga ficou como piso.

A única razão legítima para guardar áudio melhor seria retranscrever depois com
um modelo melhor — e isso exige guardar o áudio, que é exatamente o que este
módulo promete não fazer.

#### O idioma agora é conferido, e antes da reunião

`installLocale` respondia `true` mesmo quando não instalava nada: para um idioma
que o sistema não reconhece, `assetInstallationRequest` devolve `nil` — não há o
que baixar — e o `if` simplesmente não entrava. A tela comemorava, e o problema
só aparecia depois, como palavra trocada.

A lista de idiomas do `SpeechTranscriber` é **menor** que a do ditado antigo
(`SFSpeechRecognizer`), então oferecer um seletor escrito por nós sem perguntar
ao sistema é oferecer idioma que pode não existir. Agora:

- quem responde é `supportedLocale(equivalentTo:)`, que também resolve o caso de
  uma variante regional ser atendida por um modelo vizinho — a tela diz isso, em
  vez de deixar a pessoa achando que transcreve em PT-PT;
- a tela de preferências pergunta **exatamente o que a gravação pergunta**, e não
  a lista de suportados: a lista responde a pergunta errada, porque um
  identificador pode não estar nela e ainda assim ser atendido;
- a gravação recusa começar num idioma sem modelo. Descobrir isso depois de uma
  reunião de uma hora é tarde: o áudio já foi;
- o modelo é reservado (`AssetInventory.reserve`), senão o sistema o recolhe
  depois de um tempo sem uso e ele volta a ser um download no pior momento
  possível — o começo de uma reunião.

#### O vocabulário

Nome de pessoa, de empresa, de produto e jargão são precisamente o que um modelo
de fala erra: ele encaixa o som na palavra mais provável do idioma, e "Riverpod"
não é provável em português nenhum. A lista escrita nas preferências vai como
`contextualStrings` do `AnalysisContext` e inclina a decisão sem travar nada — o
que não está nela continua sendo reconhecido como sempre.

Vale para a transcrição e nunca para o resumo: o resumo já lê o texto pronto,
com os nomes escritos certos.

### 3. Resumir — `FoundationModels` (macOS 26)

O modelo do Apple Intelligence, exposto aos apps. Local, sem chave de API, sem
rede. `LanguageModelSession(instructions:)` recebe a instrução que a pessoa
escreveu nas preferências.

---

## Quem falou: a faixa decide o lado, o modelo separa as vozes

O Echo rotula "Você" e "Reunião" **sem nenhum reconhecimento de voz**, e por
isso não tem como errar: o rótulo vem de *qual faixa* o trecho veio. Microfone
é você; áudio do sistema é todo mundo menos você.

Cada faixa é transcrita em separado, e os trechos são intercalados pelo tempo
no fim. Numa conversa de duas pessoas isso é diarização completa. Numa reunião
de seis, dá "eu" e "os outros" — que é a divisão que mais importa quando se
relê depois.

Separar pessoa A de pessoa B **dentro** do áudio do sistema exige embedding
de voz e clusterização, e é difícil por um motivo de fundo: o que chega no
alto-falante já veio misturado. O Meet consegue rotular porque tem o stream
separado de cada participante; nós desfazemos uma mistura. Por isso foi
recusado aqui por muito tempo. Desde 14/10/2026 é feito pelo FluidAudio
(pyannote + WeSpeaker + VBx em CoreML), **por cima** da divisão por faixa, e
nunca no lugar dela. O lado continua sendo certeza, e "Pessoa 1", "Pessoa 2"
são palpite, em campos diferentes. Ver `echo-separacao-de-vozes.md`.

---

## O áudio é andaime

> **Desde a v0.25 o áudio da reunião fica por 14 dias** numa cópia comprimida,
> para o player da leitura. As faixas cruas descritas abaixo continuam sendo
> andaime e continuam sendo apagadas. Ver
> [echo-audio-da-reuniao.md](echo-audio-da-reuniao.md), que responde ao
> argumento de privacidade do último parágrafo.

Grava em `Caches/com.alencardev.evergreen/echo`, não junto do banco: é
temporário, e o macOS sabe limpar o que ficar para trás. Uma varredura no início
do app pega o que uma queda no meio de uma reunião deixou.

**A ordem é a regra:** a transcrição entra no banco primeiro, o áudio é apagado
depois. Nessa ordem, e nunca ao contrário — se a transcrição falhar, o áudio
fica onde está e a tela avisa. Apagar antes transformaria "a transcrição deu
errado" em "a reunião se perdeu", que é irrecuperável.

Apagar rápido não é economia de disco (meia hora dá menos de 10 MB comprimido).
É privacidade: o áudio de uma reunião é mais sensível que o texto dela — tem a
voz das pessoas, o tom, o que foi dito fora do assunto. Num app que se vende
como "tudo local", deixar isso parado no disco por descuido é o pior tipo de
vazamento, o que acontece na sua própria máquina e que você esqueceu que existe.

---

## O resumo é fatiado em Dart

A janela de contexto do modelo local não comporta meia hora de reunião, e ele
**não degrada com elegância**: estourar devolve erro, não um resumo parcial.

Quem corta em blocos é o Dart (`SummaryChunker`), porque é a única parte do
resumo que é lógica pura — e lógica pura se testa sem microfone, sem reunião e
sem modelo. O Swift resume um bloco por chamada.

**O tamanho do bloco vem da janela do modelo, não de um número fixo.** O Dart
pergunta o `contextSize` pelo canal (`summaryContextSize`) e o
`SummaryChunker.maxCharsFor` converte: os 5 mil caracteres medidos para a
janela de 4.096 tokens do macOS 26 continuam sendo o piso, e cada token a mais
vira três caracteres de texto — a reserva para a instrução e a resposta não
cresce com a janela. No macOS 27 a janela dobrou para 8.192, e o bloco passa de
5 mil para uns 17 mil caracteres: a reunião de meia hora que dava quatro blocos
e um resumo de resumos cabe numa chamada só. Quando o bloco estoura mesmo
assim, o Dart reparte ao meio e tenta de novo; o Swift reconhece o estouro
pelas duas formas que ele tem — `GenerationError.exceededContextWindowSize` até
o 26, `LanguageModelError.contextSizeExceeded` a partir do 27, que aposentou a
primeira.

São dois passos, e a distinção entre eles importa:

- **os blocos** usam uma instrução fixa e neutra ("preserve fatos, decisões,
  números e nomes; sem formatação"), porque são matéria-prima;
- **o passo final** aplica a instrução que a pessoa escreveu.

Se o formato pedido fosse aplicado já nos blocos, o passo final receberia
tópicos de tópicos e perderia o material bruto de que precisa. Bloco preserva
fato; o formato entra só no fim.

Um efeito colateral bom: trocar a instrução e refazer é barato — os resumos de
bloco já existem, só o passo final roda de novo.

---

## As duas permissões, e por que elas confundem

São duas, pedidas por APIs diferentes, com comportamentos diferentes. Uma tela
com um botão só de "pedir permissões" mente — e foi assim que este módulo
nasceu, com um botão que não fazia nada.

| | Microfone | Gravação de Tela |
|---|---|---|
| API | `AVCaptureDevice.requestAccess` | `CGRequestScreenCaptureAccess` |
| Abre diálogo | só enquanto o estado é "ainda não perguntei" | **uma vez na vida do app** |
| Depois de um "não" | retorna `false` na hora, calado | idem |
| Vale na hora? | sim | **não — só depois de reabrir o app** |

Três consequências que a interface precisa tratar, e trata:

1. **Distinguir "ainda não perguntei" de "já negaram".** É isso que decide se o
   botão pede de verdade ou abre os Ajustes. Sem a distinção, o botão parece
   quebrado: o sistema responde instantaneamente que não, e não há nada na tela.
2. **A gravação de tela não tem "ainda não perguntei" na API** —
   `CGPreflightScreenCaptureAccess` responde `false` para os dois casos. Por
   isso guardamos em `UserDefaults` se já pedimos alguma vez.
3. **Conceder a gravação de tela não basta:** o macOS só entrega a captura a um
   processo que subiu *depois* da permissão. A tela avisa para reabrir o
   Evergreen, em vez de insistir que falta permissão.

> **Em build de desenvolvimento** isso piora: sem assinatura estável, o macOS
> costuma invalidar a permissão de Gravação de Tela a cada build nova. É o mesmo
> problema que o README já documenta para o "iniciar com o macOS".

---

## O que ficou de fora

- **Separar pessoa A de pessoa B ao vivo.** Depois da reunião, sim (ver
  acima). Durante, não: ver `echo-separacao-de-vozes.md`.
- **Ignorar conteúdo sigiloso**: não se aplica aqui, mas vale para o Pin.
- **Transcrever durante a reunião como caminho principal.** A transcrição ao
  vivo existe e é uma preferência, mas é enfeite por construção: o áudio vai
  para arquivo nos dois modos, e o resultado final sempre sai do arquivo. Se o
  ao vivo falhar, engasgar ou for desligado no meio, nada se perde. Ele nasce
  desligado porque transcrever ao vivo custa processador justamente quando a
  chamada de vídeo já está consumindo a máquina.

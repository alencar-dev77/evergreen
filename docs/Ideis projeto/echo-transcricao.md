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

A entrada sobe com o processamento de voz do sistema ligado, e é por isso que
ela chega aqui como um canal só em vez do arranjo de três cápsulas do MacBook —
ver "O que chega no modelo importa mais que o formato do arquivo", adiante.

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

A entrada agora sobe com `setVoiceProcessingEnabled(true)`, que é o que o Notas
e o Gravador usam. Ele usa o atraso entre as cápsulas **a favor** (formação de
feixe), e vem com cancelamento de eco, redução de ruído e ganho automático de
brinde. O cancelamento de eco faz na origem o trabalho que o `CrossTalkFilter`
faz no texto — o filtro continua lá, porque nem toda entrada é a interna.

Se o motor de áudio recusar subir com o processamento ligado, ele desliga e
tenta de novo: gravar sem beamforming é pior, e é muito melhor que não gravar.

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

## Quem falou, sem modelo de diarização

O Echo rotula "Você" e "Reunião" **sem nenhum reconhecimento de voz**, e por
isso não tem como errar: o rótulo vem de *qual faixa* o trecho veio. Microfone
é você; áudio do sistema é todo mundo menos você.

Cada faixa é transcrita em separado, e os trechos são intercalados pelo tempo
no fim. Numa conversa de duas pessoas isso é diarização completa. Numa reunião
de seis, dá "eu" e "os outros" — que é a divisão que mais importa quando se
relê depois.

Separar pessoa A de pessoa B **dentro** do áudio do sistema exigiria embedding
de voz e clusterização (pyannote, sherpa-onnx), dependência pesada e nenhuma
delas nativa. E é difícil por um motivo de fundo: o que chega no alto-falante já
veio misturado. O Meet consegue rotular porque tem o stream separado de cada
participante; nós estaríamos tentando desfazer uma mistura.

---

## O áudio é andaime

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

- **Separar pessoa A de pessoa B** dentro do áudio do sistema (ver acima).
- **Ignorar conteúdo sigiloso**: não se aplica aqui, mas vale para o Pin.
- **Transcrever durante a reunião como caminho principal.** A transcrição ao
  vivo existe e é uma preferência, mas é enfeite por construção: o áudio vai
  para arquivo nos dois modos, e o resultado final sempre sai do arquivo. Se o
  ao vivo falhar, engasgar ou for desligado no meio, nada se perde. Ele nasce
  desligado porque transcrever ao vivo custa processador justamente quando a
  chamada de vídeo já está consumindo a máquina.

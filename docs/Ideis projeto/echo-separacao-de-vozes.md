# Echo, as vozes do outro lado

> Status: **implementado** em 14/10/2026. Código em
> `lib/features/echo/models/voice_separation.dart` (o casamento das vozes com
> as palavras) e em `macos/Runner/EchoChannel.swift` (`EchoDiarizer`).

## O que é

Até aqui o Echo dizia "Você" e "Reunião", e só: do outro lado podia haver
cinco pessoas, e todas viravam uma. Agora a faixa do computador é separada por
voz, e a transcrição diz "Pessoa 1", "Pessoa 2". A cada troca de voz começa um
turno novo, mesmo sem pausa entre os dois.

O que **não** mudou é a certeza da divisão entre você e os outros. Ela continua
vindo de *qual faixa* o trecho veio, e não de modelo nenhum (ver
`echo-transcricao.md`). A separação por voz é um palpite por cima dessa
certeza, e por isso mora num campo à parte: `MeetingSegment.speaker` é a faixa,
`MeetingSegment.voice` é o palpite. A sua voz nunca vira "Pessoa 2", porque o
microfone nem entra na diarização.

## Como funciona

São três passos, e só o primeiro é nativo.

1. **Diarizar a faixa do computador** (`EchoDiarizer`, Swift). Quem faz é o
   [FluidAudio](https://github.com/FluidInference/FluidAudio): segmentação
   pyannote, embedding WeSpeaker e agrupamento VBx, em CoreML, no Neural
   Engine. A resposta é só o relógio de cada voz (`[voz, início, fim]`), com
   um identificador que não quer dizer nada fora da reunião.
2. **Casar as vozes com as palavras** (`VoiceSeparation`, Dart). Cada palavra
   da transcrição já tem relógio (`MeetingWord`), e fica com a voz que mais
   soou enquanto ela soava. A decisão é por palavra, e não por trecho, porque
   o trecho do modelo de fala fecha onde ele achou a pausa, não onde a pessoa
   trocou: "pode ser na sexta? Sexta eu consigo." chega como um trecho só, e
   são duas pessoas.
3. **Numerar** na ordem em que cada voz aparece. "Pessoa 1" é quem falou
   primeiro do outro lado.

A ordem no `stopAndTranscribe` é: transcrever → `CrossTalkFilter` →
`VoiceSeparation` → `VocabularyCorrection`. Separar vem depois do filtro de
eco, para não pintar um trecho que vai sair, e antes do vocabulário, porque a
troca do vocabulário pode fundir duas palavras numa e apagar o ponto em que a
voz trocou.

### As três regras do casamento

- **Ilha curta volta para quem a cerca.** A diarização erra nas bordas (uma
  tosse, uma palavra dita junto), e uma frase sairia em três parágrafos por
  causa de uma palavra que "trocou de dono". O piso é 700 ms, e só vale
  *dentro* de um trecho e *entre* duas falas da mesma voz. Um "sim" de verdade
  de outra pessoa quase sempre chega como trecho próprio.
- **Palavra fora de toda voz fica com a mais próxima no tempo.** A diarização
  é mais exigente que o modelo de fala para chamar algo de voz. Um "Reunião"
  solto no meio de "Pessoa 1" e "Pessoa 2" seria uma terceira pessoa
  inventada.
- **Menos de duas vozes é nenhuma.** Numerar uma pessoa só como "Pessoa 1"
  não diz nada que "Reunião" já não dissesse. Isso vale para o que o modelo
  achou e também para o que sobrou depois de casar com as palavras.

## Enfeite, nunca bloqueio

Separar é enfeite sobre um texto que já está pronto, e por isso nunca derruba
a reunião. O canal tem um método só para isso (`diarize`), separado do
`transcribe`. Se ele falhar (sem rede na primeira vez, modelo corrompido), a
reunião é guardada exatamente como antes, com o outro lado inteiro em
"Reunião", e **sem aviso**. A reunião deu certo, e o erro de um detalhe dela
não é notícia.

Ela também não espera para sempre. Sem rede, o download desiste em uns 15 s
(quatro tentativas com espera crescente, duas vezes). Com uma rede que
responde devagar, o vigia do FluidAudio só desiste depois de 120 s parado, e
pode tentar de novo. Por isso o Dart corta em três minutos
(`_voicesTimeout`), e a reunião sai sem vozes. O lado nativo continua
baixando, e a próxima reunião já encontra o modelo pronto.

Enquanto separa, o painel troca a linha de baixo para "Separando as vozes — da
primeira vez, demora mais" (`EchoRecorderState.isSeparatingVoices`). Na primeira reunião essa
etapa baixa o modelo, e o "Transcrevendo" parado um minuto a mais pareceria
travado.

## O modelo é baixado, uma vez

Os modelos CoreML vêm do Hugging Face na primeira reunião com fala do outro
lado, e ficam na pasta do FluidAudio em Application Support. Daí em diante
tudo roda na máquina. **Nada sai dela**: o que trafega é o download do modelo,
como já acontece com o modelo de idioma do `Speech`. Foi decidido ligar sempre,
sem interruptor nas preferências.

O gerenciador nasce e morre a cada chamada. Os modelos ocupam dezenas de MB, e
a janela 0 vive o dia inteiro para usá-los alguns minutos.

## O que custou

- **O piso do app subiu de macOS 12 para 14.** O FluidAudio declara macOS 14,
  e o Xcode não linka um pacote cujo piso é maior que o do alvo. O Echo
  continua exigindo o 26. Uma alternativa era um executável à parte, com piso
  próprio, chamado por processo: mantinha o 12, mas criava outro alvo, outra
  assinatura e um protocolo a manter. Ficou descartada.
- **Um pacote SPM nosso no `Runner`**, ao lado do
  `FlutterGeneratedPluginSwiftPackage`, preso em versão exata. Ele traz junto
  um binário pré-compilado (`NemoTextProcessing`, ~8 MB, de normalização de
  texto para TTS) que o Echo não usa. Dá para cortar com o trait
  `NemoTextProcessing` do manifesto 6.2, mas uma referência de pacote no
  `.pbxproj` não tem onde declarar trait. Ele é baixado do GitHub quando o
  pacote é resolvido, então a primeira build numa máquina nova precisa de
  rede. A versão travada fica no `Package.resolved` do `Runner.xcworkspace`.
- **O bug do BNNS no macOS 14**, que o FluidAudio documenta e que derruba o
  processo inteiro, não alcança o Echo: a diarização só roda no 26.

## O resumo

Quando a reunião tem duas vozes ou mais, `LocalEchoSummaryRunner.voicesAttribution`
entra **no lugar** da `attribution`, e não ao lado dela. Ao lado, as duas
brigavam: uma proibia atribuir o áudio do computador a alguém, a outra deixava
atribuir a "Pessoa 2". Com as vozes separadas não sobra fala "Reunião:" para a
proibição alcançar. Sem a frase do número, o modelo lê o rótulo como nome próprio
("Pessoa 2 é a gerente do projeto") ou tenta casar o número com um nome dito
na conversa. A regra diz que o número não é nome, e deixa os rótulos entrarem
só onde distinguir pessoas é o conteúdo: quem ficou com a tarefa, quem
discordou de quem, e pede o rótulo ao lado da tarefa, porque o resumo de bloco
preserva "nomes próprios" e "Pessoa 2" não é um. O resto continua sobre o
assunto.

## O que ficou de fora

- **Separar ao vivo.** O texto ao vivo do painel é sinal de que o Echo está
  ouvindo, não documento: são as últimas seis linhas, sem rótulo de ninguém.
  Diarizar em tempo real (o Sortformer do FluidAudio, com quatro vagas fixas)
  custaria Neural Engine justamente quando a chamada de vídeo já está pesando,
  para enfeitar um texto que o arquivo refaz no fim de qualquer jeito.
- **Dar nome às vozes.** "Pessoa 2" vira "Ana" só se alguém disser. Renomear
  na leitura pediria uma coluna por reunião. Reconhecer a Ana na reunião
  seguinte pediria guardar a impressão digital da voz dela, que é dado
  biométrico, mesmo ficando local. Nenhum dos dois entrou.
- **Reunião antiga.** Só as gravadas a partir de agora ganham vozes. O áudio
  que fica por 14 dias é a mistura das duas faixas, e diarizar a mistura
  separaria a sua voz como mais uma, que é justamente o que a separação por
  faixa existe para evitar.
- **Cor por pessoa.** Todas as vozes do outro lado ficam no tom neutro. O
  verde é "ligado" ou "ação primária", e quem distingue "Pessoa 1" de
  "Pessoa 2" é o nome escrito ao lado.

# Echo, o áudio da reunião

> Status: **implementado** em 06/10/2026 (v0.25). Código em
> `lib/features/echo/` (player, varredura, transcrição clicável) e em
> `macos/Runner/EchoChannel.swift` + `EchoPlayerChannel.swift`.

## O que é

Na leitura da reunião, um player preso no topo: voltar 10 s, tocar/pausar,
avançar 10 s, o tempo e a barra. Enquanto o áudio toca, tudo o que já foi
dito fica aceso na transcrição — cumulativo, e não só a palavra da vez —, e a
leitura rola junto. A fronteira entre o aceso e o apagado é onde a voz está.
Clicar numa palavra leva o áudio até ela e acende todas as anteriores. É o que
o Notability fazia e o Echo não fazia.

Teclado: `espaço` toca e pausa, `←` `→` saltam 10 s — só com a leitura aberta
e uma reunião com áudio. Ver `ux.md`.

## A conta de disco

Medida para seis reuniões de 40 min por dia, com o banco real do autor como
base do texto (2,2 KB por minuto de reunião).

| O quê | Por reunião | Por dia | Por mês (22 dias úteis) |
|---|---|---|---|
| As duas faixas cruas, como o Echo grava (PCM, 16 bits) | ~154 MB | ~920 MB | ~20 GB |
| **O que fica: uma faixa AAC mono, 32 kbps** | **~8–11 MB** | **~50–65 MB** | ~1,2 GB |
| A transcrição, com o tempo de cada palavra | ~0,35 MB | ~2 MB | ~46 MB |

O AAC foi medido no próprio macOS: 60 s viram 203 KB a 16 kHz e 283 KB a
48 kHz (a taxa é a que o modelo de fala pediu para gravar). Com a validade de
14 dias, o teto prático fica perto de **600 MB**.

RAM não entra na conta: o `AVAudioPlayer` lê do disco, e a transcrição com
relógio por palavra ocupa menos de 1 MB na memória.

## As decisões

- **Uma faixa só, mixada.** As duas faixas existem para a transcrição saber
  quem falou; para ouvir, a conversa é uma. As faixas começam juntas e a pausa
  sai das duas, então somar amostra com amostra mantém o relógio do arquivo
  igual ao da transcrição. As cruas continuam sendo apagadas depois.
- **14 dias, ou até a reunião sair — o que vier primeiro.** O teto de reuniões
  (25 a 100) continua mandando: com 25 e seis por dia, a reunião sai no quinto
  dia e o áudio vai junto. Fixo, e não preferência: o número existe para o disco
  não crescer sem ninguém ver, e quem quer uma reunião para sempre tem a estrela
  (`EchoAudioRetention`).
- **A estrela guarda o áudio.** Mesmo gesto que já tirava a reunião da limpeza.
- **Apagar a reunião apaga tudo**, áudio incluído.
- **O backup não leva o áudio.** Ele é uma cópia do banco, e o áudio mora fora
  dele, na pasta `Reuniões` do aplicativo. Guardá-lo como BLOB incharia o banco
  e cada um dos cinco backups. Depois de restaurar, a linha que aponta para um
  arquivo que não existe é solta, e a reunião volta sem player.
- **Reuniões antigas não ganham áudio**: ele foi apagado depois da transcrição.
  E transcrições antigas não têm o relógio de cada palavra — nelas o destaque
  anda de trecho em trecho.

## Uma varredura, e não um "apaga também" em cada caminho

`EchoAudioJanitor.sweep`: **arquivo que nenhuma linha quer é lixo.** Apagar a
reunião, a limpeza do teto e o "Limpar histórico" só apagam a linha — o arquivo
vira órfão e sai na varredura seguinte. Roda na abertura do app e depois de
cada gravação. O áudio vencido sai do disco e a linha fica, com o texto.

## E a privacidade?

O `echo-transcricao.md` dizia que apagar o áudio logo era privacidade, não
economia: a voz é mais sensível que o texto. Continua sendo verdade, e é por
isso que o áudio **vence sozinho** em vez de ficar até alguém lembrar dele. O
que mudou foi o pedido: reouvir um trecho é uma necessidade real, e o meio-termo
é guardar por pouco tempo, na máquina, fora do backup, com a estrela como a
única forma de guardar para sempre — uma escolha explícita, reunião por reunião.

## Nativo, e por quê

- **O tempo de cada palavra** vem do `SpeechTranscriber` com
  `.audioTimeRange`: cada pedaço do `AttributedString` traz o próprio relógio, já
  com o espaço e a pontuação colados (`[ pessoal,]`). Juntar os pedaços devolve o
  trecho exato.
- **O arquivamento** é `AVAudioFile` em AAC, fora da thread do canal.
- **O player** é `AVAudioPlayer` num canal próprio (`echo_player`). Não existe
  áudio em Flutter puro: todo pacote é um plugin nativo, e um a mais entraria no
  callback de sub-janela e na fila da migração para SPM. O player mora na
  closure do canal do engine que o registrou — fechar o Hub para o áudio junto.

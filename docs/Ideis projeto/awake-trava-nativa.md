# A trava do Awake — por que ela virou código nativo

> Preferências do aplicativo → Awake → "Manter acordado".

O Awake nasceu sobre o `wakelock_plus`, e a escolha estava certa enquanto o
módulo tinha uma pergunta só: *manter a tela acesa?* O pacote registra um
`IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep)` — a mesma trava
do Caffeine e do Amphetamine — e o Swift equivalente já vivia dentro dele. O
projeto prefere Flutter puro; não havia por que escrever o nosso.

## O que faltava

Manter a tela acesa e manter o Mac acordado são **duas coisas diferentes**, e a
diferença é sobre o que se está fazendo:

- **tela acesa** é sobre olhar: a apresentação, o painel de monitoramento, a
  receita na bancada;
- **sistema acordado** é sobre terminar: a compilação, o download, o backup.
  Aqui a tela pode apagar — e é melhor que apague.

Com um modo só, quem deixava um build longo rodando precisava manter a tela
acesa a noite inteira para o Mac não suspender: gasta-se a tela para resolver um
problema que não é dela.

O `wakelock_plus` não alcança o segundo caso. Não é limitação de versão: a API
dele é `enable()`/`disable()`, sem qual assertion usar, e o tipo que ele
registra é fixo no Swift do pacote.

## A decisão

O canal `sleep_assertion` (em `macos/Runner/MainFlutterWindow.swift`) registra a
assertion diretamente, com o tipo vindo do modo escolhido:

| Modo | Assertion |
|---|---|
| Tela | `kIOPMAssertionTypePreventUserIdleDisplaySleep` |
| Sistema | `kIOPMAssertionTypePreventUserIdleSystemSleep` |

E o `wakelock_plus` saiu do `pubspec.yaml`. Mantê-lo para um modo e usar o canal
para o outro deixaria **dois mecanismos vivos** para "não deixar dormir" no
mesmo processo, cada um sem saber do outro — pior que escrever os dois no mesmo
lugar, que é o que a troca custou: cerca de sessenta linhas de Swift.

Três detalhes que a implementação carrega:

- **Uma assertion por processo.** Ligar num modo com o outro valendo troca a que
  existe, em vez de empilhar duas.
- **A antiga é liberada depois de a nova existir.** Entre uma e outra o Mac fica
  coberto pelas duas, que é o lado certo de errar — soltar primeiro abriria uma
  janela de milissegundos em que ele podia suspender no meio de uma troca de
  modo.
- **O nome aparece no `pmset -g assertions`.** É ali que se investiga "por que
  este Mac não dorme", e a linha precisa dizer quem foi: `Evergreen: Awake`.

## O que ficou de fora

**A escolha não é do painel.** O painel do Awake tem uma pergunta só ("por
quanto tempo?"), e o que muda de uma vez para outra é a duração — o modo se
decide uma vez, como qualquer preferência. Uma terceira linha no painel seria
uma decisão a mais na hora de ligar, que é o oposto do que o módulo é.

**A trava continua morrendo com o processo.** Ela vale enquanto o Evergreen
estiver de pé; encerrar o aplicativo a libera, mesmo com "Sempre" escolhido.
Uma assertion que sobrevivesse ao app seria um Mac que não dorme sem nada na
tela explicando por quê.

# Focus v0.2 — decisões de arquitetura

> Status: **implementado** na v0.2.
> Registrado em 25/07/2026, durante a construção do módulo Focus.

---

## 1. O Focus não abre uma janela própria

O Focus precisa de um painel flutuante invocável por `⌘⇧X` de qualquer lugar do
sistema — o mesmo requisito do Pin. O caminho óbvio seria criar uma segunda
janela flutuante.

**Não dá em Flutter puro.** Como já registrado em
[sugestoes-futuras-migracao-nativa.md](sugestoes-futuras-migracao-nativa.md), o
`window_manager` só estiliza a janela principal do app (a janela 0), e toda
sub-janela criada pelo `desktop_multi_window` nasce como uma `NSWindow` comum,
sem controle de tamanho, posição, nível ou transparência a partir do Dart. Uma
segunda janela flutuante exigiria um canal nativo novo, geometria por janela em
Swift e a decisão de quem é "sempre no topo" — trabalho nativo real, contra a
regra do projeto de preferir Flutter puro.

**A solução: os dois módulos dividem a janela 0.** Ela deixou de ser "o overlay
do Pin" e virou "a janela flutuante do Evergreen":

| Antes | Agora |
|---|---|
| `WindowKind.pinOverlay` | `WindowKind.overlay` |
| `PinOverlayWindow` | `OverlayWindow` |
| `home: PinOverlayView()` | `home: OverlayHost()` |

`OverlayHost` lê o `overlayPanelProvider` e desenha `PinOverlayView` ou
`FocusOverlayView`. O atalho global escreve nesse provider antes de mandar a
janela aparecer (`EvergreenBootstrap._showOverlay`).

Efeitos colaterais, todos a favor:

- **Um engine, não dois.** O custo de memória do Focus é ~zero.
- **Abertura instantânea** pelos dois atalhos, pelo mesmo motivo do Pin: a
  janela nunca é destruída, só escondida.
- **Trocar de painel com a janela aberta** é trocar de widget — `⌘⇧C` com o
  Focus na tela leva ao Pin sem piscar a janela.
- **A sessão continua correndo com o painel fechado**, porque o cronômetro vive
  no engine da janela 0, que não morre. Fechar o painel não é encerrar nada — e
  a barra de menus assume a contagem.

O que isso custa: as duas janelas compartilham tamanho e posição. Hoje isso não
incomoda (a janela é maior que os dois painéis e ambos são ancorados no topo),
mas se um módulo futuro precisar de uma geometria muito diferente, o assunto
volta — e provavelmente junto com a migração nativa daquele documento.

## 2. O aviso de fim de sessão é o próprio painel, não a Central de Notificações

Uma notificação nativa do macOS exigiria `flutter_local_notifications` (código
nativo + permissão do sistema + o usuário podendo silenciar sem saber). O painel
do Evergreen já é sempre-no-topo e já é onde a próxima decisão acontece
(iniciar a pausa, escrever o resumo) — então ele **é** a notificação, e o
caminho é 100% Dart.

Implementação: quando uma fase termina sozinha e a preferência "Avisar na tela"
está ligada, a ViewModel incrementa `FocusTimerState.alerts`; o bootstrap
observa esse contador e traz o painel para a frente. Um contador, e não um bool,
porque o app precisa distinguir "acabou de terminar" de "continua terminado".

Se a Central de Notificações entrar um dia, ela é **adicional** a esse caminho,
nunca substituta — o painel continua sendo onde o resumo é escrito.

## 3. O som é o alerta do sistema, sem pacote de áudio

`SystemSound.play(SystemSoundType.alert)`, do próprio `flutter/services`. Zero
dependências, zero arquivos empacotados, e o som é o que o usuário já configurou
no macOS. O canal é opcional por natureza: se a plataforma não implementar,
falha em silêncio e o aviso visual continua valendo.

## 4. O relógio virou uma dependência (`clockProvider`)

O cronômetro deriva o tempo restante de `DateTime.now()` contra um instante de
fim — assim ele não acumula desvio e uma suspensão do Mac não "congela" a
sessão. Isso, porém, tornaria um teste de sessão de 25 minutos uma espera de 25
minutos.

`clockProvider` injeta a função que lê o relógio. Em produção é `DateTime.now`;
nos testes é o relógio falso do binding do Flutter, avançado por
`tester.pump(...)`. Nenhum atalho de teste dentro da ViewModel.

## 5. O histórico é da semana corrente

O Focus guarda as sessões **da semana**, e a semana começa na segunda-feira à
meia-noite. Tudo que é de antes disso é apagado — não escondido — na primeira
leitura do histórico e na primeira sessão gravada depois da virada
(`FocusSessionRepository.trimToCurrentWeek`).

Por quê: o módulo responde "em que trabalhei nesta semana?". Um arquivo
histórico permanente pediria busca, filtro por período e agregação por mês —
exatamente o dashboard que este módulo recusa ser. E o que não é consultado não
precisa ser guardado.

Consequência de coerência: o segundo número do resumo é **"Esta semana"**, e não
uma janela deslizante de 7 dias — uma média móvel contaria tempo que já não está
mais na lista logo abaixo dela.

A fronteira é segunda 00:00 (e não 00:01): uma sessão iniciada 00:00:30 de
segunda pertence à semana nova, e qualquer outro corte a jogaria para a semana
que acabou de fechar.

## 6. As anotações da sessão

Durante o foco, o painel tem um campo que registra observações com o **minuto**
em que foram escritas ("aos 12 min — terminei a task e comecei outra"). O minuto,
e não o horário do relógio: o que importa é o ponto da sessão.

Duas decisões de forma:

- **O diário fica acima do campo.** O que já foi escrito não pode aparecer
  embaixo do lugar onde se escreve — a lista cresce para baixo, na direção do
  cursor, como qualquer registro cronológico.
- **Tudo vem do estado da ViewModel**, nunca dos `TextEditingController`. É o
  que faz fechar e reabrir o painel não perder nada: os controladores morrem com
  o widget, o estado não.

Persistência: coluna `notes`, uma anotação por linha no formato `minuto|texto`
(`FocusSessionNote`). Formato de linha, e não JSON, porque o campo de escrita é
de linha única — `\n` nunca aparece dentro de um texto — e assim a coluna
continua legível a olho nu em qualquer cliente de SQLite.

## 7. A migração do banco virou transacional (e só avança)

A coluna `notes` expôs um bug que estava lá desde o v0.1: `AppDatabase.migrate`
escrevia `PRAGMA user_version = <total de migrações>` **incondicionalmente**.
Um binário antigo (com menos migrações) abrindo um banco já migrado rebobinava
a versão — e o binário novo, na abertura seguinte, tentava aplicar de novo uma
migração que já estava aplicada: `duplicate column name: notes`.

Três mudanças:

- **A versão só avança.** Nunca se escreve um número menor que o gravado.
- **Tudo dentro de `BEGIN IMMEDIATE`.** As duas janelas do Evergreen abrem o
  banco quase ao mesmo tempo; sem transação, as duas podiam ler a mesma versão
  antiga e migrar em seguida. Junto veio um `busy_timeout`, para a segunda
  esperar em vez de levar `SQLITE_BUSY`.
- **"Coluna já existe" é tolerado, instrução a instrução.** É a assinatura de
  uma migração que já rodou; tolerá-la faz os bancos que passaram pelo bug se
  consertarem sozinhos na primeira abertura. Qualquer outro erro continua
  derrubando a migração inteira, com rollback.

## 8. O assert de teclado dos atalhos globais

Ao disparar `⌘⇧C`, `⌘⇧X` ou `⌘⇧,`, o macOS entrega a combinação ao atalho e
troca o foco de janela — a janela que estava em foco nunca recebe o "soltou"
das modificadoras. O framework continua achando que o Shift está pressionado e,
no próximo evento sintetizado ao reaver o foco, contradiz o próprio registro:

> A KeyDownEvent is dispatched, but the state shows that the physical key is
> already pressed.

É bug conhecido do Flutter no desktop e é **só um `assert`**: em release o
framework sobrescreve o estado e nada acontece. Em debug ele sobe como erro não
tratado e para o app no depurador a cada troca de janela por atalho.

`KeyboardStateGuard` filtra exatamente esse assert (e o irmão dele, "a tecla não
está pressionada") via `PlatformDispatcher.onError`. Qualquer outro erro segue
o caminho normal.

Por que não corrigir o estado do teclado: `HardwareKeyboard.clearState()` é
`@visibleForTesting` e, pior, limpar as teclas pressionadas troca este assert
pelo espelho dele no primeiro `keyUp` seguinte. O desencontro é da contabilidade
do embedder entre janelas, não do app.

## 9. O que ficou de fora, de propósito

- **Estatísticas além de dois números.** Hoje: tempo focado hoje e nesta
  semana. Sequência de dias e contagem de sessões foram avaliadas e descartadas
  na definição do módulo — o Focus responde "em que trabalhei?", não "como vai
  meu desempenho?".
- **Atividade como texto livre.** Integração com GitHub/Jira/Linear é assunto de
  uma versão futura; o campo `activity` da tabela já comporta isso.
- **Atalho global reconfigurável.** Mesma dívida registrada para o Pin: a linha
  nas preferências ensina o atalho, mas não aceita rebinding.
- **Uma tela de preferências do app.** O `⌘⇧,` abre o Hub de qualquer lugar,
  mas o Hub só tem telas de módulo — então o atalho é ensinado no menu da barra
  (`MenuBarAction.menuLabel`), e não em uma linha de configuração. Quando
  existir uma seção "Evergreen" no Hub, ela é o lugar dele.
- **Pausa automática.** Ao fim do foco o painel oferece a pausa, mas não a
  inicia sozinha: começar um descanso sem a pessoa pedir, enquanto ela ainda
  está trabalhando em outro app, seria decidir por ela.

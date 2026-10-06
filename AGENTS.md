# Project context

Evergreen é uma suíte pessoal de produtividade para macOS, feita como agente de
barra de menus (`LSUIElement`) — sem janela ao iniciar, sem ícone no Dock. Tudo
roda localmente, nada é enviado para a internet. São sete módulos: Pin
(gerenciador de área de transferência, `⌘⇧C`), Focus (cronômetro de foco com
registro de atividade, `⌘⇧F`), Leaf (parede de até nove anotações curtas,
`⌘⇧D`), Awake (mantém a tela acesa por um prazo, `⌘⇧X`), Echo (grava,
transcreve e resume reuniões, `⌘⇧E`), Nest (prateleira que junta arquivos de
várias pastas e manda todos para uma só, `⌘⇧R`, ou chacoalhando o arquivo no
meio do arraste) e
Track (reconstrói o dia a partir do que os outros gravaram — só tela do Hub,
sem atalho global e sem painel).

Domain: produtividade pessoal / utilitário de sistema para macOS.

# Stack

- **Flutter** (Dart SDK ^3.11.5) — app desktop nativo, sem backend.
- **O piso é macOS 12, e quem o escolheu foi a ferramenta.** Era 10.15, e o
  `macos_deployment_target_migration` do Flutter reescreve `10.11`, `10.13`,
  `10.14`, `10.15` e `11.0` para `12.0` no primeiro build — no `project.pbxproj`
  e no `Podfile` juntos, porque os dois precisam concordar. Reverter à mão não
  para de pé: o build seguinte reescreve de novo. Fica registrado aqui porque a
  linha antiga dizia 10.15 e ninguém tinha decidido trocá-la; o custo real é
  pequeno, já que o macOS 11 é de 2020 e o Echo já exigia o 26.
- **A build é híbrida, SPM mais CocoaPods — e falta um só para deixar de ser.**
  Seis dos sete plugins nativos vêm pelo Swift Package Manager; o
  `hotkey_manager_macos` é o último de CocoaPods, e é ele que segura o
  `Podfile` de pé. Não é escolha nossa: o suporte a SPM tem de vir num
  `Package.swift` **dentro do plugin**, e a 0.2.0 dele — a última — só traz
  `.podspec`. Enquanto isso o Flutter avisa a cada build, e promete transformar
  o aviso em erro; no dia em que transformar, o que para é todo atalho global.
  A saída, se a hora chegar antes do autor, é vendorizar o plugin com um
  `Package.swift` nosso. O `desktop_multi_window` era o outro da lista e saiu
  dela na 0.3.1, cujo changelog é exatamente essa uma linha — vale reconferir
  o `hotkey_manager` de tempos em tempos pelo mesmo caminho:
  `flutter pub outdated`.
- **Riverpod** (`flutter_riverpod`) — gerenciamento de estado, padrão MVVM.
- **SQLite direto** (`sqlite3` via native assets) — não usa Isar (descartado:
  sem manutenção ativa, codegen quebra no Dart 3.11); acesso isolado atrás de
  `ClipboardRepository`. Ver [docs/Ideis projeto/](docs/Ideis%20projeto/) para
  decisões de arquitetura descartadas.
- **`desktop_multi_window`** — o Hub roda em um engine Flutter próprio;
  sub-janelas nascem sem plugins, por isso o Runner nativo precisa registrar
  callback de criação (ver Convenções). A janela flutuante (janela 0) é
  compartilhada por Pin, Focus e Awake — ver
  [docs/Ideis projeto/focus-janela-compartilhada.md](docs/Ideis%20projeto/focus-janela-compartilhada.md).
- **`window_manager`, `tray_manager`, `hotkey_manager`, `screen_retriever`** —
  janela flutuante, ícone da barra de menus, atalho global.
- **`launch_at_startup`** — "iniciar com o macOS", via canal nativo próprio
  (`SMAppService`), não o pacote nativo sugerido pela lib.
- **`IOPMAssertionCreateWithName`** (nativo, canal `sleep_assertion`) — a trava
  do Awake, em dois modos: `PreventUserIdleDisplaySleep` (a tela) e
  `PreventUserIdleSystemSleep` (só o sistema, com a tela livre para apagar). Era
  `wakelock_plus`, que registra sempre a de tela e não expõe escolha — e manter
  a tela acesa a noite inteira para uma compilação terminar gasta a tela para
  resolver um problema que não é dela. Com o Swift necessário para um dos modos,
  dois mecanismos vivos para "não deixar dormir" seria pior que escrever os dois
  no mesmo lugar. Ver
  [docs/Ideis projeto/awake-trava-nativa.md](docs/Ideis%20projeto/awake-trava-nativa.md).
- **`ScreenCaptureKit` + `Speech` + `FoundationModels`** (nativo, macOS 26) — o
  Echo. Captura de áudio em duas faixas, transcrição e resumo local, sem
  equivalente em Flutter puro; o porquê de cada um está em
  [docs/Ideis projeto/echo-transcricao.md](docs/Ideis%20projeto/echo-transcricao.md).
  Exige macOS 26 e é o único módulo com piso de sistema próprio — o canal
  responde `unsupported_os` abaixo disso, e o resto do app segue no 12.0.
  Durante a gravação o canal **sobe** dois avisos para a janela flutuante: o
  texto ao vivo (só com a preferência ligada) e o `onLevels`, que é o espectro
  de cada faixa dez vezes por segundo: uma FFT (`Accelerate`/`vDSP`) sobre os
  últimos 32 ms, agregada em dez bandas por oitava entre 110 Hz e 6 kHz. É o
  que o painel desenha como equalizador, e é medida, nunca animação — um pico
  só por faixa daria dez barras da mesma altura. **Pausar não para a captura**: os blocos continuam
  chegando e são descartados, então o trecho pausado não entra no arquivo nem
  na duração (o `stop` desconta o tempo pausado). Parar e recomeçar a
  `SCStream` criaria um segundo arquivo por faixa e faria a transcrição
  remontar duas gravações como se fossem uma.
  **O áudio da reunião fica 14 dias**, numa cópia AAC mono de uma faixa só na
  pasta `Reuniões` do aplicativo (`EchoAudioStore`), ou até a reunião sair pelo
  teto — o que vier primeiro; a estrela guarda os dois. Fora do banco e, por
  isso, **fora do backup**. Quem tira do disco é uma varredura só
  (`EchoAudioJanitor`): arquivo que nenhuma linha quer é lixo, então apagar a
  reunião por qualquer caminho não precisa lembrar do áudio. O player é
  `AVAudioPlayer` num canal próprio (`EchoPlayerChannel.swift`), um por engine:
  fechar o Hub para o áudio. A transcrição guarda o relógio de cada palavra
  (`MeetingWord`): tudo o que já foi dito fica aceso, cumulativo, até a palavra
  que toca. Ver
  [docs/Ideis projeto/echo-audio-da-reuniao.md](docs/Ideis%20projeto/echo-audio-da-reuniao.md).
- **`QLThumbnailGenerator` + `NSOpenPanel` + destino de arraste** (nativo,
  canal `nest`) — o Nest. Quem recebe o arraste do Finder é o **delegate da
  janela**, nunca a janela nem uma view invisível: `NSWindow` não implementa
  `NSDraggingDestination`, e o AppKit acha uma view pelo mesmo `hitTest` do
  mouse — as duas alternativas falham em silêncio, com o arquivo caindo e nada
  acontecendo. A miniatura é o mecanismo das prévias do Finder, e arrastar a
  prateleira **para fora** é uma `NSDraggingSession` da view do Flutter —
  nenhum dos três tem equivalente em Flutter puro. A saída tem dois caminhos:
  as pastas favoritas (`⌘1..⌘9`, com desfazer, porque quem copia somos nós) e
  o arraste para qualquer lugar (sem desfazer: copiando, quem copia é o
  destino; movendo, o arraste é uma promessa de arquivo que nós cumprimos,
  porque o destino lê o `⌥` sozinho e um `.move` declarado nascia proibido).
  O `NestDrop` recusa o arraste cuja origem é a própria prateleira — sem essa
  recusa o arquivo atravessaria o painel e cairia na janela atrás dele. A
  outra porta é **chacoalhar o arquivo** (`NestShakeMonitor`), e a regra dela
  é *perguntar, nunca escutar*: durante uma sessão de arraste o AppKit não
  entrega movimento de mouse a monitor nenhum, então quem responde é
  `NSEvent.mouseLocation` e `NSEvent.pressedMouseButtons`, que são
  propriedades e não custam permissão. O único evento apanhado é o botão
  descendo, que acontece antes do arraste. Só dispara com arquivo na mão
  (`NSPasteboard(name: .drag)`, tipo **e** `changeCount`), e é a única porta
  em que o painel vai até o cursor em vez do contrário
  (`OverlayWindow.positionForCursor`). Não há terceira porta — o recorte de
  tela foi tentado e saiu: **só a janela 0**. Ver
  [docs/Ideis projeto/nest-prateleira-de-arquivos.md](docs/Ideis%20projeto/nest-prateleira-de-arquivos.md).
- **`shared_preferences`, `path_provider`, `intl`, `package_info_plus`** —
  persistência simples, paths do sistema, formatação de data/hora e a versão
  que o rodapé da sidebar do Hub mostra (`lib/core/app_info.dart`).

# Project conventions

- MVVM com Riverpod. Regra de ouro: **nenhuma lógica de negócio em widget** —
  fica em ViewModels (`Notifier`).
- Estrutura por feature em `lib/features/<modulo>/{data,models,presentation}`;
  `presentation` se divide em `viewmodels/`, `views/`, `widgets/`.
- **Todo módulo se liga e se desliga, e o atalho global de cada um é
  regravável.** As duas preferências moram no mesmo lugar
  (`ModuleSettingsRepository`, chaves `module.<id>.enabled` e
  `shortcut.<slot>`) e só o que **difere do padrão** é gravado: módulo ligado
  não tem chave e atalho intocado também não — é o que faz um módulo novo
  nascer ligado, e o que faz uma versão que troque a tecla de fábrica alcançar
  quem nunca gravou nada sem atropelar quem gravou. A chave usa
  `EvergreenModule.id`, nunca o `name`, que **neste enum é o nome de
  exibição**. Desligar tem quatro efeitos, e os quatro juntos: some do menu da
  barra, o atalho não é registrado, a tela do módulo fica apagada (`ModuleGate`,
  montado pelo Hub em `_content` — a tela do módulo não sabe disso) e o que
  rodava para (o Pin deixa de capturar a área de transferência, o Awake solta a
  trava, o Nest desliga o chacoalhar). O que estava em curso é encerrado
  **guardando** — sessão do Focus para o histórico, reunião do Echo transcrita.
  Nada é apagado, e o módulo desligado **continua na barra lateral**: sumir
  deixaria o interruptor de religar dentro da tela que sumiu. O atalho do Hub
  nunca é desregistrado, porque é a porta para religar o resto. Ver `ux.md` na
  skill de design.
- **Combinação de atalho tem uma fonte de verdade só**: o
  `GlobalShortcutSlot`, que guarda o padrão, e a preferência por cima dele.
  Havia três — o `HotKey`, a lista de key-caps da tela e um texto solto no item
  do menu da barra —, e foi por isso que o Nest ficou meses com `⌘⇧S` escrito
  num lugar e outra tecla registrada no sistema. Quem valida é
  `ShortcutRules`, que é puro: piso de duas modificadoras com `⌘` ou `⌃`, a
  lista curta do que o macOS toma de todo mundo, e conflito conferido contra os
  sete slots — inclusive os de módulos desligados, cuja tecla continua
  reservada. **E ela é impressa em dois lugares na tela de um módulo, não em
  quatro**: a barra lateral, que é o mapa do teclado, e a seção "Atalho
  global", que é onde se troca. Estava também ao lado do interruptor mestre e
  na faixa de estado — na tela do Leaf a mesma combinação aparecia quatro vezes
  de uma vez, e as duas cópias que saíram eram as que não faziam nada com ela.
  Fora da tela do módulo continuam valendo o menu da barra (que ensina o atalho
  no item que ele dispara) e o mapa de "Todos os atalhos num lugar", na tela do
  aplicativo. Gravar **suspende os atalhos do sistema** enquanto a tela escuta,
  senão apertar `⌘⇧C` para gravar abre o painel do Pin por cima das
  preferências.
- **Preferência decidida no Hub e aplicada na janela 0 atravessa o
  `ModuleSettingsHost`** — canal unidirecional, registrado uma vez só na janela
  0, mesmo arranjo (e mesmas razões) do `EchoSummaryHost`. Escrever no disco não
  avisa ninguém: sem a ponte, desligar o Echo só valeria no lançamento
  seguinte. Quem chama é o `ModuleSettingsNotifier`, que é **interface** e vem
  por provider — no relógio falso do teste de widget a resposta do canal nunca
  chega, e a tela que grava um atalho travaria esperando para sempre (a mesma
  armadilha do `NestFileService`).
- **Bandeira de build mora em `lib/shared/feature_flags.dart`**, e é `const`:
  quem mexe é quem builda, não quem usa. Bandeira serve para **desligar algo
  pronto**, nunca para esconder algo pela metade — o código atrás dela continua
  compilando, nos testes e nos goldens, senão o dia em que ela voltar a `true`
  entrega uma ruína. Teste de bandeira passa **nos dois estados** (`skip:
  !FeatureFlags.x` no que só existe de um lado); teste que só passa ligada
  obriga a mexer na suíte para desligar a funcionalidade, e aí ninguém desliga.
  Hoje existem duas, as duas em `true`: `intro` (a abertura animada do Hub) e
  `onboarding` (a apresentação de boas-vindas). Cada uma decide num ponto só —
  `HubIntroViewModel.build` e `OnboardingViewModel.build` —, e nenhuma grava o
  "já vi" quando desligada: religar apresenta quem nunca foi apresentado, em vez
  de ter consumido a vez dele calado. Houve uma terceira, `themes`, e ela saiu
  junto com o tema `apple`: uma bandeira existe para desligar algo pronto, e o
  que ela desligava deixou de existir.
- **O app é dark-only e tem uma pele só, a "Estufa" — e widget nenhum guarda um
  valor visual.** Tudo vem do tema pelo contexto (`context.eg.colors.accent`,
  `context.eg.text.body`, `context.eg.shapes.radiusCard`); os literais existem
  só em `lib/core/design/themes/evergreen_tokens.dart`. Todo campo dos tokens é
  `required`, então é o compilador que cobra o papel que falta. Houve um segundo
  tema, o `apple`, e ele saiu: a escolha de aparência estava desligada por
  bandeira desde que nasceu, e o segundo arquivo dobrava o custo de cada papel
  novo. Se voltar, volta como um `EgPalette` completo — nunca como `if`s
  espalhados.
- **O canto é contínuo acima de 14** (`EgSquircle.shape`): o macOS não arredonda
  com arco de círculo, e era daí que vinha o "tudo muito quadrado". Superfície
  interativa desenha com `ShapeDecoration`, não `BoxDecoration`. Abaixo do
  limiar o arco fica, por ser mais barato.
- **A janela do Hub é fixa em 980×680 e não redimensiona.** É a largura em que
  o cartão de preferência foi desenhado, e uma janela que encolhe é uma tela
  que ninguém desenhou. Tirar `.resizable` não impede a região de leitura de
  crescer a janela pelo `setFrame`.
- Espaçamento, tamanho de ícone e **durações** seguem estáticos em
  `app_metrics.dart`, e isso é decisão: o ritmo é do produto, não da pele — um
  app que fica mais lento ao trocar de aparência estaria mentindo sobre o que a
  troca faz. Do movimento, só a curva é do tema.
- `copyWith` em estilo de texto vale só para cor; peso e tamanho são degraus da
  escala, e degrau que falta entra na `EgTypeScale` com nome.
- Componentes compartilhados usam prefixo `Eg` em `lib/shared/widgets/`.
  Ícones são paths customizados (`EgIcon`), não Material Icons.
- **A marca do Evergreen é um desenho só**, o canivete de
  `lib/shared/widgets/eg_brand_mark.dart`. A abertura do Hub, o ícone do
  aplicativo, o da barra de menus e o glifo da barra lateral saem todos dele —
  os `.png` são **gerados** por
  `flutter test --run-skipped -t assets test/tools/brand_assets_test.dart`, e
  não existe `.svg` ao lado. Havia um, e foi por causa dele que o pinheiro
  continuou no ícone do aplicativo e na barra de menus depois de a marca do Hub
  já ser o canivete: dois desenhos, e só um trocado.
- **Tela de preferência tem ordem fixa de tópicos**: o que aconteceu (a lista do
  módulo) → o que ele faz (interruptores no topo de cada tópico, depois
  seletores, campos de texto por último) → limites e ações destrutivas → atalho
  global → permissões. A pilha é a `EgSettingsPage` — **uma coluna, sempre**, com
  o `banner` acima dela; foram duas, e o assunto seguinte ficava ao lado do
  atual em vez de abaixo, o que trocava a leitura de cima a baixo por um
  vaivém. O cartão é o `EgSettingsCard`, que dá o respiro e desenha os
  divisores — a linha não decide sozinha se tem divisor embaixo. O interruptor
  mestre **não** é a primeira seção: ele vive no `EgScreenHeader`, como pílula
  ao lado do título — e é a **única** coisa à direita do título, porque a tecla
  do módulo saiu de lá (ver a regra do atalho). Módulo com mais de um assunto ganha abas no
  mesmo cabeçalho (Pin, Focus, Echo, Nest); módulo de um assunto só não ganha,
  porque uma aba sozinha é a promessa de que existe outra. Campo de texto usa
  `EgSettingsRow.field`, nunca um rótulo com um campo solto embaixo. O detalhe
  de cada regra está em `components.md` da skill de design.
- Estado de elemento interativo (hover, pressed, foco, selecionado, desabilitado)
  vem da matriz `EgSurfaceStyle` (`eg_surface.dart`), via `EgInteractiveSurface`
  ou `EgSurface` — nunca de uma cadeia de `if`s dentro do widget. **Selecionado
  é elevação e peso, nunca cor**: a superfície `raised` mais a linha de luz de
  1px no topo (`innerHairline`) e o texto em `bodyStrong`, a mesma em linha de
  lista, item de sidebar e cartão do Leaf. Era accent a 14% mais uma aresta
  verde de 3px, e trocar a cor pela luz é o que devolveu ao verde os dois
  papéis que sobraram para ele: **ligado, ou ação primária**. Um componente
  com combinação própria compõe uma `EgSurfaceStyle` a partir dos tokens; a
  ordem de precedência é a mesma para todo mundo. A folha visual de todos os
  estados é o golden `test/goldens/design_state_matrix.png`.
- **Quem se anuncia ao leitor de tela é o `EgHoverable`**, não cada componente
  — mesmo raciocínio da matriz `EgSurfaceStyle`: ele é o único que sabe que algo
  é clicável, focável e ativável por Enter. Ele dá papel de botão, estado de
  habilitado e funde o conteúdo numa etiqueta só; `semanticLabel` **substitui**
  o que os filhos diriam (para a linha do Pin, que precisa de uma frase), e
  `selected`/`toggled` põem na árvore o que hoje só a cor mostra. Duas regras:
  `selected` é `true` ou nada, nunca `false` (um "não selecionado" em todo botão
  é ruído), e `mergeDescendants: false` é obrigatório quando há outro clicável
  dentro — a linha do Echo tem a estrela, e fundir engoliria ela junto. `EgIcon`
  é decorativo por padrão: quem nomeia é o pai, senão o leitor diz "ícone de
  fixar, fixar". O que prende isso é `test/shared/semantics_test.dart` — rótulo
  que some não quebra pixel nenhum e não falha nenhum outro teste.
- Painel flutuante novo usa `EgOverlayShell`: ela é quem registra o
  `WindowListener`, anima a entrada, decide o que é um blur de verdade, trata o
  vazio ao redor como barreira e **garante que o painel aberto tenha teclado**.
  O módulo só diz o que "fechar" significa para ele. Sobre o teclado: um painel
  pode nascer sem ninguém pedir foco (trocar de painel com a janela já visível
  não dispara `didBecomeKey`, logo não há `onWindowFocus` nem `onShow`), e sem
  nó focado nenhum `Shortcuts` é consultado — o painel fica na tela e cada tecla
  vira o bipe do macOS. A casca escuta o `FocusManager` e devolve o foco ao nó
  do módulo, ou ao dela quando o módulo não tem um. A recuperação é sempre
  adiada até depois das microtarefas do quadro: o `autofocus` de um campo do
  módulo é aplicado numa delas, e chegar antes dele abriria o Pin sem cursor na
  busca. Dois comportamentos são opt-in e hoje só o Echo pede os dois:
  `draggable` (arrasta a janela pelo fundo do painel, via `startDragging`) e
  `dismissOnBlur: false` (perder o foco não fecha). O segundo é **por fase**,
  não por módulo — o Echo só o desliga gravando ou transcrevendo, e a casca
  reconfere a bandeira depois da margem de tolerância porque a fase pode virar
  no meio dela. Painel que não pede nada continua com o comportamento de antes.
- A janela 0 é movível (`setMovable(true)`) só para o `startDragging` do painel
  ser aceito pelo macOS; nada liga o arrasto pelo fundo da *janela*, então os
  painéis que não pedem `draggable` seguem parados onde nascem.
- **Toda tela com atalho de teclado precisa de um `FocusScope` logo abaixo do
  `Shortcuts`/`CallbackShortcuts` dela.** No macOS um `TextField` larga o foco a
  cada clique fora dele, e o foco largado sobe até o escopo da rota — que fica
  *acima* do mapa de atalhos. Dali nenhuma tecla volta a descer: a tela inteira
  emudece e vira só de mouse; o Esc que não fecha é o sintoma que se nota
  primeiro. O escopo é o chão que faz esse foco cair dentro da tela. Já está
  posto na `EgOverlayShell` (os cinco painéis) e no `hub_view.dart`; tela nova
  fora desses dois caminhos põe o seu.
- Campo de texto guarda ao perder o foco, por qualquer caminho — clique fora,
  troca de item, fechamento do painel. Vale para o apelido do Pin, o cartão do
  Leaf e os campos das telas de preferência. O Esc é a única saída que
  descarta, e ele desfaz a edição **antes** de o campo sair da árvore, então
  nunca colide com o commit do foco perdido. A contrapartida disso no Leaf é o
  `⌘Z`: como esvaziar o campo apaga a anotação, e sair do campo confirma
  sozinho, a parede guarda o último cartão arrancado até o painel fechar — ação
  destrutiva sem pergunta precisa de desfazer, nunca de um diálogo.
- Acesso a dados sempre atrás de repositório (ex.: `ClipboardRepository`) —
  nunca acoplar UI/ViewModel diretamente ao SQLite.
- A busca do Pin mora inteira em `PinSearch` — casar e pontuar são a mesma
  conta, e ela é do domínio, nunca do widget. Duas regras que não se negociam
  por conveniência: **os fixados nunca são reordenados pela busca** (são a
  camada `⌥`, e `⌥2` precisa apontar para o mesmo item enquanto se digita), e a
  **subsequência não é solta sobre o conteúdo inteiro** — só sobre o apelido e a
  linha exibida. Solta, ela devolve o histórico inteiro para qualquer coisa
  digitada; o casamento literal é que continua alcançando o conteúdo todo.
- **O Pin escreve num lugar só: o gerador de CPF e CNPJ.** Ele é uma linha no
  topo da lista dentro do filtro daquele documento, e paga três exceções às
  regras daqui — as pílulas de CPF e CNPJ estão sempre na fila (senão o gerador
  nasce escondido de quem nunca copiou um), clicar nela copia em vez de abrir o
  preview (a linha não tem um "dentro"), e `selectedIndex == -1` passou a
  significar duas coisas. **É uma linha só para os dois documentos**, e uma
  conta só: o módulo 11 vive em `TaxId` (`lib/features/pin/models/tax_id.dart`),
  onde CPF e CNPJ compartilham o mesmo `_checkDigit` e discordam apenas nos
  pesos (`TaxIdKind.weightAt`) — o segundo documento não ganhou um segundo
  arquivo, pelo mesmo motivo que a conta saiu do classificador. Ver
  [docs/Ideis projeto/pin-gerador-de-cpf.md](docs/Ideis%20projeto/pin-gerador-de-cpf.md).
- Tipo de item do Pin (texto, link, e-mail, telefone, CPF, CNPJ, comando) é decidido
  na captura e gravado na linha. Mexeu no `ClipboardItemClassifier`, suba o
  `version` dele: é o que faz `reclassifyOutdated` reprocessar o histórico já
  guardado uma vez, na abertura seguinte. Sem isso, um tipo novo nasce vazio
  para quem já usa o app.
- Backup e restauração (`lib/core/storage/backup_service.dart`) **descobrem as
  tabelas pelo `sqlite_master`** — a tabela de um módulo novo entra nos dois
  sozinha, sem ninguém vir aqui. A única que fica de fora é `schema_migrations`,
  que é do banco que está rodando. O snapshot é `VACUUM INTO`, nunca cópia do
  arquivo: o banco roda em WAL com duas conexões abertas, e o arquivo no disco
  não tem o que ainda está no log. Ver
  [docs/Ideis projeto/backup-do-banco.md](docs/Ideis%20projeto/backup-do-banco.md).
- **O Evergreen guarda os dados dele para si, e não os traduz para ninguém.** O
  backup é um `.db` que só ele lê, e é o suficiente: a pergunta que ele responde
  é "e se este arquivo se perder?". Houve uma exportação em JSON ao lado, para
  outro programa abrir, e ela saiu — ninguém abriu o arquivo em programa nenhum,
  e ela cobrava o preço de um segundo formato a manter, com o histórico do Pin
  inteiro em texto puro numa pasta a mais. Um módulo novo não precisa pensar
  nela. A pasta `Backups/` fica dentro da pasta do aplicativo, onde o macOS não
  pede permissão, e o botão "Mostrar no Finder" é a interface — diálogo de
  "salvar como" exigiria um pacote novo.
- **O que a pessoa pede para levar embora é outra coisa, e tem uma saída só: o
  `ExportService`.** A regra acima é sobre o aplicativo traduzir o banco dele
  por conta própria; exportar é **um documento por vez, pedido no botão, do
  texto que está na tela** — o resumo e a transcrição de uma reunião, hoje
  (`MeetingDocument`). Nada disso é lido de volta. A pasta é `Exportações/`, ao
  lado de `Backups/` e pela mesma razão (`~/Documents` pede permissão no meio do
  clique), e por isso escrever **termina mostrando o arquivo no Finder**: a
  pasta é funda demais para alguém achá-la sozinho. O serviço é interface, como
  o `NestFileService`, pelo motivo de sempre — no relógio falso do teste de
  widget a resposta de uma escrita em disco nunca chega. Ver
  [docs/Ideis projeto/echo-copiar-e-exportar.md](docs/Ideis%20projeto/echo-copiar-e-exportar.md).
- Migrações de schema: só **adicionar** entrada com chave nova em `_migrations`
  em `lib/core/storage/app_database.dart`; nunca editar nem reaproveitar uma
  chave já publicada (a tabela `schema_migrations` rastreia quais rodaram). A
  chave vale mais que a posição porque duas branches escrevem "a próxima
  migração" ao mesmo tempo — por número elas colidem e uma some em silêncio.
- Ao adicionar pacote com código nativo macOS, verificar se ele precisa
  aparecer também no callback de sub-janela em
  `macos/Runner/MainFlutterWindow.swift` (senão quebra em janelas secundárias).
- Novo módulo: registrar em `EvergreenModule` — com `shortcutSlot` e `panel`,
  se tiver painel —, criar `lib/features/<modulo>/` na estrutura padrão e ligar
  a tela de configurações em `_settingsFor` (`hub_view.dart`). O interruptor
  mestre e o item do menu da barra vêm de graça; a seção "Atalho global" é
  `GlobalShortcutSection(slot: ...)`, nunca escrita à mão. Um módulo que apareça
  em `_startModule`/`_stopModule` do bootstrap precisa dizer o que para quando
  ele é desligado.
- **Módulo que só lê o que os outros gravaram** (hoje, o Track) não cria tabela,
  não escreve linha e não faz migração: ele é um repositório de leitura sobre as
  tabelas alheias. Consequência prática: cada módulo novo o alimenta de graça, e
  a única obrigação é a do lado dele — **nunca ler o conteúdo de um item do
  Pin**. A consulta do Track pede `copied_at` e `type`, e mais nada, porque o
  Pin registra tudo o que passa pela área de transferência, senha inclusive.
  O mesmo vale para o que segue ao modelo local: só o agregado.
- Do outro lado dessa regra: **módulo que quer aparecer no Track precisa gravar
  alguma coisa.** O Awake era o único que não aparecia — não por decisão, mas
  porque não tinha tabela. Agora grava uma linha por trava solta (`quando`,
  `quanto`, `o quê`), e só isso: o painel continua respondendo "está ligado?", e
  o histórico é do Track. A trava que ainda está de pé não vira linha, porque
  ainda não tem duração.
- O parágrafo que o modelo local escreve sobre um dia é **cache, não dado**: ele
  vive no plist (`TrackSummaryCache`), com assinatura do dia, e não no banco.
  Não entra no backup porque se refaz sozinho — e é o que
  mantém o Track sem tabela própria mesmo guardando alguma coisa.
- Módulo que usa o modelo local (`FoundationModels`, pelo canal do Echo) trata a
  resposta dele como **enfeite**: abaixo do macOS 26 ou sem Apple Intelligence o
  canal responde `unsupported_os`, e a tela precisa ficar inteira sem o texto —
  sem aviso, sem espaço reservado, sem bloquear o que já está desenhado.
- **Conteúdo longo para ler abre na região do Hub — nunca em janela nova nem em
  diálogo modal.** É o padrão do aplicativo, e vale para módulo existente ou
  novo: o módulo abre a região (`hubDetailProvider.open`), guarda no próprio
  estado *qual* item está aberto, desenha um `HubDetailRegion` e liga esse
  widget em `_region` (`hub_view.dart`); a lista que abriu marca a linha como
  selecionada. Hoje: `EchoReader` (a reunião) e `FocusReader` (a sessão do
  histórico) — o Focus era um diálogo modal até a v0.4, e o modal escurecia o
  histórico atrás, prendia o teclado e obrigava a fechar para olhar a linha
  vizinha. Modal continua sendo a forma certa de **uma pergunta de sim ou não**
  (`EgConfirmDialog`), e só disso.
- Quem faz a janela crescer para caber a região é o
  `HubWindowChannel.setDetailWidth` — dividir a largura que já existe foi
  tentado e deixa a leitura espremida. A janela cresce **em torno do próprio
  centro** e volta pelo mesmo caminho: o lado nativo guarda o que a tela não
  deixou crescer e o passo lateral que ele deu para não vazar da borda, e paga
  os dois no fechamento. Sem esse acerto, abrir e fechar deixava a janela mais
  estreita e fora do centro a cada volta.
- Preferência que não é de módulo nenhum (iniciar com o macOS, atalho do Hub,
  o nome de quem usa, a aparência) vai para `AppSettings` e para a tela do aplicativo
  (`app_settings_view.dart`), nunca para a tela de um módulo — foi assim que
  "iniciar com o macOS" acabou morando dentro do Pin até a v0.2.
- **O nome de quem usa é preferência de aplicativo, e existe para o modelo
  local.** Sem ele o resumo da reunião diz "a pessoa" e o parágrafo do Track diz
  o mesmo — texto sobre você escrito por quem não sabe seu nome. Quem quiser
  usá-lo faz duas coisas, nunca uma: põe o nome **no texto** que vai ao modelo
  (no Echo é o rótulo de quem falou, `Speaker.labelFor`) e **na instrução**,
  dizendo que aquele nome é de quem pediu — o rótulo sozinho faz o modelo achar
  que é mais um participante. **E a instrução cerca o nome, nunca o solta**: ele
  só leva o que está nas falas marcadas com ele, e não é apresentado quando a
  pessoa não falou — o único nome de um texto vira o dono de todas as falas, e
  um vídeo assistido em silêncio saiu resumido como "Lucas afirma…". O resto é
  escrito sobre o assunto, não sobre quem disse (`LocalEchoSummaryRunner.rulesFor`).
  Vazio é o estado normal e nada pode depender dele.
  Módulo que roda no engine da janela 0 relê o disco antes
  (`AppSettingsRepository.reload`): o nome é escrito no Hub, que é outro engine.
- A pergunta do nome aparece **uma vez por instalação**, quando a abertura
  animada termina: o Hub cai na tela do aplicativo, com a pergunta no topo e o
  cursor dentro. Amarrada ao fim da cena, e não à abertura da janela, porque a
  cena já roda uma vez por build — pergunta que reabre a cada Hub vira cobrança.
  Depois disso o campo continua lá, como primeira linha de "Geral".
- Módulo com painel flutuante: **não crie uma janela nova** — acrescente um
  valor a `OverlayPanel`, desenhe o painel em `OverlayHost` e registre o atalho
  global no `EvergreenBootstrap`. Só a janela 0 pode ser borderless/sempre no
  topo (motivo em `docs/Ideis projeto/`).
- A janela 0 é um `NSPanel` **não-ativante**: ela recebe o teclado sem tirar da
  frente o app em que a pessoa estava. Quem a exibe é o `OverlayWindowChannel`,
  nunca `windowManager.show()` — o `show()` do pacote chama
  `NSApp.activate(ignoringOtherApps: true)`, e é essa chamada, não o estilo da
  janela, que faz o app anterior piscar. Pelo mesmo motivo o nível e o
  `collectionBehavior` moram no `MainFlutterWindow`: `setAlwaysOnTop` os
  rebaixaria para `.floating`, abaixo de um app em tela cheia.
- O preço do painel que não ativa o app: a janela 0 só presencia as
  modificadoras que sobem e descem **enquanto ela é a key window**, e o atalho
  global acontece antes disso. Como `SingleActivator` decide pelo estado
  acumulado (`HardwareKeyboard.logicalKeysPressed`), e não pelas modificadoras
  do evento que chegou, todo atalho com `⌘` ou `⌥` falharia calado no painel
  recém-aberto — só o Esc, que não exige modificadora, continuaria de pé. Por
  isso o `OverlayWindowChannel` posta um `flagsChanged` sintético a cada
  `didBecomeKey` (`resyncModifiers`): é ele que realinha o registro do Flutter
  com o teclado físico. Não há como fazer isso do lado Dart —
  `HardwareKeyboard.syncKeyboardState` só acrescenta teclas e `clearState` é de
  teste, e leva os handlers do teclado junto.
- Sub-janela (hoje só o Hub) nasce escondida e **se exibe sozinha** depois do
  primeiro quadro, em `main.dart` — quem pediu a janela roda em outro engine e
  não tem como saber quando este subiu. Exibi-la de fora mostrava uma janela em
  branco que já levava o foco do teclado junto, e parecia app travado.
- Geometria de sub-janela é nativa (`HubWindowChannel`, em
  `MainFlutterWindow.swift`): ela abre centralizada na tela onde está o cursor,
  como o painel flutuante. `NSWindow.center()` centraliza na tela em que a
  janela já está — e uma sub-janela nasce na origem do sistema de coordenadas,
  o que com dois monitores jogava o Hub para o monitor errado.
- Esconder a janela flutuante **não** descarta o que estava desenhado nela: o
  macOS reexibe a última superfície antes de o Flutter desenhar o painel novo.
  Por isso `OverlayWindow.hide` apaga o painel (`Opacity(0)` no `OverlayHost`) e
  espera um quadro antes de esconder — sem isso, abrir o Focus logo depois de
  fechar o Pin mostra o Pin por um quadro.
- Serviços que precisam sobreviver com todas as janelas fechadas (captura de
  clipboard, cronômetro do Focus, trava do Awake) vivem no engine da janela 0 e
  são ligados no `EvergreenBootstrap`.
- **Trabalho demorado pedido de dentro do Hub também mora na janela 0.** Fechar
  o Hub destrói a sub-janela e o engine dela, e com ele tudo o que estava
  pendente — não há aviso, não há erro, o trabalho simplesmente não termina. Foi
  o que acontecia com o resumo do Echo: pedir "Resumir" e sair da janela
  cancelava o resumo no meio, e a reunião reaparecia sem ele. O arranjo é
  `EchoSummaryRunner`: quem faz é o `LocalEchoSummaryRunner` da janela 0, quem
  pede é o `WindowEchoSummaryRunner` do Hub, e o `echoSummaryRunnerProvider`
  escolhe um ou outro pelo `windowKindProvider` — o chamador não sabe a
  diferença. O Hub pergunta o andamento de meio em meio segundo enquanto há
  trabalho (`EchoSummaryStatus`), o que também é o que faz uma janela reaberta
  reencontrar um resumo em curso. Canal unidirecional, registrado uma única vez
  na janela 0: nos dois sentidos, um Hub reaberto rápido demais poderia
  encontrar o registro do engine morto ainda ocupado.
- Arquivo Swift novo em `macos/Runner/` **não entra sozinho na build**: o
  `project.pbxproj` é da era anterior aos grupos sincronizados, então cada
  arquivo precisa de quatro entradas (`PBXBuildFile`, `PBXFileReference`, filho
  do grupo `Runner` e a fase `Sources`). Sem as quatro, ele compila no editor e
  some no build.
- **Módulo que mexe em arquivo põe a conversa com o disco atrás de uma
  interface** (`NestFileService`), não de uma classe concreta. Não é cerimônia:
  teste de widget roda no relógio falso do binding, e nele a resposta de uma
  leitura de disco **nunca chega** — o teste do painel trava esperando o tamanho
  do primeiro arquivo, sem erro e sem mensagem. A tela é verificada contra uma
  imitação em memória; o disco de verdade é assunto do teste da implementação,
  que roda fora do binding. A mesma armadilha alcança o golden de conferência, e
  lá a saída é `tester.runAsync`.
- Preferir sempre a solução em Flutter puro a código nativo (Swift/AppKit);
  quando uma alternativa nativa for descartada, documentar em `docs/`.

# Language / Idioma

UI e microcopy em português (pt-BR).

# Commands

- `flutter run -d macos` — rodar em desenvolvimento
- `flutter analyze` — checar lint
- `flutter test` — rodar testes (unidade e widget)
- `flutter test --run-skipped -t preview --update-goldens` — regerar goldens
  de conferência visual (fora da suíte padrão, dependem de fontes do sistema)
- `flutter test --run-skipped -t assets test/tools/brand_assets_test.dart` —
  reexportar o ícone do aplicativo e o da barra de menus a partir da marca em
  Dart. Fora da suíte padrão porque **escreve** no repositório.
- `./run_build_copy` — build release e instala em `/Applications`, reassinando
  com identidade estável. A assinatura ad-hoc do projeto muda de hash a cada
  build, e com ela o macOS descarta a permissão de Acessibilidade — que é o que
  sustenta o auto-colar do Pin.
- `./bump_version` — bump manual da versão, para quando o Actions está fora do
  ar. Roda na `validation`, **depois** do merge; normalmente quem bumpa é o
  `.github/workflows/version-bump.yml`, pela label `bump:` da PR.

# Branches

O caminho é o do LuizLaporta e do Portal_LL: **a feature entra na `validation`,
a `validation` é promovida para a `main`.** Cada PR passa por um portão só, e
os dois portões perguntam coisas diferentes.

- **Feature → `validation`.** É onde a label `bump:patch|minor|major` é exigida
  (`require-bump-label.yml`) e, no merge, onde a versão sobe e a tag é criada
  (`version-bump.yml`). A suíte **não** roda aqui.
- **`validation` → `main`.** É a PR de promoção, e é ela que roda `flutter
  analyze` e `flutter test` (`ci.yml`) — a integração é onde se confere o
  conjunto, e um runner de macOS custa dez vezes um de Linux por minuto. Não
  pede label: ela carrega um número que já foi decidido, e bumpar dos dois
  lados daria dois números para o mesmo código.

A consequência a saber: **entre a feature e a promoção, o que segura a barra é
rodar `flutter analyze` e `flutter test` na máquina** antes de abrir a PR. O CI
só vai falar na promoção, e lá ele fala sobre o conjunto — não sobre qual PR
quebrou.

# Project context

Evergreen é uma suíte pessoal de produtividade para macOS, feita como agente de
barra de menus (`LSUIElement`) — sem janela ao iniciar, sem ícone no Dock. Tudo
roda localmente, nada é enviado para a internet. São seis módulos: Pin
(gerenciador de área de transferência, `⌘⇧C`), Focus (cronômetro de foco com
registro de atividade, `⌘⇧F`), Leaf (parede de até nove anotações curtas,
`⌘⇧D`), Awake (mantém a tela acesa por um prazo, `⌘⇧X`), Echo (grava,
transcreve e resume reuniões, `⌘⇧E`) e Track (reconstrói o dia a partir do que
os outros gravaram — só tela do Hub, sem atalho global e sem painel).

Domain: produtividade pessoal / utilitário de sistema para macOS.

# Stack

- **Flutter** (Dart SDK ^3.11.5) — app desktop nativo, sem backend.
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
  responde `unsupported_os` abaixo disso, e o resto do app segue no 10.15.
- **`shared_preferences`, `path_provider`, `intl`, `package_info_plus`** —
  persistência simples, paths do sistema, formatação de data/hora e a versão
  que o rodapé da sidebar do Hub mostra (`lib/core/app_info.dart`).

# Project conventions

- MVVM com Riverpod. Regra de ouro: **nenhuma lógica de negócio em widget** —
  fica em ViewModels (`Notifier`).
- Estrutura por feature em `lib/features/<modulo>/{data,models,presentation}`;
  `presentation` se divide em `viewmodels/`, `views/`, `widgets/`.
- Tokens de design (cor, tipografia, métricas) em `lib/core/design/` são a
  **única** fonte — nenhum `Color(0x...)` fora de `app_colors.dart`, nenhum
  tamanho de fonte, ícone, espaçamento ou opacidade escrito à mão num widget.
  `copyWith` em estilo de texto vale só para cor; peso e tamanho são degraus da
  escala, e degrau que falta entra em `app_typography.dart` com nome.
- Componentes compartilhados usam prefixo `Eg` em `lib/shared/widgets/`.
  Ícones são paths customizados (`EgIcon`), não Material Icons.
- Estado de elemento interativo (hover, pressed, foco, selecionado, desabilitado)
  vem da matriz `EgSurfaceStyle` (`eg_surface.dart`), via `EgInteractiveSurface`
  ou `EgSurface` — nunca de uma cadeia de `if`s dentro do widget. Selecionado é
  fundo accent a 14% **mais** a aresta de 3px à esquerda (`selectedEdge`), a
  mesma em linha de lista, item de sidebar e cartão do Leaf. Um componente
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
  `WindowListener`, anima a entrada, decide o que é um blur de verdade e trata o
  vazio ao redor como barreira. O módulo só diz o que "fechar" significa para
  ele. Dois comportamentos são opt-in e hoje só o Echo pede os dois:
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
- Tipo de item do Pin (texto, link, e-mail, telefone, CPF, comando) é decidido
  na captura e gravado na linha. Mexeu no `ClipboardItemClassifier`, suba o
  `version` dele: é o que faz `reclassifyOutdated` reprocessar o histórico já
  guardado uma vez, na abertura seguinte. Sem isso, um tipo novo nasce vazio
  para quem já usa o app.
- Backup, restauração (`lib/core/storage/backup_service.dart`) e exportação
  (`export_service.dart`) **descobrem as tabelas pelo `sqlite_master`** — a
  tabela de um módulo novo entra nos três sozinha, sem ninguém vir aqui. A única
  que fica de fora é `schema_migrations`, que é do banco que está rodando. O snapshot é
  `VACUUM INTO`, nunca cópia do arquivo: o banco roda em WAL com duas conexões
  abertas, e o arquivo no disco não tem o que ainda está no log. Ver
  [docs/Ideis projeto/backup-do-banco.md](docs/Ideis%20projeto/backup-do-banco.md).
- Backup e exportação respondem a perguntas diferentes e por isso são dois: o
  `.db` é para o Evergreen ler de volta (e sai por `VACUUM INTO`), o `.json` é
  para outro programa abrir. Pastas separadas (`Backups/` e `Exports/`) dentro
  da pasta do aplicativo — ali o macOS não pede permissão, e o botão "Mostrar no
  Finder" é a interface. Diálogo de "salvar como" exigiria um pacote novo.
- Migrações de schema: só **adicionar** entrada com chave nova em `_migrations`
  em `lib/core/storage/app_database.dart`; nunca editar nem reaproveitar uma
  chave já publicada (a tabela `schema_migrations` rastreia quais rodaram). A
  chave vale mais que a posição porque duas branches escrevem "a próxima
  migração" ao mesmo tempo — por número elas colidem e uma some em silêncio.
- Ao adicionar pacote com código nativo macOS, verificar se ele precisa
  aparecer também no callback de sub-janela em
  `macos/Runner/MainFlutterWindow.swift` (senão quebra em janelas secundárias).
- Novo módulo: registrar em `EvergreenModule`, criar
  `lib/features/<modulo>/` na estrutura padrão, ligar tela de configurações em
  `_settingsFor` (`hub_view.dart`).
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
  Não entra no backup nem na exportação porque se refaz sozinho — e é o que
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
- Preferência que não é de módulo nenhum (iniciar com o macOS, atalho do Hub)
  vai para `AppSettings` e para a tela do aplicativo (`app_settings_view.dart`),
  nunca para a tela de um módulo — foi assim que "iniciar com o macOS" acabou
  morando dentro do Pin até a v0.2.
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
- Arquivo Swift novo em `macos/Runner/` **não entra sozinho na build**: o
  `project.pbxproj` é da era anterior aos grupos sincronizados, então cada
  arquivo precisa de quatro entradas (`PBXBuildFile`, `PBXFileReference`, filho
  do grupo `Runner` e a fase `Sources`). Sem as quatro, ele compila no editor e
  some no build.
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
- `./run_build_copy` — build release e instala em `/Applications`, reassinando
  com identidade estável. A assinatura ad-hoc do projeto muda de hash a cada
  build, e com ela o macOS descarta a permissão de Acessibilidade — que é o que
  sustenta o auto-colar do Pin.
- `./bump_version` — bump manual da versão, para quando o Actions está fora do
  ar. Roda na `main`, **depois** do merge; normalmente quem bumpa é o
  `.github/workflows/version-bump.yml`, pela label `bump:` da PR.

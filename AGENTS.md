# Project context

Evergreen é uma suíte pessoal de produtividade para macOS, feita como agente de
barra de menus (`LSUIElement`) — sem janela ao iniciar, sem ícone no Dock. Tudo
roda localmente, nada é enviado para a internet. São seis módulos: Pin
(gerenciador de área de transferência, `⌘⇧C`), Focus (cronômetro de foco com
registro de atividade, `⌘⇧F`), Leaf (parede de até nove anotações curtas,
`⌘⇧D`), Awake (mantém a tela acesa por um prazo, `⌘⇧X`), Echo (grava,
transcreve e resume reuniões, `⌘⇧E`) e Trail (reconstrói o dia a partir do que
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
- **`wakelock_plus`** — a trava do Awake. No macOS ele registra um
  `IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep)`, a mesma
  assertion do Caffeine/Amphetamine — por isso o módulo não tem canal nativo
  próprio: o Swift equivalente já vive dentro do pacote.
- **`ScreenCaptureKit` + `Speech` + `FoundationModels`** (nativo, macOS 26) — o
  Echo. Captura de áudio em duas faixas, transcrição e resumo local, sem
  equivalente em Flutter puro; o porquê de cada um está em
  [docs/Ideis projeto/echo-transcricao.md](docs/Ideis%20projeto/echo-transcricao.md).
  Exige macOS 26 e é o único módulo com piso de sistema próprio — o canal
  responde `unsupportedOS` abaixo disso, e o resto do app segue no 10.15.
- **`shared_preferences`, `path_provider`, `intl`** — persistência simples,
  paths do sistema, formatação de data/hora.

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
- Painel flutuante novo usa `EgOverlayShell`: ela é quem registra o
  `WindowListener`, anima a entrada, decide o que é um blur de verdade e trata o
  vazio ao redor como barreira. O módulo só diz o que "fechar" significa para
  ele.
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
  nunca colide com o commit do foco perdido.
- Acesso a dados sempre atrás de repositório (ex.: `ClipboardRepository`) —
  nunca acoplar UI/ViewModel diretamente ao SQLite.
- Tipo de item do Pin (texto, link, e-mail, telefone, CPF, comando) é decidido
  na captura e gravado na linha. Mexeu no `ClipboardItemClassifier`, suba o
  `version` dele: é o que faz `reclassifyOutdated` reprocessar o histórico já
  guardado uma vez, na abertura seguinte. Sem isso, um tipo novo nasce vazio
  para quem já usa o app.
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
- **Módulo que só lê o que os outros gravaram** (hoje, o Trail) não cria tabela,
  não escreve linha e não faz migração: ele é um repositório de leitura sobre as
  tabelas alheias. Consequência prática: cada módulo novo o alimenta de graça, e
  a única obrigação é a do lado dele — **nunca ler o conteúdo de um item do
  Pin**. A consulta do Trail pede `copied_at` e `type`, e mais nada, porque o
  Pin registra tudo o que passa pela área de transferência, senha inclusive.
  O mesmo vale para o que segue ao modelo local: só o agregado.
- Módulo que usa o modelo local (`FoundationModels`, pelo canal do Echo) trata a
  resposta dele como **enfeite**: abaixo do macOS 26 ou sem Apple Intelligence o
  canal responde `unsupportedOS`, e a tela precisa ficar inteira sem o texto —
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

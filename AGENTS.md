# Project context

Evergreen é uma suíte pessoal de produtividade para macOS, feita como agente de
barra de menus (`LSUIElement`) — sem janela ao iniciar, sem ícone no Dock. Tudo
roda localmente, nada é enviado para a internet. São cinco módulos: Pin
(gerenciador de área de transferência, `⌘⇧C`), Focus (cronômetro de foco com
registro de atividade, `⌘⇧F`), Leaf (parede de até nove anotações curtas,
`⌘⇧D`), Awake (mantém a tela acesa por um prazo, `⌘⇧X`) e Echo (grava,
transcreve e resume reuniões, `⌘⇧E`).

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
  **única** fonte — nenhum `Color(0x...)` fora de `app_colors.dart`.
- Componentes compartilhados usam prefixo `Eg` em `lib/shared/widgets/`.
  Ícones são paths customizados (`EgIcon`), não Material Icons.
- Acesso a dados sempre atrás de repositório (ex.: `ClipboardRepository`) —
  nunca acoplar UI/ViewModel diretamente ao SQLite.
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

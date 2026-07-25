# Project context

Evergreen é uma suíte pessoal de produtividade para macOS, feita como agente de
barra de menus (`LSUIElement`) — sem janela ao iniciar, sem ícone no Dock. Tudo
roda localmente, nada é enviado para a internet. A v0.2 tem dois módulos: Pin
(gerenciador de área de transferência, `⌘⇧C`) e Focus (cronômetro de foco com
registro de atividade, `⌘⇧X`); Shelf existe como placeholder em
`EvergreenModule`.

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
  compartilhada por Pin e Focus — ver
  [docs/Ideis projeto/focus-janela-compartilhada.md](docs/Ideis%20projeto/focus-janela-compartilhada.md).
- **`window_manager`, `tray_manager`, `hotkey_manager`, `screen_retriever`** —
  janela flutuante, ícone da barra de menus, atalho global.
- **`launch_at_startup`** — "iniciar com o macOS", via canal nativo próprio
  (`SMAppService`), não o pacote nativo sugerido pela lib.
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
- Migrações de schema: só **adicionar** string nova em `_migrations` em
  `lib/core/storage/app_database.dart`; nunca editar uma já publicada
  (`PRAGMA user_version` rastreia o que já rodou).
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
- Serviços que precisam sobreviver com todas as janelas fechadas (captura de
  clipboard, cronômetro do Focus) vivem no engine da janela 0 e são ligados no
  `EvergreenBootstrap`.
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

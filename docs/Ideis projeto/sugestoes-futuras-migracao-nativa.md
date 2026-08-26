# Sugestões futuras — migrar a camada de janelas para nativo (Swift/AppKit)

> Status: **proposta**, não agendada. A v0.1 foi entregue em Flutter puro.
> Registrado em 23/07/2026, durante a implementação do Pin.

---

## Por que este documento existe

Na v0.1 a decisão foi implementar as janelas **só com pacotes Flutter**
(`window_manager`, `tray_manager`, `hotkey_manager`, `desktop_multi_window`),
priorizando velocidade de entrega e um código 100% Dart.

Essa escolha funciona, mas tem um teto. Este documento registra **onde ela
encosta nesse teto** e **o que a migração para AppKit resolveria**, para que a
decisão possa ser retomada quando o Evergreen amadurecer.

---

## Como está hoje

O Evergreen roda **dois engines Flutter**, um por janela:

| Janela | Papel | Como é criada |
|---|---|---|
| Janela 0 | Overlay do Pin (painel flutuante) | Runner do macOS, estilizada via `window_manager` |
| Sub-janela | Hub (painel principal / configurações) | `desktop_multi_window` |

O overlay ficou na janela 0 **de propósito**: `window_manager` só consegue
estilizar a janela principal do app. Sub-janelas criadas pelo
`desktop_multi_window` são `NSWindow` comuns (800x600, com barra de título) e
não expõem controle de tamanho, posição ou nível a partir do Dart.

Como o Hub é um painel de configurações, o chrome nativo do macOS ali é
apropriado — então o arranjo atual não sacrifica nada. O que sacrifica é o
overlay.

A janela 0 nunca é destruída, só escondida. É por isso que a captura da área de
transferência, o atalho global e o ícone da barra de menus continuam vivos com
todas as janelas fechadas.

---

## Limitações da abordagem atual

### 1. O overlay rouba o foco do app anterior

> **Resolvido em 25/08/2026.** Ver "Alternativa intermediária", no fim deste
> documento — foi ela que acabou sendo feita.

Um painel estilo Spotlight de verdade é um `NSPanel` com
`styleMask: .nonactivatingPanel`: ele recebe teclado **sem** desativar o
aplicativo que estava em foco. O `window_manager` cria uma `NSWindow` comum e
chama `NSApp.activate(ignoringOtherApps: true)`.

Consequência prática: ao abrir e fechar o Pin, o app anterior pisca — perde e
retoma o foco. Some com o efeito de "camada flutuante sobre o sistema".

### 2. Sem controle fino de nível e de Spaces

> **Resolvido em 25/08/2026**, junto com o item 1. O nível saiu do lado Dart e
> passou a ser `.statusBar`, escolhido no `MainFlutterWindow`.

`setAlwaysOnTop` mapeia para um nível fixo (`.floating`). Um `NSPanel` permitiria
escolher `.statusBar` ou `.popUpMenu`, garantindo que o overlay fique acima
inclusive de apps em tela cheia e de outros utilitários.

O `collectionBehavior`, ao contrário do que este item dava a entender, nunca foi
o problema: `canJoinAllSpaces` e `fullScreenAuxiliary` já vinham do
`setVisibleOnAllWorkspaces` desde a v0.1.

### 3. Polling da área de transferência

Hoje um `Timer` em Dart lê o pasteboard a cada 600ms
(`lib/features/pin/data/clipboard_watcher.dart`). Em Swift, dá para observar
`NSPasteboard.general.changeCount`, que é uma leitura de inteiro — mais barato e
sem janela de 600ms em que uma cópia pode ser perdida se o usuário copiar duas
coisas em sequência muito rápida.

### 4. Dropdown da barra de menus é um `NSMenu` padrão

O `tray_manager` monta um `NSMenu` do sistema. O design prevê um dropdown com a
identidade do Evergreen (fundo `#141414`, raio 12, "Encerrar" em vermelho). Com
AppKit, o `NSStatusItem` poderia abrir um `NSPopover` com conteúdo Flutter.

### 5. Dois engines não compartilham memória

Hub e overlay são isolates distintos. Hoje isso não pesa (o banco SQLite em modo
WAL é a fonte da verdade e cada engine lê o que precisa), mas quando os módulos
crescerem — e o Hub precisar refletir estado ao vivo do Focus, por exemplo — vai
exigir uma ponte de mensagens explícita.

### 6. `desktop_multi_window` é um ponto único de risco

Pacote de terceiros, pouco movimentado, no caminho crítico de uma janela do
produto.

### 7. A geometria da janela do Hub só existe em Swift

> Decisão tomada em 24/07/2026, na revisão de design do v0.1.

O `desktop_multi_window` 0.3.0 cria **toda** sub-janela com `NSRect(x: 0, y: 0,
width: 800, height: 600)` fixos: sem tamanho mínimo e ancorada no canto inferior
esquerdo da tela. Não há como mudar isso pelo Dart —

- `WindowConfiguration` aceita só `arguments` e `hiddenAtLaunch`;
- `WindowController` expõe só `show()`, `hide()` e `invokeMethod`;
- `window_manager` age sobre a janela principal do app, que aqui é o overlay do
  Pin, não o Hub.

Por isso o Hub recebe `minSize` (720x480), tamanho inicial (880x620) e
`center()` dentro de `applyHubGeometry`, chamada no
`setOnWindowCreatedCallback` em `MainFlutterWindow.swift` — o mesmo callback que
já registrava os canais nativos. São três linhas de AppKit, e a alternativa em
Flutter puro seria aceitar uma janela de configurações de 800x600 nascendo no
canto da tela.

**Limite conhecido:** o callback não recebe os `arguments` da janela, então a
geometria vale para qualquer sub-janela. Hoje só existe uma (o Hub). Quando
aparecer a segunda, o tamanho precisará vir do Dart por canal — ou, melhor, a
essa altura a migração deste documento já resolve o problema na origem.

---

## O que a migração envolveria

Substituir os quatro pacotes por código no `macos/Runner`:

```
macos/Runner/
  AppDelegate.swift          NSStatusItem + NSPopover + ciclo de vida
  PinPanelController.swift   NSPanel .nonactivating, .floating,
                             canJoinAllSpaces, borderless
  HubWindowController.swift  NSWindow comum com FlutterViewController próprio
  GlobalHotKey.swift         Carbon RegisterEventHotKey
  PasteboardWatcher.swift    observação de changeCount
  EvergreenBridge.swift      MethodChannel entre os engines
```

Dois engines continuam existindo, criados manualmente:

```swift
let engine = FlutterEngine(name: "pin-overlay", project: nil)
engine.run(withEntrypoint: "main")
GeneratedPluginRegistrant.register(with: engine)
```

### O que **não** muda

Nada da camada Dart de produto. O design system (`lib/core/design/`), os widgets
(`lib/shared/`), as ViewModels e as views seguem intactos.

O isolamento já está preparado para isso: toda a conversa com o sistema passa por
`lib/core/window/` e `lib/core/system/`. Migrar significa reescrever o corpo
dessas classes mantendo as assinaturas:

- `PinOverlayWindow.configure() / show() / hide() / toggle()`
- `HubWindow.open()`
- `GlobalShortcutService.registerPinToggle()`
- `MenuBarService.initialize()`
- `ClipboardWatcher.onCopy`

---

## Quando vale a pena

Não agora. Sinais de que chegou a hora:

- O pisca-pisca de foco ao abrir o Pin incomodar no uso diário.
- Um módulo precisar de janela com comportamento que os pacotes não dão
  (o Shelf, por exemplo, vai precisar de drag & drop de arquivos com janela
  sempre visível).
- `desktop_multi_window` quebrar em alguma atualização do Flutter.
- Chegar a hora de assinar e notarizar o app para distribuição.

## Custo estimado

Moderado. O grosso é `PinPanelController` e a criação manual dos engines; o resto
é mecânico. Nada disso toca a UI.

---

## Alternativa intermediária — feita em 25/08/2026

Era o caminho recomendado como primeiro passo, e foi o que se fez quando o
incômodo apareceu: com três módulos dividindo a janela 0, o Focus passou a abrir
e fechar várias vezes por sessão, e cada visita era uma piscada no app em que a
pessoa estava tentando focar.

Os quatro pacotes ficaram no lugar. O que mudou:

- `MainFlutterWindow` herda de `NSPanel` em vez de `NSWindow`, e ganha
  `.nonactivatingPanel`, `level = .statusBar`, `hidesOnDeactivate = false` e
  `becomesKeyOnlyIfNeeded = false`.
- `OverlayWindowChannel` (canal `overlay_window`) exibe a janela com
  `orderFrontRegardless` + `makeKey`, e `OverlayWindow.show` passou a usá-lo.
- `setAlwaysOnTop` e `setVisibleOnAllWorkspaces` saíram do lado Dart: o primeiro
  *rebaixaria* a janela para `.floating`.

### Três coisas que a proposta original errava

**Não é "um arquivo Swift aplicado depois do lançamento".** `.nonactivatingPanel`
só é honrado por `NSPanel`, e não se troca a classe de uma instância já criada —
a herança precisa mudar antes, na classe que o nib instancia.

**O `styleMask` sozinho não tira o pisca.** Ele decide o que acontece quando
alguém *clica* no painel; o `show()` do `window_manager` chama
`NSApp.activate(ignoringOtherApps: true)` de qualquer forma. Sem trocar quem
exibe a janela, a conversão para painel não muda nada do que se vê.

**O `MainMenu.xib` continua com `<window>`.** O documento está no formato do
Xcode 8 e o `ibtool` recusa um elemento `<panel>` nele. Não faz diferença: quem
o nib instancia é o `customClass`.

### O que sobrou para depois

O `PreviousAppFocusChannel` continua inteiro. Com o painel não-ativante o foco
não chega a sair do app anterior, então `capture`/`restore` viraram quase
sempre um par de chamadas sem efeito — mas `restoreAndPaste` (o auto-colar) e a
permissão de Acessibilidade seguem dependendo dele, e o custo de mantê-lo é uma
foto do frontmost por abertura. Vale medir antes de mexer.

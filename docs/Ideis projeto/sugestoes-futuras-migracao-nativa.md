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

Um painel estilo Spotlight de verdade é um `NSPanel` com
`styleMask: .nonactivatingPanel`: ele recebe teclado **sem** desativar o
aplicativo que estava em foco. O `window_manager` cria uma `NSWindow` comum e
chama `NSApp.activate(ignoringOtherApps: true)`.

Consequência prática: ao abrir e fechar o Pin, o app anterior pisca — perde e
retoma o foco. Some com o efeito de "camada flutuante sobre o sistema".

### 2. Sem controle fino de nível e de Spaces

`setAlwaysOnTop` mapeia para um nível fixo. Um `NSPanel` permitiria escolher
`.statusBar` ou `.popUpMenu`, garantindo que o overlay fique acima inclusive de
apps em tela cheia e de outros utilitários.

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

## Alternativa intermediária

Dá para pegar o maior ganho (item 1 e 2 acima) sem migrar tudo: manter os
pacotes e adicionar **um** arquivo Swift que converte a janela 0 em `NSPanel`
não-ativante logo após o lançamento. Isso resolve o roubo de foco e o nível da
janela, mantendo `tray_manager`, `hotkey_manager` e `desktop_multi_window` no
lugar.

É o caminho recomendado como primeiro passo, se o incômodo aparecer antes da
vontade de reescrever.

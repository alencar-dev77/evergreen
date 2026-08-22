# Sugestão futura — Snap, o módulo de captura de tela

> Status: **proposta**, não agendada. Nenhum código foi escrito.
> Registrado em 22/08/2026, a partir de uma conversa sobre features novas.

---

## O que foi pedido

Um módulo de captura de tela juntando o comportamento do próprio macOS (`⌘⇧5`)
com o do CleanShot X: atalho global abre um HUD na parte de baixo da tela com as
opções de captura, e o HUD some no momento de capturar. Três capacidades:

- **Print** — área, janela ou tela inteira.
- **Gravação de tela** — vídeo e GIF.
- **Captura em rolagem** — a página inteira costurada numa imagem só (citada
  como uma das mais importantes).

Mais um **editor** para anotar em cima: seta, retângulo, texto, borrão.

---

## Por que faz sentido

O CleanShot X já está escrito como referência no `ideia.md` desde o começo do
projeto, e a tese do Evergreen — substituir vários apps pequenos por um só —
se aplica aqui melhor que em qualquer outro módulo: hoje isso é um app pago à
parte.

E o módulo não começa do zero. O Echo já roda `SCStream` e `SCShareableContent`
(`macos/Runner/EchoChannel.swift`), o que significa que o ScreenCaptureKit já
está linkado, o padrão de canal nativo grande já existe no projeto e **a
permissão de Gravação de Tela já foi concedida pelo usuário**.

---

## A descoberta que encolhe o módulo

Três itens da lista "Futuro" do `ideia.md` — **Vision, OCR e Color Picker** —
não são módulos separados. São features deste.

Os três precisam exatamente da mesma peça: uma overlay que deixa escolher uma
região da tela. Depois que ela existe, OCR é uma chamada de
`VNRecognizeTextRequest` e o color picker é ler um pixel com uma lupa em cima.

Isso muda o cálculo. O Snap deixa de ser "o maior módulo do app" e passa a ser
"o módulo que resolve quatro itens do backlog de uma vez".

---

## Onde ele bate na arquitetura

### 1. A convenção "não crie uma janela nova" não cobre este caso

O `AGENTS.md` diz que módulo com painel flutuante acrescenta um valor a
`OverlayPanel` e desenha dentro da janela 0. **Aqui não dá.** A seleção de área
precisa de *uma janela borderless por monitor*, em nível acima da barra de
menus e do Dock (`.screenSaver` ou `.popUpMenu`). A janela 0 é uma só, e o
`window_manager` só estiliza ela — o teto já registrado em
`sugestoes-futuras-migracao-nativa.md`.

Este é o módulo que força aquela migração, ou pelo menos um pedaço dela.

### 2. Overlay de seleção em Flutter é caro

Rastrear o mouse a 60fps com um engine Flutter por monitor significa dois ou
três engines vivos só para desenhar um retângulo. As implementações nativas de
referência usam `NSView` puro exatamente por isso. Aqui vale abrir exceção à
regra do "Flutter puro" — como já foi aberta no Echo.

Se ainda assim se quiser tentar em Dart antes: o pacote `macos_window_utils`
expõe `setLevel` e transparência total da `NSWindow`, e é o único caminho
puro-Flutter que chega perto.

### 3. Piso de sistema próprio

`SCStream` é macOS 12.3+; `SCScreenshotManager` (o jeito limpo de tirar o still)
é 14+. O módulo teria piso próprio, como o Echo já tem o dele em 26.

---

## A linha que separa Swift de Flutter

> **Swift faz o que só ele faz** — overlay acima de tudo, capturar pixels,
> costurar a rolagem, gravar. **Flutter faz o que dá identidade** — o editor de
> anotação, o histórico, as preferências.

O editor cai bem numa convenção que já existe: **abre na região do Hub**
(`HubDetailRegion`, como o `EchoReader` e o `FocusReader`), com o histórico de
capturas na lista ao lado. Resolve "onde mora o editor" sem inventar janela nova
nem modal, e é o que separa o Evergreen de um clone — a camada de captura é
commodity, o editor é onde o design do app aparece.

---

## Como a captura em rolagem funciona

A técnica é sempre a mesma: o usuário rola no ritmo dele, o app captura frames
com throttle, converte para cinza, pega uma faixa do topo do frame novo como
template e procura ela no frame anterior — o deslocamento em Y que der o melhor
casamento é quanto costurar. As implementações usam SAD (soma das diferenças
absolutas) ou template matching sobre as primeiras ~50 linhas.

**O que quebra na prática não é o algoritmo, é cabeçalho fixo.** Um header que
não rola casa em todos os frames e vira uma faixa repetida na imagem final. É
onde as implementações boas jogam o Vision no meio. Saber disso antes de começar
é o que separa "funciona no meu teste" de "funciona no Slack e no Safari".

---

## Open source pesquisado

Ranqueado por utilidade prática — que aqui é quase toda licença:

| Projeto | Licença | Serve para |
|---|---|---|
| [ScrollSnap](https://github.com/Brkgng/ScrollSnap) | **MIT** | Só a rolagem. Overlay + `StitchingManager` com detecção de sobreposição. O mais fácil de portar direto. |
| [ScreenCap](https://github.com/8tp/ScreenCap) | **MIT** | O escopo mais próximo (anotação, OCR, rolagem, GIF, color picker) com licença que permite copiar. macOS 14+. |
| [macshot](https://github.com/sw33tLie/macshot) | GPLv3 | **Referência de leitura, não de cópia.** O `CLAUDE.md` do repositório descreve a arquitetura inteira: uma janela borderless por tela, `ScrollCaptureController` com casamento SAD, `RecordingEngine` em `SCStream` + `AVAssetWriter`, `GIFEncoder`. macOS 12.3+. |
| [Capso](https://github.com/lzhgus/Capso) | BSL 1.1 | Tecnicamente o mais plugável — 12 pacotes SPM feitos para embutir. **Mas a BSL proíbe justamente produto concorrente de captura de tela.** Descartado por licença. |

Kap (Electron) e Flameshot (Qt) foram descartados: nenhum dos dois entra num app
Flutter nativo.

---

## Escopo em fases

**Fase 1 — Snap.** Área / janela / tela cheia, HUD inferior no estilo `⌘⇧5`,
miniatura flutuante depois da captura, histórico no Hub, copiar e salvar. Editor
com o mínimo que se usa de verdade: seta, retângulo, texto, borrão e passo
numerado. Já cobre o uso diário.

**Fase 2 — captura em rolagem.** Portar o ScrollSnap (MIT) e resolver o
cabeçalho fixo.

**Fase 3 — gravação (MP4/GIF).** A mais cara e a menos usada. O motor de
gravação é praticamente um módulo sozinho: realce de clique, edição de vídeo,
encoder de GIF.

---

## Nome e atalho

**Snap** cai no padrão dos outros (Pin, Focus, Leaf, Awake, Echo). O atalho
natural seria `⌘⇧S`, mas como hotkey global ele sequestra o "Salvar como" de
todo app aberto — olhar `⌘⇧A` ou `⌘⇧2` antes.

---

## Riscos

- É o maior módulo do app mesmo depois de absorver OCR, Vision e Color Picker.
- Rompe a convenção de janela única do overlay e cobra a migração para AppKit.
- Cabeçalho fixo na rolagem é um problema de qualidade sem fim óbvio.
- **Sandbox / App Store** — ver abaixo.

---

## O gate que decide o módulo

Dois documentos do projeto se contradizem:

- `macos/Runner/Release.entitlements` diz sandbox desligado porque *"o Evergreen
  é distribuído fora da App Store"*.
- `docs/brief-redesign-visual.md` diz *"vai para a Mac App Store, pago"*.

Não dá para ter os dois. Para este módulo a consequência direta é de licença:
**GPLv3 é incompatível com a Mac App Store**, então o macshot fica sendo apenas
leitura de qualquer forma, e sobram ScrollSnap e ScreenCap (MIT).

---

## Próximo passo, se decidir seguir

Prototipar **só a overlay borderless por monitor**, em Swift, com um retângulo
de seleção e nada mais. É a peça que decide tudo: se ela existir, print, OCR,
color picker e rolagem vêm todos atrás dela. Se ela não convencer, o módulo
inteiro não sai do papel.

# Evergreen · Redesign "Estufa" — especificação de implementação

> Documento de execução. Substitui `docs/brief-redesign-visual.md` e o prompt v2.
> Tudo aqui é **o que passa a existir**, não o que existe. Onde contraria uma regra
> vigente (seção 3.11 do prompt v2), está dito qual regra cai e o que entra no lugar.
> pt-BR em toda a UI e microcópia.

---

## 0. Tese

**Estufa.** Um app usado por segundos de cada vez não precisa de sete telas iguais:
precisa de **um material em comum e sete formas diferentes**. O vidro, a luz, a
tipografia e a matriz de estados são do sistema; **o layout é do módulo**.

Três consequências que valem como lei de projeto:

1. **Cada módulo tem a tela do que ele faz.** Não existe "tela de preferências
   genérica" com o mesmo esqueleto sete vezes. Existe uma *anatomia* comum
   (cartão de seção + linha), aplicada em quantidades diferentes.
2. **Regra da não-duplicidade** (ver §1). Se a função existe no painel flutuante,
   ela **não** se repete no Hub.
3. **Toda decisão visual tem uma razão funcional dizível em uma frase.** Se não
   tiver, sai.

---

## 1. Regra da não-duplicidade — a lei mais importante deste redesenho

**O painel flutuante é onde se OPERA. O Hub é onde se CONFIGURA e onde se LÊ.**

Nenhuma função de operação aparece nos dois lugares. O Hub pode *mostrar que algo
está acontecendo* (estado, em uma linha, sem controle), e oferecer **um único
caminho de volta**: abrir o painel pelo atalho.

| Módulo | Opera no painel (⌘⇧…) | Hub: configura | Hub: lê / histórico | O que o Hub **não** tem |
|---|---|---|---|---|
| **Pin** | buscar, colar, fixar, apagar item, gerar CPF/CNPJ | captura, tipos, colagem, limites | contagem, uso por tipo | a lista do histórico completa, o preview de item |
| **Focus** | iniciar, pausar, encerrar, anotar sessão | durações, comportamento, atalho | histórico da semana, leitura da sessão | botões de pausar/encerrar; o cronômetro grande |
| **Leaf** | ler, copiar, editar, criar cartão | 3 ajustes | "5 de 9 espaços em uso" (uma linha) | a parede 3×3 |
| **Awake** | ligar, escolher prazo, estender, desligar | o que fica acordado, gatilhos, atalho | último uso (uma linha) | o relógio/anel e os botões de prazo |
| **Echo** | gravar, pausar, marcar momento, parar | idioma, vozes, resumo, permissões | lista de reuniões + região de leitura | os controles de gravação |
| **Nest** | empilhar, escolher destino, enviar um a um, passar | destinos, como abre, depois de enviar | o que foi movido (opcional, via Track) | a pilha e o botão Enviar |
| **Track** | — (não tem painel) | — (não tem interruptor próprio) | balanço da semana, barras, dia | tudo o mais |

**Estado sem controle** é a única exceção permitida, e tem forma fixa: uma
**faixa de estado** de 34 pt no topo da área de conteúdo, com bolinha de estado,
texto, e o atalho como *keycap* à direita — sem botão.

```
┌────────────────────────────────────────────────────────────┐
│ ● Sessão rodando · 18:04 restantes · "Redesenhar sidebar"  ⌘⇧F │
└────────────────────────────────────────────────────────────┘
```

**Regra 3.11.2 cai parcialmente:** o interruptor mestre continua existindo, mas
sai da lista de seções e vira **pílula no cabeçalho**, ao lado do título. E o
**Track não tem interruptor** — ele desliga quando os módulos que o alimentam
desligam (dito em texto no rodapé da tela).

---

## 2. Sistema

### 2.1 EgPalette — degraus que o olho separa

O problema nunca foi a cor, foi a **amplitude**. Os neutros viviam entre `#0B` e
`#2E` (23 pontos para 5 papéis). Agora vão de `#08` a `#36`, com salto mínimo de
5 pontos entre papéis vizinhos.

```dart
// neutros — degradê real de profundidade
canvasDeep      #08090A   // base do degradê da janela
canvas          #14181A   // topo da janela
surface         #191E20   // cartão de seção
surfaceTop      #1D2325   // topo do degradê de cartão destacado
raised          #212729   // SELECIONADO, hover de pílula, faixa de estado
control         #272E31   // botão secundário, campo, keycap
hover           #2E3639   // hover de controle
pressed         #1D2325   // pressed = afunda (mais escuro), não clareia
line            #363F42   // divisor visível        (antes #262626 — invisível)
edge            #FFFFFF @ 7%   // hairline de borda de cartão
edgeLight       #FFFFFF @ 14%  // hairline interna de luz (topo de painel/pílula)

// vidro (só janela 0 e dropdown)
glassPanel      #161B1D @ 66%  + blur 40 + saturate 165%
glassRow        #FFFFFF @ 10%  // linha selecionada dentro do vidro
glassControl    #FFFFFF @ 9%   // botão secundário dentro do vidro

// acento — o verde perde papéis
accent          #22C55E   // SÓ dois papéis: ligado + ação primária
accentLight     #6EE7A0   // rótulo/ícone sobre fundo escuro, nunca fundo
accentDeep      #15803D
accentPressed   #18A652
accentHover     #2ED26B
onAccent        #08090A

// papéis que ANTES eram verde e agora não são
selection       -> raised (#212729) + edgeLight interna + peso 600 no texto
focusRing       -> #FFFFFF @ 34%, spread 2, blur 0
selectionLabel  -> textPrimary (o rótulo selecionado é branco e mais pesado)

// dados quantitativos (novo — para o Track, o Focus e o Echo não virarem tudo verde)
ember           #E8B24A   // tempo de reunião, estado "em processamento"
tide            #5B9CF6   // arquivo/sistema, informação neutra
onEmber/onTide  #08090A

// texto
textPrimary     #EDF2F0
textSecondary   #9BA6A3
textTertiary    #6B7674
textQuaternary  #4C5457
textDisabled    #454E51

// semânticos
error           #EF4444   (superfície #EF4444 @ 6%, borda @ 22%, rótulo #F8B4B4)
warning         #E8B24A
scrim           #000 @ 62%
shadow          #000 @ 78%
shadowContact   #000 @ 45%
```

**Por que:** entre `background` e `card` havia 6 pontos de luminância — o olho não
separa. Agora `canvas → surface → raised → control` sobe 5, 8 e 6 pontos, e a
borda saltou de `#262626` para `#363F42`, que é o primeiro valor que se enxerga
sobre `#191E20` num painel P3 a 50% de brilho.

**Papéis novos:** `edgeLight`, `glassPanel`, `glassRow`, `glassControl`, `ember`,
`tide`, `accentPressed`, `accentHover`, `pressed`, `textDisabled`.
**Papéis removidos:** `selection`, `selectionLabel`, `selectionEdge`,
`accentGradient`, `selectionGradient`, `sidebar` (a sidebar passa a ser
`#FFFFFF @ 2.6%` sobre o canvas, um token só: `sidebarTint`).

### 2.2 EgTypeScale — dois degraus novos no topo

O topo da escala era 17 pt: nenhuma tela tinha ponto de entrada. Entram `display`
e `title`; `screenTitle` some (virou `display`).

| Papel | Tam | Peso | Tracking | Altura | Uso |
|---|---|---|---|---|---|
| `display` | **30** | 650 | −0.78 | 1.0 | nome do módulo no cabeçalho do Hub — **um por tela** |
| `title` | **20** | 620 | −0.28 | 1.2 | "Semana", "Destinos", título da leitura |
| `panelTitle` | 15 | 600 | 0 | 1.2 | título de painel flutuante |
| `body` | 13.5 | 400 | 0 | 1.4 | linha de configuração |
| `bodyEmphasis` | 13.5 | 500 | 0 | 1.4 | item de lista relevante |
| `bodyStrong` | 13.5 | 600 | −0.1 | 1.3 | **linha selecionada** |
| `bodyCompact` | 12.5 | 400 | 0 | 1.4 | lista dentro de painel |
| `reading` | 14 | 400 | 0 | **1.65** | região de leitura |
| `footnote` | **11.5** | 400 | 0 | 1.35 | explicação de uma linha sob o rótulo (novo) |
| `caption` | 11.5 | 400 | 0 | 1.5 | metadados |
| `overline` | 11 | 600 | **+0.99** | 1.0 | rótulo de seção — **agora em SF Mono** |
| `keycap` | 10.5 | 600 | 0 | 1.0 | tecla (mono, tabular) |
| `button` | 12.5 | 600 | 0 | 1.0 | |
| `timer` | 48 | 500 | −0.96 | 1.0 | cronômetro grande (só no painel) |
| `timerSmall` | 32 | 500 | −0.64 | 1.0 | cronômetro em painel estreito |
| `mono` / `monoSmall` | 12 / 10.5 | 400/500 | 0 | 1.4 | valores, atalhos, contagens |

**Por que o overline vira mono:** ele é rótulo de estrutura, não de conteúdo.
Em mono + tracking alto, o olho o lê como "etiqueta de gaveta" e para de competir
com o `body`. Custa zero — SF Mono já está no bundle.

**Regra mantida:** `copyWith` em estilo só para cor. Peso e tamanho são degraus.

### 2.3 EgShapes — squircle, e maior

```dart
radiusWindow    26   // ContinuousRectangleBorder
radiusPanel     20   // painel flutuante
radiusStage     18   // bloco-instrumento (o anel do Focus, a pilha do Nest)
radiusCard      14   // cartão de seção
radiusRow       11   // linha de lista / item de sidebar
radiusControl   10   // botão, campo
radiusSegment    7   // segmento dentro do trilho
radiusChip     999   // pílula: interruptor mestre, filtro, prazo
hairline         1
```

**Implementação:** `ContinuousRectangleBorder` para tudo ≥ 14; abaixo disso o arco
circular é indistinguível e `BorderRadius.circular` fica (mais barato).
`ContinuousRectangleBorder(cornerRadius: r * 1.2)` aproxima o squircle da Apple —
calibrar contra uma captura do Sonoma antes de fechar o número.

**Isto resolve o sintoma nº 1 ("quadrado") sozinho.** É a mudança de maior
impacto por linha de código do documento inteiro.

### 2.4 EgElevations e material

```dart
floatingPanel = [
  #000 @ 78%  blur 56  y+28  spread −20,
  #000 @ 45%  blur 12  y+4   spread −6,
]
panelInnerHairline = 1 px  #FFFFFF @ 14%   // topo interno — NOVO
dropdown  = [ #000 @ 70% blur 24 y+8 spread −8 ]
raisedRow = inset 0 1 0  #FFFFFF @ 8%      // o que faz "selecionado" ler como elevação
control   = []                              // botão não levanta do fundo
focusRing = [ #FFFFFF @ 34%  blur 0  spread 2 ]
```

A **hairline interna de luz** é o que faltava para o painel parecer feito de
material e não desenhado: no macOS a borda superior de uma janela translúcida
recebe luz do ambiente. Uma linha de 1 px a 14% no topo interno, com o degradê
`panelSurface` já existente, resolve o sintoma nº 7.

**Vidro — custo assumido explicitamente:**

- **Liga** em: janela flutuante (janela 0) e dropdown. Vivem segundos.
- **Não liga** em: sidebar do Hub e cartões de conteúdo. Ficam na tela o tempo
  todo; um `BackdropFilter` permanente recompõe tudo atrás a cada quadro.
- A sidebar usa `sidebarTint` (#FFFFFF @ 2.6%) chapado + divisor — visualmente
  paga o mesmo papel a custo zero.
- `AppMaterials.panelVibrancy` já existe; é ligar `usesVibrancy: true` no tema
  `evergreen` e apagar o caminho opaco.

### 2.5 EgGradients — amplitude útil

Os degradês atuais têm 2–5 pontos de luminância: não se veem. Ou sobem, ou saem.

```dart
windowBackground  #14181A → #0B0D0E   (vertical, 0 → 1)          // 9 pontos
stageSurface      #1D2325 → #161B1D   (vertical)                  // bloco-instrumento
cardSurface       removido — cartão é chapado #191E20
accentGradient    removido — botão primário é chapado
nestStage         radial rgba(34,197,94,.09) em (20%, 0%), raio 1.2, sobre stageSurface
```

**Regra:** degradê só para **profundidade ou material**. Nunca decoração. Um
chapado bem resolvido vence um degradê genérico.

### 2.6 EgMotion

```dart
instant   90 ms   hover, pressed, anel de foco
fast     140 ms   troca de estado pequena, troca de aba
entrance 120 ms   entrada de painel — escala 0.97 → 1 + opacidade
exit       0 ms   SAÍDA É INSTANTÂNEA — mantido, é identidade do app
medium   220 ms   crescimento da janela do Hub (centro fixo)
stack    160 ms   cartão da pilha do Nest sobe 12 pt e some
curva    easeOutQuint  (era easeOutCubic — chega mais rápido, assenta mais macio)
```

**Invariante:** nenhuma animação bloqueia teclado. O painel aceita tecla no
primeiro quadro da entrada. Se a animação atrasa a primeira tecla, ela está errada.

---

## 3. Anatomia dos componentes

### 3.1 Cabeçalho de tela do Hub (novo)

```
padding 26 / 28 / 18
┌─────────────────────────────────────────────────────────────────┐
│ Pin                                        [●───  Ativo] [⌘⇧C]  │  display 30
│ Histórico da área de transferência. 1.842 itens em 30 dias.     │  body, secundária
│                                                                  │
│ ( Ajustes ) ( Tipos 6 ) ( Gerador )              [🔍 buscar ]   │  abas de tela, 28 pt
└─────────────────────────────────────────────────────────────────┘
  divisor 1 px #363F42 @ borda inferior
```

- **Interruptor mestre**: pílula de 32 pt, `radiusChip`, fundo `accent @ 13%`,
  borda `accent @ 30%`, toggle + rótulo "Ativo"/"Desligado". Sai da lista.
- **Atalho**: keycap de 32 pt ao lado — clicável, abre o gravador de atalho.
- **Abas de tela**: só aparecem em módulos que têm mais de um assunto (Pin, Echo).
  Módulo simples não tem aba.
- **Campo de busca de ajuste**: só nas telas com ≥ 8 linhas de configuração
  (Pin, Echo, Aplicativo). Filtra as linhas, não navega.

### 3.2 Cartão de seção + linha de configuração

**Sai a escada de pares soltos** (sintoma nº 6): o rótulo à esquerda e o controle
à direita separados por 400 px de vazio. Entra **cartão com largura de coluna**.

```
overline (mono 11, +0.99, textTertiary)            ← rótulo de seção, FORA do cartão
┌─ card #191E20, borda edge, radius 14 ────────────┐
│ Guardar por                            [7d|30d|∞]│  linha 38 pt
│ apaga sozinho depois do prazo                    │  footnote 11.5
├──────────── divisor 1 px #FFFFFF@5% ─────────────┤
│ Limite de itens              ──●───── 2.000      │  linha 38 pt
└──────────────────────────────────────────────────┘
padding do cartão: 0 (as linhas têm 9 / 12)
```

Medidas: **linha 38 pt** sem footnote, **46 pt** com footnote. Rótulo `body`,
footnote `footnote` em `textTertiary`. Controle encostado à direita.
O vão entre rótulo e controle nunca passa de **1 coluna do grid** (a coluna tem
~300 pt em janela mínima) — é isto que mata a escada.

**Layout de duas colunas:** a área de conteúdo do Hub vira
`grid-template-columns: 1fr 1fr; gap: 18` a partir de 880 pt de janela; abaixo
disso, uma coluna. Cartões são atômicos: nenhum cartão quebra entre colunas.

### 3.3 Item de sidebar

```
altura 34 · radius 11 · padding 0 10 · gap 10
[glifo 16] Pin                             ⌘⇧C  ●
```

- Glifo: path em Dart, 16 pt, `textSecondary`; `accentLight` quando selecionado.
- **Atalho sempre visível** em `keycap` `textQuaternary` — a sidebar vira o mapa
  de teclas do app. É a resposta ao "teclado é a interface primária".
- **Bolinha de estado** 5 pt à direita: `accent` = ligado, `#3F464A` = desligado,
  `ember` + contador = rodando agora (`18:04`).
- **Selecionado** = `raised` + `raisedRow` (hairline interna) + `bodyStrong`.
  Sem aresta verde de 3 px.
- **Grupos**: `CAPTURA` (Pin, Leaf, Nest) · `TEMPO` (Focus, Awake, Track) ·
  `VOZ` (Echo). Overline mono, padding 18 acima / 8 abaixo. Resolve o sintoma nº 8.
- Largura da sidebar: **232 pt** (era 260). Os 28 pt vão para a área de conteúdo.
- Rodapé: linha "Aplicativo ⌘⇧," (item normal, é uma tela) + uma linha
  `mono 10.5 textQuaternary`: "tudo local · nada sai daqui".

### 3.4 Controles

| Componente | Medida | Notas |
|---|---|---|
| Botão primário | h 32, radius 10, `accent`, texto `onAccent` 600 | keycap embutido à direita a 50% de opacidade |
| Botão neutro forte | h 32, radius 10, `#EDF2F0`, texto `#0B0D0E` | ação de sistema (Pausar, Parar e resumir) — evita verde onde não é "ligado" |
| Botão secundário | h 32, radius 10, `control` + borda `edge` | |
| Botão destrutivo | h 26, radius 8, transparente + borda `error @ 40%` | mora dentro do cartão vermelho |
| Toggle | 34 × 20, botão 15 | ligado = `accent`, botão `#08090A` |
| Segmented | trilho `#0F1315` radius 9, segmento h 22 radius 7 | selecionado = `hover` + peso 600 |
| Campo de busca | h 38, radius 12, `#FFFFFF@4%` + borda `edge` | |
| Keycap | h 18–26, radius 5–8, `#FFFFFF@11%` (vidro) / `control` (Hub) | |
| Slider | trilho 3 px, polegar 12 | valor em `mono` tabular à direita |
| Badge de contagem | h 20, radius 999, `accent`, `mono` 10.5 | |

### 3.5 Barra de teclas (rodapé do painel)

Altura **34**, fundo `#000 @ 18%`, divisor no topo. Pares `[keycap] rótulo`,
gap 6 dentro do par, 14 entre pares, `esc fechar` sempre por último, à direita.
Máximo **4 pares** — se precisar de um quinto, a função não é essencial.

### 3.6 Estado vazio (sintoma: badge genérico)

Sai o badge de ícone 40 com glifo. Entra o **contorno do que vai aparecer ali**:
um desenho tracejado (1 px, `#FFFFFF@14%`) da própria coisa que falta — uma linha
de lista para o Pin, um cartão para o Leaf, um retângulo de arquivo para o Nest.
Abaixo: título `bodyStrong` + uma linha `caption` com o atalho que preenche.

### 3.7 Faixa de estado (novo — o que substitui a duplicidade)

Altura 34, radius 11, `raised`, hairline interna. `[● cor] texto · valor mono`
à esquerda, keycap do atalho à direita. **Não é clicável para operar** — clicar
abre o painel. Existe no Hub do Focus, do Awake, do Echo (gravando) e do Nest
(pilha com itens).

---

## 4. Telas

### 4.1 Hub — geometria

| Medida | Valor | Mudança |
|---|---|---|
| Conteúdo inicial | 880 × 620 | mantido |
| Mínimo | 720 × 480 | mantido |
| Sidebar | **232** | era 260 |
| Padding do conteúdo | 26 topo · 28 lados · 24 base | era 32/32/48 |
| Grid do conteúdo | 2 colunas · gap 18 (≥ 880) / 1 coluna (< 880) | novo |
| Região de leitura | 480 preferidos, cede até 0 | mantido |
| Crescimento da janela | 220 ms, centro fixo | mantido |

### 4.2 Pin — o módulo com mais assunto (ponto 1, 2 e 10)

**Três abas de tela**, porque são três assuntos distintos e misturá-los foi o erro
do estado atual. **Aba não é seção**: cada aba tem seu próprio conteúdo e sua
própria contagem.

**Aba `Ajustes`** — duas colunas de cartões:

| Coluna A | Coluna B |
|---|---|
| `CAPTURA` — Guardar por (7d/30d/∞) · Limite de itens (slider, 2.000) · Ignorar apps de senha (toggle, footnote com os nomes) | `COLAGEM` — Colar sem formatação · Fechar depois de colar · Mostrar preview ao lado |
| `PRIVACIDADE` — Apps ignorados (lista editável) · Não guardar quando a tela estiver compartilhada | `LIMITES` — cartão destrutivo: Apagar histórico (1.842 itens · sem volta) |

**Aba `Tipos`** — só tipos. Grade de 2 colunas de pílulas de 30 pt: cada tipo com
bolinha de estado, nome e contagem em mono (`Texto 1.4k`, `Link 312`,
`Imagem 88`, `Arquivo —`, `Cor —`, `Rich text —`). Ligado = `accent @ 10%` +
borda `accent @ 22%`. Desligado = `#0F1315` + borda `edge`. Um clique liga/desliga.
Nada mais mora aqui.

**Aba `Gerador`** — só o gerador. **Não é ajuste, é uma ferramenta**, e é por isso
que ele quebrava a tela de ajustes. Aqui ele tem o bloco-instrumento:
segmented CPF/CNPJ · campo de resultado 44 pt em `mono 18` tabular ·
botão `Copiar ⌘G` · abaixo, duas linhas de ajuste *do gerador*
("Aparecer na lista quando eu digitar `cpf`" · "Formatar com pontuação").

> **Duplicidade aceita, e só esta:** o gerador existe no painel (primeira linha
> quando você digita `cpf`) e no Hub. Motivo: no painel ele é *atalho*; no Hub ele
> é *bancada* — gerar vários, conferir, ajustar formato. São usos diferentes,
> não a mesma função duas vezes.

**Painel do Pin (⌘⇧C) — correções do ponto 10:**

- **Filtro embaixo do campo de busca**, como hoje: campo de busca em cima (linha
  inteira, 38 pt), e **abaixo dele** a fileira de pílulas
  `Tudo · Fixados · Links · Imagens · Arquivos` (22 pt, radius 999).
  Não pôr o filtro na mesma linha do campo — some quando a busca cresce.
- **O preview tem caixa.** O conteúdo copiado mora dentro de um cartão próprio:
  `#000 @ 22%`, radius 12, padding 12, altura flexível — nunca texto solto sobre
  o vidro. Separação visível entre "a lista" e "o item".
- Cabeçalho do preview: `overline` com tipo + tamanho (`TEXTO · 1.204 CARACTERES`)
  e, à direita, origem e hora (`há 4 min · Mail`) em `caption`.
- Rodapé do preview: `Colar ↩` (primário) · `Fixar` (secundário) · `⌫` (destrutivo,
  ícone só, à direita).
- Largura: **420** só-lista / **560** com preview. Altura até **460**. Mantidas.

### 4.3 Echo (pontos 3 e 4)

**Hub — lista + leitura.** Sem controles de gravação (§1).

- Lista agrupada por dia. Cabeçalho de grupo: `HOJE · SEXTA, 28` (overline mono) +
  filete + total do dia à direita.
- Linha de reunião: **44 pt** — badge de forma de onda 26 (verde = pronta,
  `ember` = transcrevendo, cinza = arquivada), título `bodyEmphasis`,
  `N vozes · estado` em `footnote`, miniatura de onda 64 × 16 e duração `mono`.
- **Renomear** (ponto 3): duplo-clique na linha edita o título no lugar
  (`EgTextField` inline, sem modal). No menu de contexto: Renomear · Exportar ·
  Apagar. Atalho: `↩` renomeia a linha selecionada, como no Finder.
- **Nomear ao terminar** (ponto 3): quando a gravação para, o **painel flutuante**
  troca por um estado final de ~6 s: campo de nome já focado com sugestão
  (`Reunião de sexta, 14:02`), `↩` confirma, `esc` aceita a sugestão. O painel
  não fica esperando: se perder o foco, salva com a sugestão. **Zero fricção,
  zero modal.**
- **Região de leitura** (ponto 4): título + metadados + segmented
  **`Resumo` · `Transcrição` · `Tarefas`** — mantidos exatamente assim.
  - `Resumo`: parágrafo `reading` + lista `DECISÕES` com marcadores 5 pt +
    bloco `TRECHOS COM SUA VOZ` (citação com filete `accentLight @ 50%`).
  - `Transcrição`: linhas com carimbo de tempo `mono` à esquerda, falante
    colorido (`accentLight` = você, `tide` = outros).
  - `Tarefas`: caixas de seleção, cada uma com o carimbo de onde saiu.
  - Rodapé: `Copiar resumo` (primário) · `Exportar .md` · `Apagar` (à direita).
- Ajustes do Echo em cartão único no fim da lista, com link "Abrir" — 8 linhas:
  idioma, separar vozes, resumir ao terminar, tamanho do resumo, guardar áudio,
  apagar depois de N dias, permissões (microfone/gravação de tela), atalho.

### 4.4 Focus (ponto 5)

**Hub — sem cronômetro operável.** No topo, a **faixa de estado**:
`● Sessão rodando · 18:04 · "Redesenhar a sidebar"` + keycap `⌘⇧F`.
Um relógio pequeno, `mono`, informativo. **Pausar e Encerrar existem só no painel.**

O resto da tela é o que o Hub sabe fazer melhor que o painel — **o histórico**:

- `Semana` (title 20) + subtítulo `14 sessões · 9 h 20 de foco · média 40 min` +
  segmented `Semana | Mês`.
- Linhas de dia (36 pt): sigla do dia em mono, faixa de blocos proporcionais
  (verde = foco, `ember` = sessão em curso), total à direita, chevron para abrir
  o dia na região de leitura.
- Dois cartões lado a lado: `DURAÇÕES` (foco 25 · pausa 5 · pausa longa 20) e
  `COMPORTAMENTO` (pedir o que vai fazer · emendar pausa · som ao terminar).
- Região de leitura da sessão: o que foi anotado, a linha do tempo das pausas.

**Painel (⌘⇧F):** anel de 128 pt com o tempo em `timerSmall`, o texto do que está
sendo feito, `Pausar ␣` (botão neutro forte) e `Encerrar`. É o único lugar com
esses botões.

### 4.5 Leaf (ponto 8)

**Hub — sem a parede.** A parede é o painel; repetir os 9 cartões no Hub é
duplicidade pura. A tela fica curta e assume isso:

```
Leaf                                      [●─── Ativo] [⌘⇧D]
Nove anotações, todas à vista. O número do cartão é a tecla que copia.

┌ faixa de estado ────────────────────────────────────────┐
│ ● 5 de 9 espaços em uso · última edição há 2 h      ⌘⇧D │
└─────────────────────────────────────────────────────────┘

AJUSTES — SÃO SÓ TRÊS
┌──────────────────────────────────────────────────┐
│ Copiar e fechar                            [●──] │
│ o painel some no instante em que você aperta o nº│
│ Tamanho do texto do cartão            [P|M|G]    │
│ Atalho global                            [⌘⇧D]   │
└──────────────────────────────────────────────────┘

LIMPEZA
┌──────────────────────────────────────────────────┐
│ Esvaziar todos os cartões        1.4 KB  [Apagar]│
└──────────────────────────────────────────────────┘
```

Uma tela curta não é uma tela pobre: é o módulo dizendo que não pede nada.
**Não preencher com nada.**

**Painel (⌘⇧D):** grade 3 × 3 de cartões **~200 × 118**, painel ~660 de largura.
Número do cartão em badge 18 (verde quando foi o último copiado, com "copiado" em
`caption` ao lado). Vazio = contorno tracejado + "digite pra criar".
Barra de teclas: `1-9 copiar` · `⌥1-9 editar` · `esc fechar`.

### 4.6 Awake (ponto 9)

**Hub — sem relógio e sem os botões de prazo.** Faixa de estado
(`● Desligado` ou `● Tela acesa · termina 19:42`) + keycap, e só ajustes:

- `O QUE FICA ACORDADO` — dois cartões de escolha lado a lado
  (`Tela acesa` / `Só o sistema`), com uma linha de exemplo de uso em cada.
  É configuração de *padrão*, não a ação.
- `PRAZO PADRÃO` — segmented `30 min | 1 h | 2 h | até eu desligar`: o que vem
  pré-selecionado quando o painel abre.
- `GATILHOS` — Ligar sozinho quando eu espelhar a tela (footnote:
  projetor, Sidecar, AirPlay) · Ligar durante gravação do Echo.
- `Atalho global ⌘⇧X`.

**Painel (⌘⇧X):** o objeto inteiro — badge 40, "Tela acesa", "termina 19:42 ·
1 h 34 restante", toggle mestre, barra de progresso 6 px, `+30 min` `+1 h`
`Desligar`. Teclas `1-4` escolhem prazo.

### 4.7 Nest (pontos 7 e 11)

**Hub — sem a pilha e sem "Enviar".** A pilha é a alma do painel; no Hub ela
seria uma maquete inútil. O Hub cuida dos **destinos** e das regras.

**Destinos como lista, não como grade** (ponto 11) — porque a lista escala e a
grade de tiles quebra a partir de 3–4 pastas:

```
Destinos                                   ⌥1..⌥9 manda direto
┌ card ────────────────────────────────────────────────────┐
│ ⌥1  ▮ Entregas/Agosto        ~/Documentos/…    128  ⋮⋮  │  linha 40
│ ⌥2  ▮ Clientes/Ativos        ~/Trabalho/…       31  ⋮⋮  │
│ ⌥3  ▮ Recibos/2026           ~/Financeiro/…      9  ⋮⋮  │
│ ⌥4  ▮ Referências            ~/Imagens/…        —   ⋮⋮  │
│ …                                        (rola dentro)   │
├──────────────────────────────────────────────────────────┤
│ ＋ Arraste uma pasta aqui ou escolha…                     │  linha 40, tracejada
└──────────────────────────────────────────────────────────┘
```

- Linha de **40 pt**: número de atalho em `keycap` (só os 9 primeiros têm),
  chip de cor da pasta 22 × 18 (a cor é escolhida pelo usuário e é o que aparece
  no painel), nome em `bodyEmphasis`, caminho em `footnote` truncado no meio,
  contagem do mês em `mono`, alça de arraste `⋮⋮` no hover.
- **Reordenável por arraste** — a ordem define `⌥1..⌥9`.
- O cartão **rola internamente** a partir de 8 linhas, com altura máxima de
  360 pt. Acima de 12 destinos, aparece um campo de filtro no cabeçalho da seção.
- Abaixo: `COMO ABRE` (chacoalhar no arraste · sensibilidade baixa/média/alta) e
  `DEPOIS DE ENVIAR` (mover ou copiar · fechar quando esvaziar · revelar no Finder).

**Painel (⌘⇧R) — a pilha, adaptada ao "um por vez":**

- **Bloco da pilha** à esquerda (96 × 110): três cartões `radiusStage` empilhados
  com rotações de −9° / +5° / 0°, o de cima com o ícone real do arquivo
  (`QLThumbnail`) e a hairline de luz. Badge verde com o total (`12`) no canto.
- À direita: `1 DE 12 · PRÓXIMO` (overline), nome do arquivo (`panelTitle`),
  `2,4 MB · ~/Downloads` (caption), a **caixa de destino** (34 pt, tracejada
  `accentLight @ 40%`, com o chip de cor, o caminho e `⌥1`), e dois botões:
  `Enviar ⌘↩` (primário) e `Passar →` (secundário).
- Abaixo, a **fila** — linhas de 30 pt com os próximos arquivos, numeradas.
  Arraste reordena; a ordem é a ordem de saída.
- **Animação `stack` (160 ms):** ao enviar, o cartão de cima sobe 12 pt, some, o
  contador cai para `11`, o próximo assume o topo. É a única animação decorativa
  do app, e ela existe porque *confirma que exatamente um saiu*.
- Vazio: contorno tracejado de arquivo + "Chacoalhe um arquivo no arraste, ou
  solte aqui".

### 4.8 Track (ponto 6)

Sem interruptor, sem painel, sem atalho. Só leitura, e o texto diz isso: pílula
`tide` no cabeçalho — "nada é gravado aqui" — e, no rodapé, "O Track não tem
interruptor próprio: ele desliga quando os módulos que o alimentam desligam" +
botão `Ver fontes` (abre a lista de módulos que alimentam o dia).

- **Três cartões de balanço** no topo (`FOCO 9 h 20` / `REUNIÃO 6 h 12` /
  `ARQUIVOS 128`), cada um com uma linha de comparação em cor
  (`+1 h 05 vs. semana passada` em `accentLight`; `40% do tempo ativo` em `ember`).
- **Últimos 7 dias**: linha de 34 pt por dia, com uma **faixa de tempo** de 10 px
  (não uma barra de total) — os blocos ficam nas posições reais do dia, então a
  forma da faixa é o formato do dia. Legenda: verde foco · `ember` reunião ·
  `tide` arquivo.
- **Região de leitura do dia**: linha do tempo vertical, carimbo `mono` à
  esquerda, ponto colorido por tipo, título + uma linha de detalhe.
  A mesma faixa da lista é a fonte do desenho — clicar num dia troca só a coluna.

### 4.9 Aplicativo

A única tela que continua sendo formulário, e assume: `SISTEMA` (iniciar com o
macOS · ícone na barra de menus + footnote · abrir o Hub com ⌘⇧,) ·
`TODOS OS ATALHOS NUM LUGAR` (grade 2 × 3, os seis módulos com painel) ·
`SEUS DADOS` (backup local com Exportar/Importar + último backup) ·
cartão destrutivo `Zerar o Evergreen`. Rodapé: `nada sai deste Mac · sem conta ·
sem sync` em mono, e "Novidades da versão" à direita.

---

## 5. Matriz de estados (`EgSurfaceStyle`)

Precedência mantida: `disabled > selected > pressed > hover|focused > rest`.

| Família | rest | hover | pressed | selected | focused | disabled |
|---|---|---|---|---|---|---|
| `row` (34, r11) | transparente, `body` `textSecondary` | `#1D2325` | `#2A3134` | `raised` + hairline + `bodyStrong` | rest + anel `#FFF@34%` sp2 | texto `textDisabled` |
| `sidebarItem` | transparente | `#1D2325` | `#2A3134` | `raised` + hairline + glifo `accentLight` | anel | 40% |
| `primary` | `accent` | `accentHover` | `accentPressed` | — | `accent` + anel | `#1B3D28`, texto `#4C6B57` |
| `neutralStrong` | `#EDF2F0` | `#FFFFFF` | `#D2D9D6` | — | + anel | `#2A3134`, texto `#5E6669` |
| `secondary` | `control` + `edge` | `hover` + borda 11% | `pressed` | `#39433F` + borda `accentLight@35%` | + anel | `#1A1F21`, texto `textDisabled` |
| `destructive` | transparente + borda `error@40%` | `error@10%` | `error@18%` | — | + anel | 40% |
| `toggle` | trilho `hover` | trilho `#3A4347` | botão 17 × 15 (alonga) | trilho `accent` | + anel | trilho `#1F2426` |
| `segment` | transparente | `#1D2325` | `#252C2F` | `hover` + peso 600 | trilho + anel | 40% |
| `card` | `surface` + `edge` | — | — | `surfaceTop` + borda 11% | — | 55% |
| `glassRow` | transparente | `#FFF@6%` | `#FFF@14%` | `#FFF@10%` + hairline | + anel | 40% |

**Selecionado é elevação + peso, nunca cor.** Resolve os sintomas 2, 5 e 6 de uma
vez: separa camadas, devolve significado ao verde e cria agrupamento visual.

Golden novo: `test/goldens/design_state_matrix_estufa.png`, cobrindo as 10
famílias × 6 estados, no fundo `canvas` e sobre `glassPanel`.

---

## 6. Antes/depois — três telas

**Pin (Hub).** Antes: uma coluna, 5 seções empilhadas, 14 linhas de rótulo à
esquerda e controle à direita, gerador no meio dos ajustes, rolagem obrigatória.
Depois: três abas por assunto (Ajustes/Tipos/Gerador), ajustes em duas colunas de
cartões, tudo acima da dobra em 880 × 620, gerador com bancada própria.
→ resolve **6** (ritmo horizontal), **4** (ponto de entrada), **2** (camadas).

**Leaf (Hub).** Antes: parede 3 × 3 repetida do painel + 5 seções de ajuste.
Depois: faixa de estado de uma linha + 3 ajustes + limpeza; a parede vive só no
painel. → resolve **duplicidade** e **4**; a tela encurta 60%.

**Painel do Pin.** Antes: retângulo cinza opaco, canto de raio 12 em arco
circular, sombra genérica, preview solto sobre o fundo.
Depois: vidro (blur 40 + sat 165%), `radiusPanel` 20 contínuo, sombra de duas
camadas + hairline interna de luz, preview em caixa própria, filtro em pílulas
sob a busca. → resolve **1** (quadrado), **3** (sem material), **7** (sombra),
**10** (separação).

---

## 7. O que muda em código

**Tokens** (`lib/core/design/`)
- `EgPalette`: +10 papéis novos, −6 removidos, ~20 valores recalibrados. Todo
  campo é `required` → nasce nos dois arquivos de tema ao mesmo tempo; o tema
  `apple` recebe os mesmos papéis com valores próprios (ou é apagado, se a flag
  `themes` continuar desligada — **recomendação: apagar**, é dívida morta).
- `EgTypeScale`: +`display`, +`title`, +`footnote`, +`keycap`, +`timerSmall`;
  `overline` passa a SF Mono; `screenTitle` sai.
- `EgShapes`: +`radiusWindow`, +`radiusStage`, +`radiusChip`; adoção de
  `ContinuousRectangleBorder` (novo helper `EgSquircle.border(r)`).
- `EgElevations`: +`panelInnerHairline`, +`raisedRow`; `focusRing` muda de verde
  para branco.
- `EgGradients`: `cardSurface` e `accentGradient` saem; `stageSurface` e
  `nestStage` entram; `windowBackground` ganha amplitude.
- `EgMotion`: curva `easeOutQuint`, +`stack` (160 ms).

**Componentes** (`lib/shared/widgets/`)
- Novos: `EgScreenHeader` (título + pílula mestre + keycap + abas),
  `EgStatusStrip` (a faixa de estado), `EgSettingsCard` (cartão + divisores),
  `EgDestinationRow` (linha de destino do Nest, arrastável),
  `EgStack` (a pilha do Nest + animação), `EgKeyHintBar` (rodapé, no lugar do
  `EgHintBar`), `EgTypePill` (pílula de tipo do Pin), `EgFilterPills`.
- Reescritos: `EgSettingsRow` (footnote, 38/46 pt, controle colado à direita),
  `EgNavTile` (atalho + bolinha de estado + grupo), `EgEmptyState` (contorno em
  vez de badge), `EgPanel` (vidro + hairline), `EgOverlayShell` (entrada 120 ms
  com escala), `EgSegmentedControl`, `EgToggle`, `EgButton` (+ variante
  `neutralStrong`).
- Removidos: a aresta de seleção de 3 px (todos os usos), `EgSectionLabel` como
  widget separado (vira parâmetro do `EgSettingsCard`).

**Telas** — todas as 11 do escopo. Ordem sugerida de execução:
1. Tokens + `EgSquircle` + matriz de estados + golden novo (nada visual muda
   ainda; o compilador guia).
2. `EgScreenHeader` + sidebar + Hub do Pin (valida a anatomia em duas colunas).
3. Painéis: vidro, hairline, barra de teclas (validam o material).
4. Focus / Awake / Leaf — aplicar a regra da não-duplicidade (as telas encolhem).
5. Echo (renomear + leitura em 3 abas) e Nest (destinos em lista + pilha).
6. Track e Aplicativo.

**Swift/AppKit — o que é novo e por quê**
- **Nada obrigatório.** Vibrancy sai do `BackdropFilter` já existente; squircle
  sai de `ContinuousRectangleBorder`; a sombra é `BoxShadow`.
- *Descartado, e o motivo:* usar `NSVisualEffectView` nativo atrás da janela
  flutuante daria vibrancy "de sistema" de graça em GPU, mas obrigaria a hospedar
  a superfície Flutter sobre uma view AppKit translúcida — muda o pipeline de
  composição da janela 0 e quebra o `NSPanel` não-ativante. Preferência da casa
  (Flutter puro) prevalece; se o custo de quadro do `BackdropFilter` medir acima
  de 4 ms em Intel, reabrir esta decisão.
- `QLThumbnail` (já existente) passa a alimentar o cartão de topo da pilha —
  antes era só um glifo genérico.

**Feature flags:** `themes` continua desligada (e o tema `apple` deve ser
apagado). `intro` e `onboarding` seguem desligadas — nenhuma decisão deste
documento depende delas.

---

## 8. Invariantes (não negociáveis)

1. Saída de painel é **instantânea**. Sempre.
2. `Esc` fecha. Sempre. Em qualquer estado, inclusive gravando (o Echo continua
   gravando em segundo plano — dito na barra de teclas).
3. Nenhuma tela de carregamento, nenhum pulo de layout, nenhuma transição acima
   de 220 ms.
4. Blur só onde a superfície é efêmera.
5. Nenhum literal de cor, raio, sombra ou duração fora de
   `lib/core/design/themes/`.
6. Nenhuma lógica de negócio em widget.
7. Se uma função existe no painel, ela **não** existe no Hub (§1).
8. Verde = ligado ou ação primária. Mais nada.

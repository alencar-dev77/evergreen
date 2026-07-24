# Handoff: Evergreen — Pin (v0.1) Design System

## Overview
Pin é o módulo de clipboard manager do Evergreen, um app desktop Flutter para macOS. Este pacote documenta o design system "Dark Premium" e as telas do Pin v0.1 para implementação em Flutter/Dart.

## About the Design Files
O arquivo `Evergreen Pin Design System.dc.html` incluído aqui é uma **referência de design em HTML** — um protótipo mostrando aparência e comportamento pretendidos, não código de produção. A tarefa é **recriar este design em Flutter** (widgets nativos, MVVM, arquitetura já definida no projeto Evergreen), usando os valores exatos abaixo — não copiar HTML/CSS diretamente.

## Fidelity
**High-fidelity.** Cores, tipografia, espaçamento e estrutura de componentes abaixo são finais e devem ser seguidos com precisão.

## Design Tokens

### Cores (usar como `Color` consts, ex. `AppColors`)
| Token | Hex | Uso |
|---|---|---|
| background | `#0B0B0B` | fundo da janela/overlay |
| surface | `#141414` | painel/card principal |
| card | `#1A1A1A` | campos, cards internos, badges |
| hover | `#232323` | estado hover/seleção de list item |
| border | `#262626` | bordas sutis (1px) |
| greenPrimary | `#22C55E` | ação primária, foco, indicador de fixado |
| greenLight | `#4ADE80` | hover de botão primário, acentos |
| textPrimary | `#F5F5F5` | texto principal |
| textSecondary | `#9CA3AF` | metadados, labels, placeholders |
| error | `#EF4444` | ações destrutivas (ex. "Encerrar") |
| warning | `#F59E0B` | alertas |

### Tipografia
Fonte: **Inter** (fallback: SF Pro Display / -apple-system).
| Estilo | Peso | Tamanho |
|---|---|---|
| Título de tela | 700 | 32px |
| Cabeçalho de seção | 600 | 20px |
| Texto de item / label UI | 500 | 15px |
| Texto secundário / metadados | 400 | 13px |

### Espaçamento e forma
- Border radius: cards/painéis 14–16px; botões 9–10px; badges de ícone 6–7px; toggle 11–12px (pill).
- Borda padrão: 1px solid `border` (#262626).
- Sombra do painel flutuante: `box-shadow: 0 24px 60px rgba(0,0,0,0.55)` — usar `BoxShadow` equivalente em Flutter.
- Muito respiro: padding generoso (16–24px) em cards; nunca telas apertadas.
- Scrollbar fina (~6px), track transparente, thumb `#262626`.

## Componentes

**Botão primário**: bg `#22C55E`, texto `#0B0B0B` peso 600, padding 10x18, radius 10, hover bg `#4ADE80`.
**Botão secundário**: bg `#1A1A1A`, borda 1px `#262626`, texto `#F5F5F5`, hover bg `#232323`.
**Botão ícone**: 36x36, transparente, ícone `#9CA3AF`, hover bg `#232323` + ícone `#F5F5F5`.
**Campo de busca**: bg `#1A1A1A`, borda 1px `#22C55E` (verde = foco), radius 10, ícone de lupa + placeholder em `textSecondary`.
**Toggle/switch**: trilho 36x21 pill; ligado = bg `#22C55E` com bolinha `#0B0B0B` à direita; desligado = bg `#262626` com bolinha `#9CA3AF` à esquerda.
**List item / card do clipboard**: bg `#1A1A1A`, radius 9-10, ícone 22-24px em badge `#232323` à esquerda indicando tipo (texto/link/comando), título em `textPrimary` (truncar com ellipsis), subtítulo em `textSecondary` 12px. Item selecionado/hover: bg muda para `#232323`.
**Indicador de fixado**: pequeno ícone de estrela verde (`#22C55E`) à direita do item.

## Telas / Views

### 1. Painel principal (overlay estilo Spotlight)
- Overlay flutuante centralizado, sem chrome de janela, ~420px largura, fundo `surface` (#141414), borda 1px `border`, radius 16, sombra flutuante.
- Topo: campo de busca (borda inferior 1px `border` separando do conteúdo).
- Lista dividida em duas seções com header uppercase 11px `textSecondary` peso 600: **"Fixados"** e **"Recentes"**.
- Navegação: ↑/↓ movem seleção, Enter copia novamente o item, Esc fecha o overlay.
- Densidade: compacta (mais itens visíveis, ~8-10px padding vertical por item), inspirada no Maccy.

### 2. Item selecionado — preview expandido
- Layout de duas colunas dentro do painel: lista à esquerda (~210px, borda direita 1px `border`), preview à direita.
- Preview mostra: badge de tipo + "copiado há Xmin" (uppercase, `textSecondary`), conteúdo completo em card `#1A1A1A` com `word-break`, botões "Colar novamente" (primário) e "Excluir" (secundário).

### 3. Estado vazio
- Painel centralizado, ícone de documento em badge 52x52 (`card` bg, borda `border`), título "Nenhum item ainda" (15px 600), subtítulo explicativo em `textSecondary`.

### 4. Fixados vs Recentes
- Mesma lista do painel principal — grupos com headers de seção separados; fixados sempre no topo, indicados com ícone estrela verde.

### 5. Menu bar dropdown
- Ícone verde `#22C55E` na barra de menu do macOS (barra 26-28px, fundo translúcido escuro).
- Dropdown ancorado no canto superior direito: item "Abrir painel", "Configurações", separador, "Encerrar Evergreen" em `error` (#EF4444).

### 6. Configurações
- Painel com seções: **Geral** (toggles "Iniciar com o macOS", "Abrir minimizado"), **Atalho global** (exibição do atalho como key-caps: `⌘` `⇧` `V` em badges `#1A1A1A` com borda), **Sobre** (versão do app).

## Interactions & Behavior
- Atalho global padrão do Pin: `⌘⇧C` — abre a busca do histórico independente do app em foco.
- Pesquisa em tempo real (filtra a lista a cada tecla).
- Todas as animações devem ser suaves, 60fps, sem gradientes exagerados.
- Fixar/desafixar item, excluir item, copiar novamente (Enter) — sem confirmação para copiar; excluir pode ter confirmação leve.

## State Management (sugestão MVVM)
- `PinViewModel`: lista de itens (fixados + recentes), texto de busca, item selecionado, estado do overlay (aberto/fechado).
- `SettingsViewModel`: iniciar com macOS (bool), abrir minimizado (bool), atalho customizado.
- Persistência local via Isar (histórico do clipboard, itens fixados, preferências).
- Nenhum dado sincroniza com a internet.

## Assets
Nenhuma imagem externa — apenas ícones vetoriais simples (documento, link, terminal, estrela) desenhados como paths SVG no protótipo; recriar como `Icons`/`CustomPainter` ou pacote de ícones no Flutter.

## Files
- `Evergreen Pin Design System.dc.html` — protótipo completo (tokens, componentes, todas as telas) usado como referência visual.

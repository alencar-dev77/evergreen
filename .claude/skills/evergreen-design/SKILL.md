---
name: evergreen-design
description: Identidade visual e de produto oficial do Evergreen, um aplicativo desktop nativo para macOS construído em Flutter. Use esta skill sempre que for desenhar, revisar, ajustar ou implementar QUALQUER tela, componente, fluxo, animação ou estado visual do Evergreen — telas novas, refatoração de telas existentes, componentes soltos (botões, listas, sidebars, popups, dialogs, menus, badges, empty states), microcopy de interface, espaçamento, cores, tipografia, motion, atalhos de teclado, ou qualquer decisão de UI/UX do projeto. Aciona também quando o pedido for vago ("melhora essa tela", "deixa mais bonito", "cria um modal para X", "como devo desenhar essa lista") — nesses casos, esta skill é a fonte de verdade que substitui qualquer intuição genérica de design. Não use para conteúdo de marketing, landing pages ou material web — o Evergreen é um app desktop, não um site.
---

# Evergreen Design

Esta skill é a **fonte oficial da identidade visual e de produto do Evergreen** — um aplicativo desktop nativo para macOS, construído em Flutter, no espírito de ferramentas como Raycast, Linear, Arc, Things 3, Craft, CleanShot X e Maccy.

Ela não é uma skill genérica de "design bonito". Ela existe para impedir um problema específico e recorrente: interfaces que **funcionam**, mas que denunciam imediatamente terem sido "geradas" — simétricas demais, coloridas demais, cheias de gradiente e sombra decorativa, com cards dentro de cards, ícones em excesso e uma sensação geral de maquete de landing page. O Evergreen precisa parecer **desenhado por alguém que usa o macOS o dia inteiro e odeia fricção**.

## Como usar esta skill

Esta skill é dividida em módulos. Leia o SKILL.md inteiro primeiro (ele te dá o mapa mental), depois abra os arquivos de referência conforme a tarefa exigir. Você não precisa ler tudo sempre — mas para qualquer entrega de UI, no mínimo leia `philosophy.md` e `anti-patterns.md` antes de desenhar qualquer coisa, porque é ali que mora a diferença entre "parece Evergreen" e "parece um template".

| Arquivo | Quando ler |
|---|---|
| `philosophy.md` | Sempre, antes de qualquer decisão de design. Define o caráter do produto. |
| `colors.md` | Ao escolher cores, estados (hover/focus/error), superfícies, dark/light. |
| `typography.md` | Ao definir hierarquia de texto, tamanhos, pesos, tracking. |
| `spacing.md` | Ao montar grid, densidade, alinhamento, respiro entre elementos. |
| `motion.md` | Ao animar qualquer transição, hover, abertura de painel, feedback. |
| `components.md` | Ao construir ou revisar botões, campos de busca, sidebars, listas, popups, modais, menus, badges, loading, empty states, etc. |
| `ux.md` | Ao pensar em atalhos de teclado, navegação, densidade de informação, fluxo de interação teclado/mouse/trackpad. |
| `accessibility.md` | Sempre que envolver contraste, foco, tamanho de alvo de clique, leitura de tela, redução de movimento. |
| `anti-patterns.md` | Sempre, como checklist final antes de considerar uma tela "pronta". |
| `references.md` | Quando precisar justificar uma decisão citando o princípio (não a interface) de um app de referência. |

Regra prática: **desenhe primeiro pensando no arquivo, depois no pixel.** Se uma decisão não tem lastro em algum destes arquivos, pare e pergunte-se "isso parece coisa que o time do Linear faria, ou parece coisa que uma IA faria porque é o caminho de menor resistência?".

## A regra de ouro

> Se a primeira impressão de uma tela é "nossa, que bonito", alguma coisa está errada. A primeira impressão certa é "nossa, que rápido" ou nenhuma impressão nenhuma — a interface deve desaparecer e deixar só a tarefa.

Isso significa, na prática:

- **Neutro antes de colorido.** Cor é usada para significar algo (estado, prioridade, ação), nunca para decorar.
- **Denso antes de arejado.** Espaço em branco existe para separar grupos de informação, não para preencher a tela.
- **Teclado antes de mouse.** Toda ação frequente tem atalho. O mouse é um complemento, não o caminho principal.
- **Instantâneo antes de suave.** Motion existe para explicar uma mudança de estado, nunca para "impressionar".
- **Nativo antes de bonito.** Se em dúvida entre o que é chamativo e o que é como o macOS já se comporta, escolha o macOS.

## O que este produto é (e não é)

O Evergreen é um app desktop de produtividade que roda o dia inteiro em segundo plano, sendo invocado rapidamente, usado por poucos segundos ou minutos, e descartado até a próxima necessidade — como o Raycast, o Maccy ou o Things. Não é uma ferramenta que a pessoa "visita" e explora; é uma ferramenta que a pessoa **aciona e resolve**.

Consequências diretas dessa natureza:

- Telas de estado vazio devem ser raras e discretas — o app normalmente já tem conteúdo.
- Não existem "seções de hero", "CTAs" ou "onboarding em carrossel". Isso é vocabulário de landing page.
- A janela principal deve poder ser operada inteiramente pelo teclado, do abrir ao fechar.
- Cada tela deve assumir que o usuário já sabe o que quer fazer — a interface guia com clareza estrutural, não com instruções de texto.

## Stack e restrições técnicas relevantes ao design

- **Flutter para macOS**, não Flutter para web/mobile. Isso significa: usar as convenções de teclado do macOS (Cmd em vez de Ctrl), respeitar `NSVisualEffectView`/blur nativo com moderação e considerar múltiplas densidades de tela Retina.
- **O app é dark-only**, por decisão explícita — light mode é dívida assumida, não esquecida. O escuro tem **duas peles** trocáveis em runtime (`evergreen`, a paleta da casa, e `apple`, o escuro do macOS), e é isso que o `ThemeExtension` do projeto serve: não introduza tokens claro/escuro nem `ThemeMode` "já preparando" o terreno. Todo valor visual vem do tema pelo contexto (`context.eg.…`) e um papel novo nasce nos dois temas ao mesmo tempo; ver `colors.md`, seção "Decisão do produto: dark-only, e duas peles escuras", e `THEMING.md` na raiz do repositório.
- Componentes devem ser pensados em termos de **estados explícitos** (`default`, `hover`, `active/pressed`, `focus`, `disabled`, `selected`, `loading`, `error`) porque é assim que se implementa consistência em Flutter (widgets com builders de estado), e porque é assim que apps macOS nativos realmente se comportam.
- Performance visual é parte do design, não um detalhe técnico posterior: uma sombra cara, um blur em excesso ou uma animação com muitos widgets rebuildando destroem a sensação de "app nativo rápido" que é a razão de existir do Evergreen.

## Fluxo recomendado para qualquer tarefa de UI

1. Leia `philosophy.md` e identifique qual "modo de uso" essa tela representa (ação rápida tipo Raycast? organização tipo Things? captura tipo CleanShot? navegação tipo Linear?).
2. Defina hierarquia de informação antes de qualquer cor: o que é primário, secundário, terciário nesta tela?
3. Aplique `spacing.md` e `typography.md` para estruturar antes de estilizar.
4. Aplique `colors.md` com neutros dominando 90%+ da superfície.
5. Escolha componentes em `components.md` — prefira sempre o componente mais simples que resolve o problema (lista antes de tabela, texto antes de badge, badge antes de card).
6. Se algo se move, abre ou muda de estado, defina o motion em `motion.md` antes de implementar.
7. Rode o checklist de `anti-patterns.md` como última etapa, sem exceções.
8. Se precisar justificar uma escolha citando um app de referência, use `references.md` para articular o *princípio*, nunca para copiar o *pixel*.

Esta skill deve evoluir junto com o Evergreen. Se uma decisão de design nova for tomada em conversa com o usuário e ela contradiz algo escrito aqui, atualize o arquivo relevante — não deixe a skill ficar desatualizada em relação ao produto real.

# Motion

## Princípio central

Motion no Evergreen existe para **explicar uma mudança de estado**, nunca para demonstrar capacidade técnica ou "impressionar". A pergunta antes de animar qualquer coisa: *sem essa animação, a pessoa entenderia menos o que aconteceu?* Se a resposta é não, a animação deveria ser mais curta, mais discreta, ou simplesmente não existir.

Apps como Raycast, Linear e Arc são percebidos como "fluidos" não porque têm muita animação, mas porque toda animação que existe é **curta, previsível e nunca compete com a ação do usuário**. Fluidez é sobre ausência de fricção perceptível, não sobre quantidade de movimento.

## Durações

Trabalhe com uma escala pequena de durações, quase sempre entre 100–300ms — motion de interface desktop é sempre mais curto que motion de app mobile ou site, porque a expectativa de resposta é mais imediata em desktop:

| Categoria | Duração | Exemplos |
|---|---|---|
| Micro-feedback | 80–120ms | Hover de botão, mudança de cor em estado pressed, foco de input |
| Transição de estado pequena | 120–180ms | Abrir/fechar dropdown, expandir/colapsar item de lista, aparecer/sumir de badge |
| Transição de painel | 180–260ms | Abrir sidebar, trocar de aba, mostrar painel de detalhe lateral |
| Modal/popup de destaque | 200–280ms | Abrir modal, abrir popup de contexto maior |
| Nunca ultrapassar | ~320ms | Qualquer coisa acima disso já parece lenta para uso repetido no dia a dia |

Regra prática: **animações de saída são sempre iguais ou mais rápidas que as de entrada**. A pessoa quer voltar ao trabalho mais rápido do que quer "admirar" a chegada de um elemento.

### Tokens implementados (`AppDurations`)

| Token | Valor | Uso |
|---|---|---|
| `instant` | 90ms | hover, pressed, anel de foco, rolagem que revela a seleção |
| `entrance` | 120ms | fade de entrada de superfície flutuante (overlay do Pin) |
| `fast` | 150ms | transição de estado pequena (badge que muda de cor) |
| `medium` | 220ms | transição de layout (painel do overlay que alarga com o preview) |
| `curve` | `easeOutCubic` | curva padrão de tudo que entra ou muda de estado |

Não existe token de saída porque **saída não anima**: fechar é instantâneo.

### Decisão do produto: entrada e saída do overlay do Pin

O painel do Pin **entra** com um fade de 120ms (`easeOut`) e **sai instantaneamente** — a janela simplesmente se esconde, sem animação de volta.

Por quê: o Pin é invocado dezenas de vezes por dia e usado por segundos. Um fade curto na chegada evita o "pop" seco de um painel aparecendo do nada sobre outro app (e cobre o instante em que o macOS ainda está trocando o foco); qualquer animação na saída, por outra, seria tempo entre a pessoa escolher o item e voltar a digitar no app de origem. É a aplicação literal de "instantâneo antes de suave".

Sem movimento de posição/escala junto do fade: o painel nasce onde vai ficar. Deslizar de cima competiria com a lista, que é o que a pessoa está lendo assim que o painel aparece.

## Easing

- Use easing do tipo "ease-out" (rápido no início, desacelerando suavemente no fim) para elementos que **entram** na tela — isso comunica "chegou com intenção e se acomodou".
- Use "ease-in" (começa devagar, acelera) para elementos que **saem** — comunica "está indo embora, sem hesitação".
- Evite curvas de bounce/elastic/spring exageradas — um leve spring sutil pode ser aceitável em um único lugar muito específico (ex: um pequeno "settle" ao soltar um item de drag-and-drop), mas nunca como padrão geral de toda a interface. Bounce excessivo é um dos sinais mais reconhecíveis de "motion de app genérico/consumer", incompatível com a seriedade funcional do Evergreen.
- Nunca use "linear" (velocidade constante) para transições de UI — isso é perceptivelmente mecânico e "não natural" ao olho humano, mesmo que a diferença pareça sutil no papel.

## Hover

- Hover responde **instantaneamente ou quase** (transição de 80–100ms) — hover é feedback de exploração, e qualquer atraso perceptível nele faz a interface parecer "pesada".
- Mudança de hover é sutil: leve alteração de superfície (cor de fundo um degrau acima do repouso) ou leve aumento de opacidade em ícones que estavam semi-transparentes — nunca mudança de tamanho/escala do elemento (escalar elementos no hover, tipo "cresce ao passar o mouse", é um padrão de site de e-commerce/marketing, não de ferramenta desktop).
- Cursor deve mudar apropriadamente (pointer em elementos clicáveis) simultaneamente à mudança visual de hover.

## Click / Active / Pressed

- Estado pressed é visualmente mais escuro/mais opaco que hover, aplicado **imediatamente** ao toque (sem delay, sem transição de entrada — o feedback de "eu registrei seu clique" precisa ser instantâneo).
- A transição de volta ao estado normal após soltar o clique pode ter uma transição curta (80–120ms) para não parecer um "piscar" abrupto.
- Nunca anime escala/tamanho no click (efeito "clique aperta o botão que encolhe") — de novo, isso é linguagem de app mobile consumer, não de ferramenta desktop.

## Foco (teclado)

- Mudança de foco por teclado (Tab, setas de navegação) deve ser instantânea ou quase instantânea (menos de 100ms) — navegação por teclado é sobre velocidade, e um anel de foco que "desliza" lentamente entre elementos atrapalha usuários rápidos de teclado.
- O indicativo visual de foco (outline/ring na cor de destaque) pode ter uma transição de opacidade muito curta (60–80ms) para não parecer que "pisca" de forma abrupta, mas nunca desliza fisicamente de posição em posição.

## Transições estruturais (painéis, abas, listas)

- **Abrir/fechar sidebar ou painel lateral**: desliza no eixo apropriado (translateX/Y) combinado com fade sutil, 180–240ms, ease-out na entrada.
- **Trocar de aba/seção**: prefira fade cross-dissolve curto (120–160ms) em vez de slide, a menos que a navegação tenha uma ordem espacial clara (como abas horizontais onde a pessoa "sabe" que está indo para a direita ou esquerda) — nesse caso um slide sutil na mesma direção reforça a orientação espacial.
- **Expandir/colapsar item de lista** (accordion, seção recolhível): anima a altura com ease-out, 150–200ms, e o conteúdo revelado aparece com um fade leve levemente atrasado (10–20ms) em relação ao movimento de altura, para não parecer que "texto vaza" antes do espaço existir.
- **Reordenação de lista (drag-and-drop)**: os itens vizinhos se deslocam suavemente (150–180ms, ease-out) para abrir espaço conforme o item arrastado se move — nunca "pulam" instantaneamente de posição.
- **Aparecer/sumir de item em lista dinâmica** (ex: resultado de busca aparecendo enquanto digita): fade + leve movimento vertical de poucos pixels (4–8px), 100–150ms — sutil o suficiente para não distrair de uma lista que está atualizando a cada tecla digitada.

## Loading e estados assíncronos

- No produto, o atraso implementado é de **200ms** (`_Loading`, no overlay do Pin): o banco é local, então o spinner quase nunca chega a aparecer — que é exatamente o objetivo. O bloco reserva a altura desde o início, para o painel não mudar de tamanho quando o indicador aparecer.
- Prefira **não mostrar nada por um breve instante** (até ~150–200ms) antes de mostrar qualquer indicador de carregamento — a maioria das operações do Evergreen deve ser rápida o suficiente para que um spinner nunca chegue a aparecer; mostrar um spinner que pisca por 50ms e some é pior do que não mostrar nada.
- Quando o carregamento realmente demora, use indicadores discretos e nativos (um spinner pequeno, uma barra de progresso fina) — nunca skeletons elaborados e coloridos ou telas de loading "de marca" com logo animado. Esse tipo de loading grandioso é característico de apps consumer/web, não de ferramentas desktop utilitárias.
- Ver `components.md` para a especificação visual completa de indicadores de loading.

## O que NUNCA fazer em motion

- Parallax de qualquer tipo.
- Animação de entrada de página inteira tipo "elementos aparecem um a um em cascata" (stagger dramático) — aceitável apenas em quantidades muito pequenas (2–3 itens) e com atraso mínimo entre eles (20–40ms), nunca como espetáculo.
- Ícones ou ilustrações com "vida própria" (flutuando, pulsando) fora de um indicador de status genuíno (ex: um ponto pulsando suavemente para indicar "gravando" é aceitável porque comunica um estado real; um ícone decorativo pulsando sem motivo não é).
- Transições com física de mola (spring) exagerada aplicadas indiscriminadamente em todo o app.
- Qualquer animação que bloqueie a interação da pessoa com a interface enquanto ela ainda está rodando — o app deve permanecer responsivo durante toda transição.

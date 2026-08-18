# Tipografia

## Princípio central

Tipografia é a hierarquia. Em um app desktop denso como o Evergreen, a diferença entre uma tela clara e uma tela confusa é decidida quase inteiramente por tamanho, peso e cor de texto — antes mesmo de qualquer outro elemento visual entrar em cena.

## Fonte

Use a fonte de sistema nativa do macOS (a família San Francisco, acessível via as configurações padrão de fonte do sistema no Flutter/macOS) como primeira escolha, para que o Evergreen tenha a mesma sensação de nitidez e otimização de renderização que qualquer outro app nativo da plataforma. Se uma fonte customizada for necessária por identidade de marca, ela deve:

- Ter excelente legibilidade em tamanhos pequenos (13–14px), já que boa parte da interface roda nessa faixa.
- Ter uma variante mono compatível para dados, atalhos de teclado e conteúdo técnico.
- Não competir visualmente com a fonte de sistema usada pelo resto do macOS ao redor da janela — o Evergreen deve parecer parte do sistema operacional, não um mundo visual à parte.

Nunca misture mais de uma família de fonte para texto de interface (fora do par principal + monoespaçada). Múltiplas famílias sem propósito é um sinal clássico de falta de decisão editorial.

### Decisão do produto: Inter com fallback para SF

O Evergreen declara **Inter** como família de interface, com fallback em cascata para a fonte do sistema — `SF Pro Display` → `SF Pro Text` → `.AppleSystemUIFont` → `Helvetica Neue`. A mono é **SF Mono**, com fallback para `Menlo`.

Por quê: a Inter foi desenhada para UI em tamanho pequeno e é quase indistinguível da SF nas métricas que importam aqui (altura-x, largura de dígito, terminações), então o app tem identidade própria **sem** parecer estrangeiro ao lado das janelas do sistema. E como o fallback nativo entrega a leitura correta, o arquivo da Inter não precisa estar empacotado para o app parecer certo — a decisão não custa peso de bundle nem risco de renderização.

Não troque a família sem um motivo de legibilidade. "Ficaria mais moderno" não é motivo.

## Escala tipográfica

Trabalhe com uma escala pequena e disciplinada — poucos tamanhos, usados de forma consistente, é mais importante que uma escala "completa". Uma referência de estrutura (ajuste valores exatos no design system real do projeto, mas mantenha a lógica de papéis):

| Papel | Tamanho aproximado | Peso | Uso |
|---|---|---|---|
| Título de janela/seção | 15–17px | Semibold | Cabeçalhos de painel, título de modal |
| Corpo padrão | 13–14px | Regular | Texto de leitura, itens de lista, conteúdo principal |
| Corpo enfatizado | 13–14px | Medium/Semibold | Nome/título dentro de um item de lista, valor principal em vez de label |
| Secundário/metadado | 11–12px | Regular | Timestamps, contadores, texto de apoio abaixo do título |
| Rótulo pequeno/caps | 10–11px | Medium, tracking levemente positivo | Labels de seção em maiúsculas (ex: "RECENTES", "HOJE") |
| Monoespaçada | 12–13px | Regular | Atalhos de teclado, valores técnicos, código |

Evite tamanhos grandes e decorativos (24px+) exceto em contextos muito específicos e raros, como o título de uma tela de boas-vindas/onboarding inicial (que deve ser mínima) ou um número de destaque isolado (ex: contador grande em um dashboard interno simples). Um app de produtividade não tem "títulos heroicos" espalhados pelas telas.

### Escala implementada (`AppTypography`) — valores oficiais do produto

Nada de `copyWith(fontSize: ...)` em widget: se falta um degrau, ele entra aqui como token nomeado.

| Token | Tamanho / peso | Uso |
|---|---|---|
| `screenTitle` | 17 / 600, tracking -0.2 | maior texto do app — cabeçalho de painel do Hub |
| `sectionTitle` | 15 / 600 | cabeçalho de seção |
| `panelTitle` | 15 / 600 | título de painel compacto e de diálogo |
| `body` | 14 / 400 | corpo padrão, texto digitado no campo de busca |
| `bodyEmphasis` | 14 / 500 | título dentro de uma linha, valor em vez de rótulo |
| `bodyStrong` | 14 / 600, tracking -0.2 | nome próprio numa linha — a marca no rodapé da sidebar |
| `bodyCompact` | 13 / 400 | corpo dentro do overlay, conteúdo do preview |
| `bodyCompactEmphasis` | 13 / 500 | título de linha de lista, rótulo de configuração, título de empty state |
| `caption` | 13 / 400, secundário | tagline de módulo, texto de apoio |
| `captionSmall` | 12 / 400, secundário | descrição de linha de configuração, texto de empty state |
| `captionSmallEmphasis` | 12 / 600, secundário | a opção escolhida de um segmented control |
| `captionXS` | 11 / 400, secundário | timestamp de linha, rótulo de dica de atalho, subtítulo de sidebar |
| `overline` | 11 / 600, caps, tracking +0.66 | label de seção ("FIXADOS", "GERAL") |
| `button` | 14 / 600 | rótulo de botão |
| `timer` | 36 / 500, tabular | contagem regressiva do Focus — a exceção do "número de destaque isolado" |
| `mono` | 12 | conteúdo técnico monoespaçado |
| `monoSmall` | 11 | key-cap, badge de atalho na linha |

`timer` é a única entrada acima de 17 e existe sob condição: o número tem que
ser o **conteúdo** da tela, não um enfeite dela. Peso 500 (não 600, que em 36px
grita) e `FontFeature.tabularFigures()`, senão a linha dança a cada segundo.

O topo da escala (17) fica a **um** degrau do corpo (14), não a três: é o que impede o "título heroico" de voltar por acidente. Hierarquia dentro de um mesmo bloco se faz por **peso** (400 → 500 → 600), não por tamanho — daí os pares `body`/`bodyEmphasis` e `bodyCompact`/`bodyCompactEmphasis`. Peso 700 não existe mais na escala.

## Peso e hierarquia

- Prefira variar **peso** (regular → medium → semibold) antes de variar **tamanho** para estabelecer hierarquia dentro de um mesmo contexto (por exemplo, dentro de uma linha de lista). Duas linhas de texto do mesmo tamanho mas pesos diferentes comunicam hierarquia sem ocupar mais espaço vertical — crucial para densidade de informação.
- Bold pesado (700+) é raro e usado com moderação extrema — normalmente reservado para números/contadores de destaque pontuais, nunca para texto corrido ou títulos de seção recorrentes.
- Itálico é praticamente ausente da interface — não é uma convenção nativa forte no ecossistema macOS de produtividade e tende a parecer "editorial" fora de contexto de escrita longa (Craft sendo a exceção, onde é uma opção de formatação de conteúdo do usuário, não da interface do app).

## Tracking e leading

- Títulos de seção em caixa alta (labels tipo "RECENTES") usam tracking levemente positivo (letter-spacing sutil) para compensar a leitura mais difícil de maiúsculas em tamanho pequeno.
- Corpo de texto normal usa tracking neutro (padrão da fonte) — tracking apertado artificialmente para "parecer mais compacto" prejudica legibilidade e não deve ser usado.
- Leading (altura de linha) em texto corrido de interface fica geralmente entre 1.3–1.5x o tamanho da fonte; em listas densas de uma linha só, aproxime-se de 1.2x para não desperdiçar altura vertical desnecessária.

## Truncamento e overflow

Em uma interface densa, texto que não cabe é constante — trate isso com intenção, nunca deixando quebrar layout:

- Truncar com reticências (`…`) no fim da linha é o padrão para títulos/nomes de item em listas de uma linha.
- Para textos onde o começo importa mais que o fim (caminhos de arquivo, URLs), considere truncar no meio.
- Nunca deixe texto colidir com outro elemento ou vazar da área alocada — isso é o erro visual mais rapidamente perceptível como "não polido".

## Números e dados

- Use algarismos tabulares (largura fixa por dígito) sempre que números aparecerem em colunas ou mudarem dinamicamente (contadores, timers, valores que atualizam) — evita que o layout "pule" horizontalmente a cada atualização.
- Contadores/badges numéricos usam peso medium/semibold para se distinguir do texto ao redor mesmo em tamanho pequeno.

## Cor de texto conforme papel (referência cruzada com `colors.md`)

- Título/corpo principal → `text/primary` (`AppColors.textPrimary`).
- Metadado/apoio → `text/secondary` (`AppColors.textSecondary`).
- Placeholder, desabilitado, timestamp discreto → `text/tertiary` (`AppColors.textTertiary`).

Os tokens de `caption*` já nascem em `textSecondary`; para o terceiro nível, componha (`captionXS.copyWith(color: AppColors.textTertiary)`), como faz o timestamp da linha do Pin.

`copyWith` em widget vale **só para cor** — tamanho, peso e tracking são degraus da escala, e degrau novo entra aqui com nome. Foi assim que `bodyStrong` e `captionSmallEmphasis` nasceram: os dois já existiam escritos à mão dentro de um widget, que é como um degrau aparece no produto sem ninguém ter decidido que ele existe.

Nunca use a cor de destaque (accent) em texto corrido apenas para chamar atenção — reserve accent em texto para links/referências clicáveis reais, mantendo o princípio de "cor como significado" também na tipografia.

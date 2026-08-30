# Redesign "Estufa" — progresso da execução

Branch: `feat/redesign-estufa` (a partir da `main`).
Especificação: [`redesign-estufa.md`](redesign-estufa.md).
Retrato do estado anterior: [`brief-redesign-visual-v2.md`](brief-redesign-visual-v2.md).

**Baseline antes de começar:** `flutter analyze` sem issues, 635 testes passando,
10 pulados.

## Como retomar

Ler a tabela de fases abaixo, achar a primeira linha que não está `feito`, e
continuar dali. Cada fase fecha com `flutter analyze` + `flutter test` verdes e
um commit próprio.

## Fases

| # | Fase | Estado |
|---|---|---|
| 0 | Branch + documentos + progresso | feito |
| 1 | Tokens: paleta, tipo, formas, elevação, degradês, motion, squircle | feito |
| 2 | Matriz de estados (`EgSurfaceStyle`) + famílias novas | feito |
| 3 | Componentes compartilhados (novos + reescritos) | feito — falta `EgEmptyState` e `EgKeyHintBar`, que vão com os painéis |
| 4 | Painéis flutuantes: vidro, hairline, barra de teclas | feito |
| 5 | Hub: sidebar + cabeçalho de tela + grade de duas colunas | feito |
| 6 | Telas: Pin, Leaf, Awake | feito |
| 7 | Telas: Focus, Echo, Nest | feito no Hub; falta o conteúdo dos painéis flutuantes |
| 8 | Telas: Track, Aplicativo | feito |
| 9 | Goldens novos + skill de design atualizada | feito |

## O que a fase 1 e a 2 deixaram pronto

- `EgPalette` com 35 papéis: neutros de `#0B` a `#36`, o vidro (`glassPanel`,
  `glassRow`, `glassControl`), as duas cores de dado (`ember`, `tide`), a luz
  (`edge`, `edgeLight`, `sidebarTint`) e o anel de foco branco. Saíram
  `selection`, `selectionLabel`, `selectionEdge`, `accentGradient`,
  `selectionGradient`, `sidebar` e as quatro cores de sistema.
- `EgTypeScale` com `display` (30) e `title` (20) no topo, mais `footnote`,
  `keycap` e `timerSmall`; `overline` passou a SF Mono.
- `EgShapes` com o squircle: `EgSquircle.shape` devolve
  `ContinuousRectangleBorder` acima de 14 e o arco de sempre abaixo. Toda
  superfície interativa passou a `ShapeDecoration`.
- `EgElevations` com `panelInnerHairline` e `rowInnerHairline` — a linha de luz
  que substituiu a aresta verde de 3 px.
- `EgMotion` com `stack` (160 ms) e curva `easeOutQuint`.
- Matriz de estados com as dez famílias da §5, incluindo `sidebarItem`,
  `glassRow`, `glassControl` e `neutralStrong`.
- `EgButton` com altura fixa (32, ou 26 no `compact`), a variante
  `neutralStrong` e a tecla impressa dentro (`keycap`).
- O tema `apple` foi apagado, junto com `AppThemeId`, o `ThemePicker`, a chave
  `app.theme` e a bandeira `themes`. A preferência guardada no disco continua
  lá, intocada.

**Estado da suíte ao fim da fase 2:** `flutter analyze` sem issues, 633 testes
passando, 10 pulados. Os goldens ainda são os antigos — a fase 9 os regera.

## O que falta, e o que é feature nova (não redesenho)

A especificação descreve alguns ajustes que **ainda não existem no código**.
Redesenhar não é inventá-los, então eles ficam anotados aqui em vez de nascerem
calados:

- **Leaf** — "Copiar e fechar" e "Tamanho do texto do cartão" (§4.5) são
  preferências novas: pedem modelo, repositório e ViewModel.
- **Awake** — "Gatilhos" (§4.6: ligar ao espelhar a tela, ligar durante gravação
  do Echo) é comportamento novo, com detecção de espelhamento no lado nativo.
- **Pin** — a aba `Tipos` (§4.2) supõe ligar e desligar tipos na captura; hoje o
  classificador grava todos. É o próximo passo pedido, e toca
  `PinSettings` (um conjunto de tipos), o repositório de preferências e o
  serviço de captura. O gerador de CPF/CNPJ **já entrou**, como cartão dentro
  das preferências (e não como aba própria).
- **Nest** — cor por destino e reordenação por arraste (§4.7) são dados novos na
  tabela de destinos.

**A faixa de estado de Focus, Awake, Echo e Nest depende de uma ponte entre
engines.** O que está rodando vive no engine da janela 0, e o Hub é outro
engine: hoje ele não tem como saber que há uma sessão em curso. O Leaf funciona
porque a parede está no disco e o Hub relê (como o Track já fazia). Os outros
quatro precisam de um canal, no mesmo arranjo do `EchoSummaryStatus`.

## Decisões tomadas na execução

### Divergências entre a especificação escrita e as imagens de referência

As imagens são referência de **layout**; onde elas contrariam uma regra que a
especificação justifica por escrito, vale a especificação.

1. **Filtro de lista (Pin, Echo).** As imagens põem as pílulas de filtro na mesma
   linha do campo de busca. A especificação (§4.2) as põe **abaixo**, com o
   motivo: na mesma linha elas somem quando o texto da busca cresce. Vale a
   especificação.
2. **Focus no Hub.** A imagem `1d` mostra `Pausar` e `Encerrar sessão` dentro do
   Hub. O invariante 8.7 diz que função que existe no painel **não** existe no
   Hub. Vale o invariante: o Hub fica com o bloco-instrumento visual da imagem
   (anel, blocos do ritmo, "o que estou fazendo") **sem os botões** — é leitura,
   não operação. A faixa de estado da §3.7 é o que dá o caminho de volta.

### Tema `apple`

A especificação (§7) recomenda apagar. Com todo campo de token `required`, manter
o segundo tema dobra o custo de cada papel novo, e a flag `themes` está
desligada. Decisão: **apagar**, junto com `AppThemeId`, o `ThemePicker` e a flag
`themes`.

## Detalhes tirados das imagens de referência

Não estavam na especificação escrita e entram na implementação:

- **Sidebar** — linha da marca no topo (`canivete + "Evergreen" + versão à
  direita`), acima do primeiro grupo. Os controles de janela do macOS ficam
  sobre ela.
- **Focus (Hub)** — o bloco-instrumento tem, além do anel: `O QUE ESTOU FAZENDO`
  (overline), o texto da sessão, e uma **fileira de blocos do ritmo** (foco
  cumprido em verde, o corrente em `ember`, os futuros vazios).
- **Echo (painel, gravando)** — duas faixas de onda rotuladas `VOCÊ` (verde) e
  `SISTEMA` (`tide`), e uma caixa `ÚLTIMA FALA` com a citação corrente. Rodapé
  em mono: "tudo processado neste Mac · Apple Intelligence".
- **Nest (painel)** — badge verde de contagem **sobre** o canto do bloco da
  pilha; a caixa de destino mostra chip de cor + caminho + `⌥1`; abaixo da fila,
  a linha "a pilha guarda a ordem · arraste pra reordenar".
- **Leaf (painel)** — cabeçalho próprio: `Leaf` + "aperte o número pra copiar" à
  esquerda, `5 de 9 usados` à direita.
- **Track (Hub)** — a pílula `nada é gravado aqui` fica no lugar do interruptor
  mestre, no cabeçalho.
- **Aplicativo** — subtítulo com `versão · N módulos · banco local de N MB`.

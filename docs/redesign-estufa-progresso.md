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
| 1 | Tokens: paleta, tipo, formas, elevação, degradês, motion, squircle | a fazer |
| 2 | Matriz de estados (`EgSurfaceStyle`) + famílias novas | a fazer |
| 3 | Componentes compartilhados (novos + reescritos) | a fazer |
| 4 | Painéis flutuantes: vidro, hairline, barra de teclas | a fazer |
| 5 | Hub: sidebar + cabeçalho de tela + grade de duas colunas | a fazer |
| 6 | Telas: Pin (abas), Leaf, Awake | a fazer |
| 7 | Telas: Focus, Echo, Nest | a fazer |
| 8 | Telas: Track, Aplicativo | a fazer |
| 9 | Goldens novos + skill de design atualizada | a fazer |

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

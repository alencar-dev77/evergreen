# O gerador de CPF — o dia em que o Pin passou a escrever

> Painel do Pin (`⌘⇧C`) → pílula "CPF" → linha "Gerar CPF".

Até aqui o Pin fazia uma coisa só: guardar o que passou pela área de
transferência e devolver. Todo o desenho segue disso — a lista é histórico, o
Enter copia, o classificador *lê* o conteúdo para decidir o que ele é. O gerador
de CPF é a primeira coisa que o painel **produz**, e foi ela que empurrou três
decisões que valem estar escritas.

## A conta saiu do classificador

Validar e gerar um CPF são a mesma soma ponderada módulo 11 — uma comparando o
resultado com o que está escrito, a outra anexando o resultado ao que ainda não
tem. Ela morava privada dentro do `ClipboardItemClassifier`, que só precisava
responder "isto é um CPF?".

Duas cópias do mesmo módulo 11 é o tipo de coisa que se desencontra em silêncio:
o gerador passaria a produzir números que o próprio Pin guardaria como texto, e
a linha sumiria do filtro que a desenhou. Por isso a conta virou `TaxId`
(`lib/features/pin/models/tax_id.dart`), e o classificador delega. O que prende
isso é um teste que gera mil números e passa cada um pelo classificador.

A versão do classificador **não** subiu: o comportamento não mudou, só o
arquivo. Subir custaria uma reclassificação do histórico inteiro à toa.

## A pílula do CPF está sempre na fila

A fila de pílulas oferecia só os tipos presentes no histórico, e a regra era boa:
um filtro sem o que mostrar é uma promessa vazia. Ela quebra aqui pelo motivo
mais simples possível — **só se copia um CPF depois de ter um**. Com a regra
antiga o gerador nasceria escondido de quem nunca copiou nenhum, que é
exatamente quem precisa gerar.

Junto foi o `hasTypeFilter`, que exigia dois tipos ("Tudo | Textos" eram dois
botões para a mesma lista). Também deixou de valer: a pílula do CPF nunca é a
mesma coisa que "Tudo", porque atrás dela há um número que ainda não existe. E
era esse o caso a resolver, não uma hipótese — quem acabou de gerar o primeiro
CPF tem um histórico só de CPF, e a fila sumiria justamente ali, levando o
gerador junto.

## `selectedIndex == -1` tem dois sentidos

A linha do gerador fica acima do primeiro item e é alcançada pelo `↑`. Ela não
entra em `results`: seria um não-item atravessando a busca, o ranking, os
atalhos numéricos e o preview, todos obrigados a desviar dela. Em vez disso ela
é o índice `-1`, que já existia significando "nada selecionado".

Os dois sentidos convivem porque `selectedItem` devolve `null` nos dois casos —
e é isso que faz `⌘P`, `⌘R`, `⌘⌫` e o `tab` saírem sozinhos com o gerador
selecionado, sem nenhum deles precisar saber que ele existe. Quem separa um
sentido do outro é `hasGenerator`.

O preço está em `pin_result_list.dart`: os cabeçalhos de grupo usavam `-1` como
"não estou em `results`", e `_revealSelection` acha a linha selecionada
comparando esse número. Passaram a usar `_noIndex = -2`. Sem isso a rolagem
levaria a um cabeçalho no lugar do gerador — e teria quebrado calada.

## O que o gerado é depois de copiado

Nada de especial: `Enter` copia e fecha, o número passa pelo mesmo `copyItem`
dos itens da lista e entra no histórico como qualquer cópia — classificado como
CPF, recuperável por `⌘1` na abertura seguinte. Um item ainda sem `id` é o que a
captura já produz, e o `upsert` resolve pelo conteúdo; por isso o gerador não
precisou de nada novo no repositório.

`⌘G` sorteia outro sem fechar. O número vive no estado, não no widget, porque
quem decide quando ele muda é a ViewModel: `⌘G` troca, digitar na busca não —
um número que trocasse a cada tecla seria ilegível para quem está conferindo
dígito a dígito.

E o clique na linha copia e fecha, contra a regra do painel de que clicar abre o
preview. A regra existe para quem chega pelo mouse poder ver o conteúdo antes de
decidir; aqui o conteúdo inteiro já está escrito na linha, e não há um "dentro"
para abrir.

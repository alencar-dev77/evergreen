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

## O CNPJ, depois

O CNPJ entrou como par do CPF, e a decisão que importa é que ele **não ganhou
nada próprio**: nem arquivo, nem widget, nem tecla.

- **A conta.** `TaxId._checkDigit` já era a soma ponderada módulo 11 partilhada
  entre validar e gerar. CPF e CNPJ divergem só nos pesos — o CPF desce de 10 a
  2 sem repetir, o CNPJ desce de 9 a 2 e dá a volta, porque doze dígitos não
  cabem numa faixa de oito. Isso virou `TaxIdKind.weightAt`, e o resto do
  arquivo não soube da diferença. O `(soma * 10) % 11` do CPF virou
  `11 - resto`: dão o mesmo número (multiplicar por dez, módulo onze, é o mesmo
  que negar) e é a forma que a Receita publica para os dois.
- **A linha.** `PinGeneratorRow` recebeu um `TaxIdKind` e tira dele o rótulo, o
  ícone e o texto do leitor de tela. Duas classes iguais menos por três palavras
  se desencontrariam no primeiro ajuste de altura.
- **A tecla.** `⌘G` continua sendo uma só. Qual documento sortear é o filtro que
  diz — a mesma tecla dentro da pílula CNPJ devolve um CNPJ. Um segundo atalho
  para "gerar CNPJ" seria uma tecla a decorar por uma escolha que a tela já fez.

O que precisou de campo novo foi só um: `_generatedKind`, na ViewModel. O número
é preservado *dentro* de um filtro (sortear a cada tecla digitada na busca
trocaria o número embaixo do dedo de quem está conferindo dígito a dígito), e
sem saber de qual documento ele é, sair do CPF e entrar no CNPJ deixaria o CPF
sorteado escrito na linha "Gerar CNPJ". `state.generatedTaxId` é uma `String`, e
quando se pergunta o filtro já mudou.

E `ClipboardItemClassifier.version` **subiu para 3**, ao contrário do que o
gerador de CPF fez: ali nada mudou na classificação, só o arquivo em que a conta
morava. Aqui há um tipo novo — sem a subida, todo CNPJ já copiado continuaria
guardado como texto, e a pílula nasceria vazia justamente para quem tem
histórico. O enum passou de `taxId` a `cpf` na mesma leva; a reclassificação que
a versão dispara reescreve o nome guardado, então a troca não deixa linha órfã.

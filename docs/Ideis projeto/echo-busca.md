# Echo, a busca nas reuniões

> Status: **implementado** em 14/10/2026. Código em
> `lib/features/echo/models/meeting_search.dart` (o domínio),
> `lib/features/echo/presentation/widgets/echo_search_box.dart` e
> `echo_search_results.dart` (a tela), e no `EchoMeetingDetail` (a leitura que
> obedece o salto).

## Por que fora de cada reunião

A primeira ideia foi uma busca dentro da leitura de cada reunião. Ela responde
à pergunta errada. Quem procura quase nunca sabe *em qual* reunião algo foi
dito: a pergunta é "quando falamos do orçamento, e quem disse?", e não "o que a
reunião de terça disse do orçamento?". Por isso a busca fica no topo do cartão
"Reuniões" e procura em todas de uma vez, nos títulos, nos resumos e no que foi
dito. Os resultados entram no lugar da lista enquanto há texto no campo.

## Como ela acha

- **Sem acento e sem maiúscula.** O `TextFold` dobra o texto caractere por
  caractere, **sem mudar o comprimento**. É o que permite achar no texto
  dobrado e grifar no original, com acento: a posição serve nos dois.
- **Pelo começo da palavra.** "orcam" acha "Orçamento", e a lista reage
  enquanto se digita. "custo" não acha "acusto": casar no meio da palavra
  devolveria metade do histórico para qualquer sílaba.
- **Todas as palavras na mesma reunião, em qualquer lugar dela.**
  "orçamento sexta" acha a reunião que falou do orçamento num minuto e da sexta
  no outro.
- **A partir da segunda letra.** Uma letra solta não entra na busca: "a", "e"
  e "o" começam metade das palavras do português, e uma letra sozinha casaria
  com todas as reuniões. Seria uma resposta que não responde nada, e a mais
  cara de calcular. Até a segunda letra fica a lista de sempre.
- **A ordem**, do mais forte para o mais fraco:
  1. todas as palavras no título;
  2. todas num trecho só;
  3. as palavras juntas e na ordem digitada;
  4. o número de trechos, com teto de dez.

  No empate vence a mais recente. Quem lembra o nome da reunião já disse qual
  é. Duas palavras ditas na mesma fala são quase sempre o assunto; ditas a
  vinte minutos uma da outra, coincidência.

O índice dobra o texto uma vez por lista de reuniões e cada tecla só compara.
Cada reunião guarda também o texto inteiro dobrado, para a recusa rápida: a
palavra que não aparece em lugar nenhum dela dispensa olhar trecho por trecho.
Grifar e contar as palavras de um trecho é uma passada só. O recorte do
trecho nunca corta um emoji ao meio, porque as posições são de UTF-16 e o
Flutter se recusa a desenhar meio caractere.
Ele se refaz quando a lista muda de verdade (renomear, apagar, um resumo novo)
ou quando muda o nome de quem usa, que entra no rótulo dos trechos.

## O que ela mostra

Uma reunião por bloco. A linha da reunião traz o título, com o grifo no que
casou, e quando foi. Embaixo vêm até três trechos, cada um com o minuto numa
coluna fixa, quem falou ("Pessoa 2", "Lucas", "Resumo") e o pedaço da fala em
volta do termo, cortado numa palavra inteira. O que não coube é contado ("mais
4 trechos, grifados na leitura"), e no topo vai o tamanho da resposta ("7
trechos em 3 reuniões").

Quando nada casa, a tela diz o que foi procurado e onde a busca olhou. Não há
ilustração nem botão: a saída é apagar uma letra, e o cursor já está no campo.

## Abrir é ir até o trecho

Enter ou clique abre a reunião na face do trecho (resumo ou transcrição), com a
fala à vista um terço abaixo do topo, o termo marcado e o áudio **parado** onde
a palavra soa. O espaço seguinte toca dali. Tocar sozinho seria áudio
começando sem ninguém pedir.

O pedido é um `EchoJump`, com número de série. A leitura e o player o obedecem
uma vez por pedido. Abrir o mesmo trecho de novo é outro pedido, e um quadro
que chegue com o pedido antigo não arranca a leitura de onde a pessoa rolou.
`select`, que é a escolha pela lista, esquece o pedido. Sem isso, reabrir a
reunião pela lista voltaria ao trecho de uma busca já largada.

O player nasce com a leitura, e a leitura nasce *por causa* do salto. Por isso,
ao nascer, o player adota o salto que encontrar de pé, além de escutar os
seguintes.

## Dois grifos

- **Na lista, a cor da letra (accent)**, como na busca do Pin: o grifo aparece
  em muitas linhas ao mesmo tempo, e um fundo em cada uma viraria um mosaico.
- **Na leitura, o fundo `findMark`** (branco a 16%), o "buscar na página".
  Ali a cor da letra já é do áudio (verde é o que já foi dito), e as duas
  marcas precisam caber na mesma palavra. O fundo é neutro, e não âmbar como o
  do macOS, porque o âmbar do Evergreen é o `ember`, que significa trabalho em
  curso.

A marca na leitura dura enquanto houver texto no campo. Apagar a busca apaga
as marcas.

## Teclado

`⌘F` leva à busca de qualquer aba do Echo, e só com o Echo ligado. Da aba de
ajustes, ele troca de aba antes, e antes disso tira o cursor do campo em que
estava: sem esse passo, o campo sairia da árvore com o foco na mão, e o
vocabulário digitado nunca seria guardado.

Com o cursor no campo, `↑↓` andam pelos resultados sem dar a volta no fim da
lista, e o leitor de tela anuncia a linha apontada. `Esc` apaga o que foi
escrito; com o campo vazio, ele sobe para o do Hub.

**Abrir é o fim da busca, e o teclado vai para a leitura.** Enter ou clique
tiram o cursor do campo. Com ele lá, o espaço seguinte entraria na busca em vez
de tocar o trecho. Fora do campo, as teclas são as da região: espaço, setas e
S. O `Esc` fecha a leitura, e o `⌘F` volta à busca com o texto selecionado e a
linha apontada onde estava. As linhas não pegam foco, porque não são paradas
do Tab.

Aberta pela busca, a região nasce estreita e alarga junto com a janela (220
ms). Por isso a leitura mira a fala duas vezes: no primeiro quadro e quando a
janela termina de crescer, com o texto já acomodado na largura final.

## O que ficou de fora

- **Busca por sentido.** "Quando falamos de dinheiro?" achar "orçamento"
  pediria embeddings, ou o modelo local por pergunta. O casamento literal com
  prefixo cobre a pergunta que se faz de fato, que é a palavra lembrada.
- **Filtros** (por pessoa, por data). A lista agrupada por dia já responde
  "quando". Filtrar por pessoa esbarra em "Pessoa 2" não ser a mesma pessoa
  de uma reunião para outra.
- **Busca no painel flutuante.** O painel do Echo grava. Ler e procurar é no
  Hub.

# Copiar e exportar a reunião — o que foi decidido e o que foi descartado

> Status: **implementado** em 18/09/2026.
> Hub → Echo → Reuniões → uma reunião aberta, na linha do seletor de aba.

---

## O problema

O Echo transcreve e resume localmente, e o resultado ficava preso dentro do
aplicativo. A transcrição e o resumo são `SelectableText` desde o começo, então
sempre foi possível arrastar o mouse por cima e apertar `⌘C` — mas isso é o
caminho de quem já desistiu de procurar um botão. Um resumo de reunião existe
para ir para algum lugar: um e-mail, uma tarefa, um documento do time.

Faltavam as duas saídas: **a rápida** (a área de transferência) e **a que
sobrevive ao aplicativo** (um arquivo).

---

## As decisões

### Cada botão age sobre a aba aberta, não sobre "a reunião"

A leitura já tem duas faces alternadas por um `EgSegmentedControl` — resumo e
transcrição, uma de cada vez. Um botão único que copiasse "a reunião" teria de
escolher entre as duas por conta própria, e escolheria errado metade das vezes;
dois pares de botões (copiar resumo, copiar transcrição, exportar resumo,
exportar transcrição) seriam quatro controles para uma decisão que o seletor já
tomou.

O par de botões muda de alvo junto com a aba. É por isso que ele mora **na linha
do seletor**, e não no rodapé junto de "Resumir" e "Apagar": o rodapé é o que se
faz com a *reunião*; estes dois são o que se faz com o *documento* que está
aberto, e ver o seletor e as ações na mesma linha é o que torna isso óbvio sem
uma palavra de explicação.

### O que se copia é o que se lê; o que se exporta se apresenta

Copiar entrega só o corpo — sem título, sem data, sem a instrução do resumo.
Quem copia vai colar num e-mail ou num documento que já tem esse contexto.

O arquivo exportado sai sozinho no disco e não tem contexto nenhum, então leva
um cabeçalho: título, data absoluta (`26/08/2026 · 10:05 · 32 min` — nunca
"Hoje", que num arquivo não quer dizer nada no dia seguinte) e o nome da seção.
O resumo leva junto a instrução que o produziu, depois do texto, no mesmo lugar
em que ela está na tela.

A transcrição sai em **turnos**, como a tela a desenha, e não nos trechos crus
do banco — os dois pedidos passam pelo mesmo `MeetingDocument`, que é o que
garante isso.

### Markdown, e por que isso não é "um segundo formato a manter"

O `AGENTS.md` registra que o Evergreen guarda os dados dele para si e não os
traduz para ninguém — e que uma exportação em JSON do banco inteiro existiu e
saiu, porque ninguém abriu o arquivo em programa nenhum e ela cobrava o preço de
um segundo formato.

Isto é outra coisa. Aquilo era o banco inteiro virado dado estruturado, escrito
sem ninguém pedir, para um programa que nunca apareceu. Aqui é **um documento
por vez, pedido no botão, do texto que está na tela** — e nada disto é lido de
volta pelo aplicativo. O `.md` foi escolhido porque se lê igual com e sem
programa que o entenda: aberto no TextEdit continua sendo o texto inteiro, com
os `#` à vista e nada escondido.

### Onde o arquivo cai: `Exportações/`, ao lado de `Backups/`

Mesma razão do backup, e com a mesma consequência. `~/Documents` e `~/Downloads`
são protegidos por TCC desde o Catalina: escrever ali faz o macOS pedir
permissão no meio de um clique em "Exportar", transformando uma ação de um passo
numa caixa de diálogo do sistema — e uma recusa por reflexo deixa a exportação
quebrada sem explicação.

A pasta do aplicativo não pede nada. O custo é ela ser funda demais para alguém
achá-la sozinho, e é por isso que **escrever termina mostrando o arquivo no
Finder** (`open -R`). Aqui a abertura do Finder não é um botão à parte como no
backup: ela é o que completa a ação. De lá a pessoa arrasta para onde quiser.

O nome é `2026-08-26-alinhamento-de-escopo-resumo.md` — data na frente para os
arquivos se ordenarem pela ordem em que as reuniões aconteceram, título sem
acento e com teto de 48 caracteres, face no fim. Nome ocupado ganha sufixo em
vez de ser sobrescrito: exportar a mesma reunião duas vezes é o que se faz
depois de refazer o resumo, e é justamente para comparar um com o outro.

---

## O que foi descartado

### `NSSavePanel` — o "salvar como" de verdade

Seria o gesto mais macOS possível, e o Nest já prova que dá para abrir painel do
AppKit daqui (`NSOpenPanel`, no `NestChannel`). Descartado por desproporção: é
código nativo novo — com as quatro entradas de `project.pbxproj` que todo
arquivo Swift do Runner exige — para resolver o que abrir o Finder já resolve,
e a regra da casa é preferir Flutter puro. Fica registrado como o caminho óbvio
se um dia houver um segundo módulo exportando e a pasta única deixar de servir.

### Confirmar com o nome do arquivo

A primeira versão devolvia `2026-08-26-alinhamento-de-escopo-resumo.md` como
confirmação. São quarenta e tantos caracteres numa região de 480px: o nome era
cortado no meio e empurrava os botões que o produziram para fora da linha. E era
redundante — a janela do Finder abre com o arquivo **selecionado**, e é ela quem
mostra o nome. Ficou "Resumo exportado".

### Confirmação permanente, como no cartão do Leaf

O Leaf mantém o "copiado" no cartão até o painel fechar, e pode: o painel dele
fecha em seguida. A região de leitura do Hub fica aberta pelo tempo que a
leitura durar, e um rótulo fixo dizendo "Resumo copiado" meia hora depois estaria
afirmando algo que já não está acontecendo. Três segundos, e ela também sai ao
trocar de aba ou de reunião — a confirmação é da face que estava aberta.

### Toast flutuante

Peso demais para uma ação que não pode dar errado, e a região de leitura não tem
canto onde ele caberia sem cobrir o que se está lendo.

### Botões de ícone

Caberiam com folga (36px cada, contra ~130 dos dois com texto), e o ✕ da própria
região é um `EgIconButton` com tooltip. Mas o `components.md` é explícito: se o
ícone precisa de tooltip para ser entendido, o ícone falhou — e não existe glifo
de copiar nem de exportar no `EgIconData`, então a alternativa custaria dois
desenhos novos para dizer o que duas palavras já dizem.

O preço de manter texto é que o seletor mais os dois botões não cabem sempre na
mesma linha — numa tela pequena demais para a janela crescer, ou nos 220ms em
que ela ainda está crescendo. A saída é a mesma que o `EgSegmentedControl` já
usa na fila dele: **`Wrap`, não `Row`**. Onde há largura, `spaceBetween` mantém
o seletor à esquerda e as ações à direita numa linha só; onde não há, elas
descem para a linha de baixo em vez de estourar o layout — que seria o mesmo que
escondê-las.

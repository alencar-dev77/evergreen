# Backup do banco — o que foi decidido e o que foi descartado

> Status: **implementado** em 25/08/2026, junto com o Track.
> Preferências do aplicativo → seções "Backup" e "Restaurar".

---

## O problema

O Evergreen não manda nada para lugar nenhum. É a promessa do produto e está
escrita na própria tela de preferências — mas ela tem uma consequência
desconfortável: se o `evergreen.db` se perder, **não há servidor de onde puxar
de volta**. O histórico do Pin, as sessões do Focus, a parede do Leaf e as
reuniões do Echo moram num arquivo só, nesta máquina.

O backup é a resposta a isso. E, pela mesma razão, ele não podia ser uma
integração com nuvem nenhuma: é um arquivo nesta máquina que a pessoa copia
para onde quiser.

---

## As decisões

### Onde: `~/Library/Application Support/<bundle>/Backups/`

`~/Documents/Evergreen` foi a primeira ideia — visível, fácil de achar,
entra no Time Machine da pessoa sem ela pensar. **Descartada por causa do TCC**:
desde o Catalina, escrever na pasta de Documentos faz o macOS pedir permissão,
e o backup automático acontece numa hora que ninguém escolheu. Um pedido de
permissão que aparece sozinho às três da tarde e é recusado por reflexo deixa a
proteção desligada sem ninguém saber que desligou.

A pasta do próprio aplicativo não pede nada. O custo é ela ser invisível no
Finder, e é por isso que a tela mostra o caminho por extenso e tem o botão
"Mostrar no Finder" ao lado.

Vale dizer o que isso **não** protege: um backup na mesma pasta do original
cobre "apaguei sem querer" e "o banco corrompeu", não "perdi o Mac". Para o
segundo caso, a pasta precisa ser copiada para fora — que é o que o botão do
Finder existe para facilitar.

### Como: `VACUUM INTO`, não cópia de arquivo

O banco roda em WAL com **duas conexões abertas** (a janela flutuante e o Hub).
Copiar o `evergreen.db` no disco pegaria o arquivo sem as páginas que ainda
estão no log: o backup nasceria faltando o que foi escrito nos últimos minutos,
e ninguém descobriria até precisar dele.

`VACUUM INTO` pede ao próprio SQLite um banco novo, consistente e compactado,
num arquivo só — sem `-wal` nem `-shm` para acompanhar. Ele também se recusa a
escrever por cima de um arquivo existente, o que é exatamente o que se quer de
um backup.

### Quando: semanal, verificado de seis em seis horas

Sem tarefa agendada no sistema. O Evergreen é um agente de barra de menus que
fica aberto o dia inteiro, então uma verificação barata de tempos em tempos
alcança tanto quem reinicia o Mac todo dia quanto quem passa três semanas sem
desligar. Só a checagem é frequente; o backup é semanal.

Roda no engine da janela flutuante, junto com o cronômetro do Focus e a captura
do Pin, pela mesma razão que eles: a janela de preferências passa a maior parte
do tempo fechada, e um backup que só rodasse com ela aberta não seria
automático.

**"Está na hora?" é respondido pela pasta, não por uma data guardada nas
preferências.** As duas janelas rodam em engines separados e não veem a
preferência uma da outra — mas veem a mesma pasta. De quebra, apagar os backups
à mão volta a pedir um novo, que é o que a pessoa esperaria.

### Quantos: cinco

Um backup semanal sem teto vira um depósito que ninguém revisita e que só
cresce. Cinco cobre mais de um mês — tempo de sobra para perceber que algo se
perdeu. É o mesmo raciocínio do teto de nove anotações do Leaf: o limite é o
produto, não uma limitação técnica.

A limpeza só alcança arquivos com **o nome que o Evergreen escreve**
(`evergreen-2026-08-25-1432.db`). Um arquivo que a pessoa arrastou para a pasta
fica onde está: ela o pôs ali de propósito, e apagá-lo por causa de um teto que
ela não escolheu seria perder justamente o backup que mais importava.

E a data de um backup nosso sai **do nome**, não do `mtime`: copiar a pasta para
outro disco, restaurar de um Time Machine ou sincronizar por alguma nuvem
reescreve a data de modificação, e um backup de março passaria a se apresentar
como de hoje — adiando por uma semana o backup que deveria acontecer agora.

---

## Restaurar

### Sem seletor de arquivo: a pasta é a interface

`file_selector` (ou qualquer plugin de seleção de arquivo) foi descartado por
dois motivos. O primeiro é a regra do projeto de preferir Flutter puro. O
segundo é específico daqui: **o Hub é uma sub-janela**, e sub-janela nasce sem
plugins — o pacote teria que ser registrado à mão no callback de criação em
`MainFlutterWindow.swift`, que é justamente onde esse tipo de coisa quebra em
silêncio.

A lista mostra qualquer `.db` que estiver na pasta, não só os nossos. Trazer um
backup de outra máquina é arrastá-lo para lá — e o botão "Mostrar no Finder"
abre a pasta.

### Tabela a tabela, não trocando o arquivo

As duas janelas têm este banco aberto. Um arquivo substituído por baixo delas
deixaria as duas conexões apontando para um inode que não existe mais.

A restauração então roda `ATTACH` + `DELETE`/`INSERT ... SELECT` dentro de uma
transação só, na conexão viva. Vale na hora, sem reiniciar o aplicativo: os
painéis releem ao abrir e as telas do Hub ao montar.

**As tabelas são descobertas pelo `sqlite_master`, não escritas à mão.** A
tabela de um módulo futuro entra no backup e na restauração sozinha, sem
ninguém lembrar de vir aqui. A única exceção é `schema_migrations`: o registro
de migrações é do banco que está rodando, e restaurá-lo faria uma migração já
aplicada parecer pendente.

### O backup é migrado antes de entrar

Um arquivo de três versões atrás não tem as colunas de hoje. Sem migrá-lo
primeiro, a cópia falharia justamente no backup mais antigo — que é o que se
restaura em desespero. O `AppDatabase.migrate` roda no arquivo do backup antes
de qualquer leitura, e uma coluna que ele não tinha nasce com o valor padrão.

### Antes de restaurar, um backup do agora

Restaurar é a única operação do Evergreen que apaga tudo de uma vez. Ter clicado
na linha errada da lista não pode custar o dia de trabalho de hoje, então o
estado atual vira um arquivo novo antes de qualquer coisa — e ele aparece na
lista, no topo, pronto para desfazer o engano.

Essa rede nasceu no ViewModel, como um `create()` antes do `restore()`, e nessa
forma ela tinha um buraco que fazia exatamente o oposto do que prometia: o
`create()` chama a limpeza, a limpeza mantém cinco, e com a pasta no teto o
sexto arquivo empurrava para fora **o mais antigo — que é justamente o que se
estava prestes a restaurar**. O `sqlite3.open` seguinte não reclamava: num
caminho que não existe ele *cria* um banco vazio, a migração dava a ele as
tabelas de hoje, e as zero linhas desse banco eram copiadas por cima de tudo. A
tela dizia "Backup restaurado".

Três decisões saíram daí:

**A rede é do serviço, não de quem chama.** Ela protege da limpeza o arquivo que
o método está prestes a ler, e só quem lê sabe qual é. O `prune` ganhou um
`protecting`: o arquivo em restauração não sai da pasta, nem que esteja
sobrando.

**Nome próprio, teto próprio.** `evergreen-antes-de-restaurar-2026-08-25-1432.db`
continua sendo um arquivo nosso (a limpeza alcança), mas conta separado — três,
contra as cinco dos automáticos. Duas razões: um teto compartilhado faria a
terceira tentativa de restauração apagar a cópia da primeira, que é a única em
que o dia ainda estava inteiro; e uma pasta cheia de backups semanais não pode
varrer a única cópia do que existia antes da última troca. A rede também não
entra na conta do `isDue` — ela é do dia em que se restaurou algo, não do fim de
uma semana, e adiaria por sete dias um backup que ninguém pediu para adiar.

**A lista diz o que ela é.** Os arquivos do Evergreen aparecem só pela data, sem
nome, porque o nome repetiria a data. A rede quebra isso: na linha dela, no
lugar do nome, vai a etiqueta "antes de restaurar". Sem ela, a cópia de
emergência seria indistinguível de mais um backup semanal — no minuto exato em
que se procura por ela.

### O arquivo que sumiu da pasta

A pasta é a interface, o que significa que a pessoa mexe nela. Arrastar um
backup para o lixo com o Hub aberto deixa na lista uma linha que já não
corresponde a nada — e, pelo mesmo `sqlite3.open` que cria banco vazio, clicar
em Restaurar ali esvaziava o banco anunciando sucesso. A restauração agora
confere se o arquivo existe antes de tudo, e recusa com uma frase em português
(`BackupMissing`) sem tocar no banco nem deixar rede para trás.

---

## O que ficou de fora

**As preferências não entram no backup.** São uma dúzia de toggles que se
refazem em um minuto; o histórico não se refaz de jeito nenhum. Guardá-las
exigiria um segundo formato de arquivo, e um `preferencias.json` que ninguém
sabe restaurar automaticamente é peso morto.

**Não há escolha de quantos backups guardar.** Seria um controle a mais numa
tela que já responde a pergunta ("ficam as cinco mais recentes") — e a escala
de decisão aqui é "não quero que acumule", não "quero exatamente sete".

**Não há backup na barra de menus.** A barra é para ação de segundo; backup é
uma coisa que se configura uma vez e se esquece.

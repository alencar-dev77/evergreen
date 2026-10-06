# Track, o dia reconstruído

> Status: **implementado** em 25/08/2026, em `lib/features/track/`.
> Registrado como proposta em 22/08/2026, a partir de uma conversa sobre
> features novas. O que está escrito daqui até "Escopo" é o documento original,
> preservado porque é o argumento do módulo; o que mudou na implementação está
> em "O que a construção decidiu", no fim.

---

## O que é

Uma tela no Hub que responde "o que eu fiz hoje" usando **só o que os módulos já
gravaram**: focou 3h20 em 4 sessões, gravou 2 reuniões, copiou 40 itens — desses,
9 links e 6 comandos. E, no topo, um parágrafo em linguagem natural escrito pelo
modelo local.

Não é um módulo que captura nada. É um módulo que **lê**.

---

## Por que esta é a ideia mais forte do backlog

É a única que **nenhum concorrente consegue copiar**. O Maccy não sabe quanto
você focou. Um app de time-tracking não sabe o que você copiou. O Evergreen sabe
as duas coisas porque os cinco módulos já escrevem no mesmo banco local.

É a feature que só existe porque a suíte existe — e é o que faz o Evergreen
deixar de ser cinco aplicativos dentro de um ícone e virar **um produto**. Todo
módulo novo que entrar depois passa a alimentar o Track de graça.

---

## Por que é barata

Zero código nativo. Zero permissão nova. Zero tabela nova. As três fontes já
estão em `lib/core/storage/app_database.dart`:

| Tabela | O que o Track tira dela |
|---|---|
| `focus_sessions` | Sessões do dia, duração somada, o campo `notes` (o registro de atividade) |
| `clipboard_items` | Volume copiado e a distribuição por `type` — o classificador já separa link, e-mail, telefone, CPF e comando |
| `echo_meetings` | Reuniões gravadas, duração, o resumo que o Echo já produziu |
| `leaf_notes` | O que estava na parede naquele dia |

O módulo é uma query, uma tela e um prompt.

---

## Onde mora

Tela própria na sidebar do Hub — não é painel flutuante, porque não é uma ação
de segundo, é uma leitura. A lista é de dias; o dia aberto usa a **região de
leitura** (`HubDetailRegion`, o mesmo caminho do `EchoReader` e do `FocusReader`),
com a linha do dia marcada como selecionada. Nada de modal.

---

## O resumo em linguagem natural

Usa `FoundationModels`, que já está linkado no Runner pelo Echo
(`macos/Runner/EchoChannel.swift`) — mesmo modelo, mesmo canal, mesmo piso de
macOS 26.

**Mas o módulo não pode depender dele.** Abaixo do macOS 26, ou sem Apple
Intelligence disponível, o Track mostra os números e as listas normalmente e
apenas não escreve o parágrafo. O canal do Echo já responde `unsupportedOS` nesse
caso; o Track segue o mesmo padrão. O resumo é enfeite, o dado é o produto.

---

## Risco principal: o Track não pode vazar o que o Pin guardou

O Pin registra **tudo** o que passa pela área de transferência, senha colada
inclusive. Uma tela que mostra "o que você copiou hoje" é, sem cuidado, uma tela
que exibe senhas em texto puro — e ainda manda esse texto para o modelo.

A regra do módulo, então:

- O Track trabalha com **tipos e contagens**, não com conteúdo bruto.
- O que for para o prompt do modelo é o agregado ("40 itens, 9 links, 6
  comandos"), nunca o texto dos itens.
- Conteúdo de item só aparece se o usuário pedir, e a partir da tela do Pin,
  que é onde ele já espera ver isso.

---

## Escopo se for adiante

- Repositório novo de leitura agregando as quatro tabelas por dia — nenhuma
  escrita, nenhuma migração de schema.
- Tela no Hub: lista de dias + região de leitura do dia.
- Prompt de resumo no canal que o Echo já usa, com degradação silenciosa quando
  o modelo não está disponível.
- Recorte de período (hoje, semana) — o suficiente para fechar uma sexta-feira.

---

## O que a construção decidiu

Seis pontos que o documento não previa, e que só apareceram ao desenhar a tela.

**A medida do Track é "tempo registrado", não tempo focado.** A coluna da
direita de cada dia e a altura de cada barra da semana somam foco **mais**
reunião (`TrackDay.registered`). Uma manhã inteira de reunião é uma manhã de
trabalho, e uma faixa que só contasse foco a desenharia como um dia vazio. É o
que distingue esta faixa da do Focus, e o que justifica as duas existirem.

**O recorte manda na tela inteira, e a faixa da semana some no recorte de hoje.**
Uma barra sozinha não compara nada com nada. No recorte de hoje sobra a frase do
balanço, que é o suficiente para um dia só.

**Hoje tem linha mesmo sem nada registrado.** Os outros dias vazios ficam de
fora — uma quarta-feira de folga não precisa de linha para dizer que foi folga —,
mas uma lista que começa em "Ontem" às dez da manhã parece um módulo quebrado.

**A lista de dias e o dia aberto correm em sentidos opostos.** A lista é uma
lista: hoje na primeira linha. Um dia aberto é uma história, e história se lê do
começo — a sessão das nove antes da das três, que é o que reconstrói o dia.

**A região não tem nenhuma ação, nem apagar.** Cada registro se edita no módulo
que o criou: sessão no Focus, reunião no Echo, item no Pin. Um botão de apagar
aqui apagaria dado de outro módulo pelas costas dele.

**O módulo não tem preferência nenhuma.** Não havia o que ajustar que não fosse
invenção: o recorte é um controle da tela, não uma configuração guardada.

E o risco principal do documento virou uma fronteira de código: a consulta em
`SqliteTrackRepository` pede `copied_at` e `type` da tabela do Pin, e mais nada.
O conteúdo copiado não sai do banco — não é uma escolha da tela, é a única coisa
que o repositório sabe ler. O que segue para o modelo é o agregado, e o teste
`o conteúdo copiado não sai do banco` é o que prende isso.

## Semanas anteriores (v0.24)

O recorte de semana ganhou setas: `‹ Esta semana ›` anda para a semana anterior
e volta. **Não é um seletor de datas** — continua sendo o recorte de semana,
só que de uma semana que já fechou, que é a pergunta de segunda-feira de manhã.

- **O limite é o do Focus, não o dos outros módulos.** Pin, Echo e Awake guardam
  mais que quatro semanas, mas antes disso o foco já não existe, e a semana
  sairia desenhada como uma semana sem trabalho. Por isso o Focus passou a
  guardar quatro semanas no disco (`FocusSessionRepository.keptWeeks`) e o
  Track anda até três para trás (`TrackRange.maxWeeksAgo`), as duas contas
  amarradas na mesma constante.
- **O controle não some com o recorte vazio.** Antes o estado vazio levava o
  seletor junto — e segunda às oito, quando a semana ainda não tem nada, é
  exatamente quando se quer voltar para a anterior. O vazio da estreia ("Nada
  registrado ainda") só aparece na tela de abertura; uma semana passada vazia
  diz que está vazia.
- **Numa semana que já passou, hoje não tem linha** e nenhuma barra se
  destaca: o destaque e a linha obrigatória são de hoje.
- **Trocar para "Hoje" e voltar leva para esta semana.** Quem sai de "Hoje"
  quer o contexto de hoje, não a semana em que estava antes.
- A faixa de barras passou a se chamar "Por dia": o título antigo, "Últimos 7
  dias", já era impreciso (a faixa sempre foi de segunda a domingo), e com o
  nome da semana ao lado das setas ele repetiria a informação.

## Onde o código está

| Peça | Arquivo |
|---|---|
| Leitura agregada das quatro tabelas | `lib/features/track/data/track_repository.dart` |
| O parágrafo do modelo, com degradação silenciosa | `lib/features/track/data/track_summarizer.dart` |
| Estado da tela, recorte e cache do resumo | `lib/features/track/presentation/viewmodels/track_view_model.dart` |
| Tela do Hub | `lib/features/track/presentation/views/track_view.dart` |
| Região de leitura do dia | `lib/features/track/presentation/widgets/track_reader.dart` |
| Faixa de barras, compartilhada com o Focus | `lib/shared/widgets/eg_day_bars.dart` |

Conferência visual: `test/goldens/hub_track.png` e
`test/goldens/hub_track_day.png`.

# Sugestão futura — Trail, o dia reconstruído

> Status: **proposta**, não agendada. Nenhum código foi escrito.
> Registrado em 22/08/2026, a partir de uma conversa sobre features novas.

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
módulo novo que entrar depois passa a alimentar o Trail de graça.

---

## Por que é barata

Zero código nativo. Zero permissão nova. Zero tabela nova. As três fontes já
estão em `lib/core/storage/app_database.dart`:

| Tabela | O que o Trail tira dela |
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
Intelligence disponível, o Trail mostra os números e as listas normalmente e
apenas não escreve o parágrafo. O canal do Echo já responde `unsupportedOS` nesse
caso; o Trail segue o mesmo padrão. O resumo é enfeite, o dado é o produto.

---

## Risco principal: o Trail não pode vazar o que o Pin guardou

O Pin registra **tudo** o que passa pela área de transferência, senha colada
inclusive. Uma tela que mostra "o que você copiou hoje" é, sem cuidado, uma tela
que exibe senhas em texto puro — e ainda manda esse texto para o modelo.

A regra do módulo, então:

- O Trail trabalha com **tipos e contagens**, não com conteúdo bruto.
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

## Próximo passo, se decidir seguir

Rodar as queries à mão contra o `evergreen.db` de um dia real de uso e olhar o
resultado. Se os números de um dia qualquer já contarem uma história sem nenhuma
tela desenhada, o módulo se paga. Se não contarem, o problema é falta de dado, e
nenhuma UI conserta isso.

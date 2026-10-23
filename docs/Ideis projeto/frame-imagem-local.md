# Sugestão futura — Frame, ferramentas de imagem locais

> Status: **descartada** em 23/10/2026: o escopo do Evergreen fechou na V1
> com os sete módulos. Nenhum código foi escrito; o documento fica pelo
> raciocínio (o porquê e o custo nativo), não como fila.
>
> Antes: proposta, não agendada.
> Registrado em 22/08/2026, a partir de uma conversa sobre features novas.

---

## O que é

Arrasta uma imagem, o fundo some. Salva PNG transparente.

Junto, no mesmo painel: comprimir, converter formato e redimensionar — as três
coisas que hoje se faz subindo arquivo para um site aleatório.

---

## Por que é barata

`VNGenerateForegroundInstanceMaskRequest`, do Vision (macOS 14+), separa o
objeto do fundo numa chamada, offline, sem modelo para baixar e sem rede. O
framework já está no sistema. Compressão, conversão e redimensionamento saem de
`ImageIO` e `Core Graphics`.

É a menor das três propostas registradas neste dia — a que dá para entregar num
fim de semana.

---

## Por que vale

É o tipo de tarefa pela qual as pessoas hoje mandam foto de trabalho para um
servidor de terceiro e pagam por crédito. Fazer isso local é ao mesmo tempo a
tese do Evergreen ("tudo local, nada sai da máquina") e um argumento de venda
que se explica sozinho.

E é a melhor screenshot de loja do backlog inteiro: o antes-e-depois não precisa
de legenda — o que importa, dado que o brief de redesign diz que o app *"precisa
converter na primeira impressão da screenshot da loja"*.

---

## Como se encaixa nos outros módulos

- **Com o Snap** — o destino natural de uma captura recém-feita: capturou, tirou
  o fundo, colou.
- **Com o Shelf** (se um dia sair) — a mesma área de soltar arquivo serve aos
  dois.

Nenhum dos dois é pré-requisito. O Frame funciona sozinho.

---

## Onde mora

Painel flutuante na janela 0, como os outros (acrescentar um valor a
`OverlayPanel`, desenhar em `OverlayHost`, registrar o atalho no
`EvergreenBootstrap`) — o painel é a área de soltar. O resultado e o histórico
de conversões ficam no Hub.

Diferente do Snap, aqui **não** é preciso janela nova nem overlay por monitor: o
arquivo chega por arrasto, não por seleção de tela. A convenção do projeto se
mantém inteira.

---

## Riscos

- Qualidade da máscara varia com o assunto: cabelo, objeto fino e fundo de baixo
  contraste saem pior. É limitação do modelo do sistema, não de implementação —
  e o usuário precisa poder salvar mesmo assim.
- Piso de macOS 14 para a máscara de recorte. Menor que o do Echo (26), maior que
  o do resto do app (12).
- Escopo tem tendência a virar saco de utilidades. O módulo é "tirar fundo" com
  três acompanhamentos, não um editor de imagem.

---

## Próximo passo, se decidir seguir

Um script Swift de vinte linhas chamando
`VNGenerateForegroundInstanceMaskRequest` sobre meia dúzia de imagens reais —
print de tela, foto de pessoa, logotipo, algo com cabelo. Olhar os recortes.
A viabilidade do módulo inteiro está nesse resultado, e ele custa uma tarde.

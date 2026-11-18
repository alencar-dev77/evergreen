# Bloquear o teclado

> Status: **implementado**, como parte do Awake (18/11/2026). Registrada em
> 23/10/2026, quando o escopo do Evergreen fechou na V1, como a única ideia que
> ainda podia entrar.

---

## O que é

Limpar o teclado de um MacBook com ele ligado digita lixo em qualquer app que
estiver na frente — e desligar a máquina para isso é desproporcional. O Awake
ganhou um **bloqueio de teclado**: nenhuma tecla chega a app nenhum por um
prazo curto, e o teclado volta sozinho quando ele acaba.

É o mesmo tipo de coisa que o Awake já fazia com a tela — um estado da
máquina, ligado de propósito, que se desfaz sozinho —, por isso mora nele, e
não num oitavo módulo.

## Como ficou

- **Só liga e desliga.** Não há opção no painel: o prazo é preferência, na
  tela do Awake no Hub — 1 min (padrão), 5 min, 10 min ou "Sempre". Na hora de
  bloquear ninguém quer decidir um número, e o painel bloqueado não tem
  teclado para trocar de opção.
- **Três portas para bloquear**: a linha "Bloquear o teclado por 1 min" no
  painel do `⌘⇧X`, a tecla `t` nesse painel e o item "Bloquear teclado" no
  menu da barra (que também traz o painel para a tela). **Nenhum atalho
  global**: um atalho que só serve para ligar ensina metade do gesto.
- **O bloqueio é o painel.** Bloqueado, o painel do Awake vira a contagem do
  bloqueio, diz que o mouse e o trackpad continuam funcionando e que o tempo se
  muda nas preferências. Ele não fecha pelo Esc (nenhuma tecla chega) e não
  fecha sozinho — sai pelo "Desbloquear" ou pelo clique fora, e os dois
  devolvem o teclado. Trocar de painel, desligar o Awake ou encerrar o app
  também devolvem. Teclado bloqueado sem nada na tela pareceria um Mac travado.
- **A saída nunca depende do teclado**: o prazo, o botão, o clique fora e o
  item "Desbloquear teclado" do menu da barra.

## Por baixo

- **`CGEventTap` na sessão** (`KeyboardLockChannel.swift`), que devolve `nil`
  para tecla descendo, tecla subindo, modificadora e tecla de sistema (brilho,
  volume — `NSSystemDefined`). Ele olha o tipo do evento, não o conteúdo. A
  subida das teclas que já estavam apertadas na hora de bloquear (o `t`)
  passa, senão o app que viu a descida acharia que ela continua apertada. Se o
  sistema desliga o tap por demora, ele é religado na hora.
- **Acessibilidade**: a mesma do auto-colar do Pin. Sem ela, o painel diz por
  quê, e a tela do Awake no Hub mostra o "Permitir".
- **Entrada segura** (campo de senha com foco, "Secure Keyboard Entry" do
  Terminal): nesse estado o macOS não entrega tecla a tap nenhum. O bloqueio é
  recusado com o motivo, em vez de prometer o que não acontece.
- **Teclado externo**: o tap pega todos os teclados de uma vez — o esperado
  para limpar.
- Não grava nada no banco, e o Track não o vê: não é um período do dia.

## Referências

Apps como o KeyboardCleanTool fazem exatamente isso, sozinhos. O motivo de
caber no Evergreen é o mesmo do Awake: é um utilitário de um gesto, que vive na
barra de menus e some quando acaba.

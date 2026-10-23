# Sugestão futura — bloquear o teclado para limpar

> Status: **proposta**, não agendada. Nenhum código foi escrito.
> Registrada em 23/10/2026, quando o escopo do Evergreen fechou na V1: é a
> única ideia que ainda pode entrar.

---

## O que é

Limpar o teclado de um MacBook com ele ligado digita lixo em qualquer app que
estiver na frente — e desligar a máquina para isso é desproporcional. A
proposta é um atalho (ou um item do menu da barra) que **ignora o teclado por
um prazo curto**, com a contagem na tela, e devolve tudo sozinho quando acaba.

É o mesmo tipo de coisa que o Awake já faz com a tela: um estado da máquina,
ligado de propósito, com prazo, que se desfaz sozinho. Por isso o lugar natural
é **um modo do Awake**, e não um oitavo módulo — o escopo fechou nos sete.

## Como funcionaria

- **Engolir as teclas é nativo**: um `CGEventTap` na sessão, que devolve `nil`
  para `keyDown`, `keyUp` e `flagsChanged` enquanto o bloqueio vale. Não há
  equivalente em Flutter.
- **Permissão**: um tap que descarta eventos exige a **Acessibilidade** — a
  mesma do auto-colar do Pin, que a pessoa talvez já tenha dado. Sem ela, a
  opção avisa e não liga.
- **A saída nunca depende do teclado**, porque é justamente o que está
  bloqueado:
  - o prazo acaba sozinho (30 s, 1 min — curto de propósito);
  - um botão "Desbloquear" clicável na tela da contagem;
  - o trackpad e o mouse continuam funcionando (só o teclado é engolido).
- **A tela da contagem** cobre a tela inteira, escura, com o tempo restante —
  é o que deixa claro que digitar agora não faz nada. Isso pede uma janela
  própria ou a janela 0 esticada, e qualquer uma das duas precisa ser decidida
  contra a regra da janela 0 (ver o AGENTS.md).

## Riscos

- **Ficar preso fora do teclado** é o pior caso, e é por ele que o prazo é
  curto e a saída é pelo trackpad. O botão de liga do Mac e o Touch ID não
  passam pelo tap — o sistema continua alcançável.
- **Entrada segura** (campo de senha com foco, Terminal com "Secure Keyboard
  Entry"): nesse estado o macOS não entrega teclas a tap nenhum, e o bloqueio
  não funciona. A opção precisa perceber isso (`IsSecureEventInputEnabled`) e
  dizer, em vez de prometer um bloqueio que não está acontecendo.
- **Teclado externo**: o tap pega todos os teclados de uma vez, o que é o
  esperado para limpar — mas vale dizer na descrição.

## Referências

Apps como o KeyboardCleanTool fazem exatamente isso, sozinhos. O motivo de
caber no Evergreen é o mesmo do Awake: é um utilitário de um gesto, que vive na
barra de menus e some quando acaba.

## Pronto quando

- [ ] Ligar pelo atalho ou pelo menu, com a contagem na tela e as teclas
      engolidas em qualquer app.
- [ ] O prazo acaba sozinho; o botão na tela desbloqueia antes.
- [ ] Sem Acessibilidade, ou com entrada segura ligada, a opção diz por que não
      liga.
- [ ] A PRIVACY.md continua certa: o tap não lê o que é digitado, só descarta.

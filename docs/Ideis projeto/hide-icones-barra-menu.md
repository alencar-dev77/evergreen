# Sugestão futura — hide de ícones na barra de menus (estilo Ice/Bartender)

> Status: **proposta**, não agendada. Nenhum código foi escrito.
> Registrado em 24/07/2026, a partir de um pedido de feature durante ajustes
> no `run_build_copy`.

---

## O que foi pedido

Adicionar, no menu do ícone do Evergreen na barra de menus
(`lib/core/system/menu_bar_service.dart`), uma opção **Hide** com um submenu
**Ativar/Desativar**.

O comportamento esperado: o próprio ícone do Evergreen na barra vira um botão
de "esconder" — ao clicar, os ícones de **outras apps** na barra de menus
somem; segurando `cmd` e clicando/arrastando um ícone, dá pra mover ele pra
dentro ou pra fora da área escondida. É o mesmo comportamento do app **Ice**
(open source, MIT) e de apps como Bartender/Vanilla/Dozer.

## Por que isso não é uma feature do Pin

Apesar de morar no mesmo menu, isso não tem relação com clipboard. É gerenciar
os ícones de **processos de outras apps** na barra de menus do sistema —
domínio bem diferente do resto do módulo Pin.

## Por que não dá pra fazer em Flutter puro

O macOS não expõe API pública para esconder ou mover o `NSStatusItem` de outro
processo. O truque que Ice/Bartender usam:

1. O ícone do app vira um marcador de fronteira na barra.
2. Ao ativar o "hide", o app desenha uma janela opaca por cima da região da
   barra à esquerda do marcador — cor igual à barra de menus, cobrindo
   visualmente os ícones. Eles continuam lá, só ficam tampados.
3. Para saber a posição exata de cada ícone alheio (e redesenhar a cobertura
   quando algum muda), o app lê isso via **Accessibility API**
   (`AXUIElement`), o que exige que o usuário conceda permissão de
   Acessibilidade ao Evergreen.

Nenhum pacote Flutter expõe isso — `tray_manager` só gerencia o ícone do
próprio app. Seria necessário um módulo novo, majoritariamente em
Swift/AppKit, o que contraria a convenção do projeto de preferir sempre
Flutter puro (registrada em `AGENTS.md`) — motivo pelo qual está documentado
aqui em vez de implementado direto.

O `cmd`+arrastar para reordenar ícones **já é nativo do macOS** — nenhuma
implementação é necessária para essa parte, só para o "esconder/mostrar".

## Riscos

- Depende de comportamento não documentado da barra de menus; já quebrou
  Bartender em updates do macOS (ex.: Ventura).
- Pede permissão de Acessibilidade — fricção nova de confiança com o usuário,
  algo que o Evergreen ainda não pede para nada.
- Manutenção contínua acompanhando mudanças do sistema.

## Escopo se for adiante

Módulo praticamente do zero, não um ajuste no menu do Pin:

- Novo canal nativo (`macos/Runner`) para status items de terceiros —
  enumeração via Accessibility API.
- Janela overlay borderless, sempre no topo, posicionada sobre a barra de
  menus, cobrindo a região à esquerda do ícone do Evergreen.
- Fluxo de solicitação de permissão de Acessibilidade.
- Estado (ativado/desativado, quais ícones estão "escondidos") persistido —
  provavelmente `shared_preferences`, sem precisar de tabela nova no SQLite.
- Referência de implementação: [Ice](https://github.com/jordanbaird/Ice)
  (MIT) resolve exatamente este problema e pode servir de guia técnico.

## Próximo passo, se decidir seguir

Prototipar só a janela de cobertura (passo 2 acima) isolada, antes de
construir a leitura de posição via Accessibility — valida se o efeito visual
convence antes de pagar o custo de permissão + enumeração de ícones alheios.

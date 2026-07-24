# Filosofia do Evergreen

## Quem é o Evergreen

O Evergreen é uma ferramenta, não uma experiência. Isso parece óbvio, mas é a distinção mais importante desta skill: uma ferramenta boa é aquela que a pessoa esquece que está usando, porque toda a atenção vai para o trabalho, não para o software.

Pense em como você usa o Raycast: você aperta um atalho, digita três letras, aperta Enter, e já saiu. Você não "aprecia a interface" do Raycast enquanto usa — você aprecia depois, quando percebe o quanto ele não te atrapalhou. É esse o padrão de sucesso do Evergreen.

## Os cinco pilares

### 1. Simplicidade estrutural, não simplicidade visual

Simplicidade não é "poucos elementos na tela". É **hierarquia clara o suficiente para que a pessoa nunca precise pensar sobre a interface em si**. Uma tela pode ter quinze linhas de informação densa e ainda ser simples, se a hierarquia for impecável. Uma tela pode ter três elementos e ser confusa, se não estiver claro o que é clicável, o que é label, e o que é conteúdo.

Pergunta de verificação: *se eu tirar todo o styling e deixar só texto preto em fundo branco, a hierarquia ainda faz sentido pela posição e pelo peso da fonte?* Se sim, o design está certo antes mesmo de aplicar cor.

### 2. Foco como recurso escasso

Cada elemento visual que não contribui diretamente para a tarefa atual é um imposto sobre a atenção do usuário. Isso vale para decoração, mas também vale para excesso de opções, ícones redundantes, textos explicativos desnecessários e cores que competem entre si.

O Evergreen deve favorecer sempre **uma ação primária óbvia por tela ou por contexto**, com as demais ações disponíveis mas discretas (menu contextual, atalho, texto secundário). Isso é o oposto do padrão "todas as opções visíveis o tempo todo" que domina dashboards web genéricos.

### 3. Produtividade como métrica estética

Uma tela do Evergreen é bem-sucedida quando o tempo entre "abrir o app" e "tarefa concluída" é mínimo. Isso influencia decisões que parecem puramente visuais:

- Listas densas em vez de cards espaçados, porque cards espaçados obrigam mais rolagem para ver a mesma quantidade de informação.
- Texto em vez de ícone sempre que o ícone precisar de um tooltip para ser entendido — se precisa de tooltip, o ícone falhou.
- Estados de carregamento rápidos e discretos, nunca com telas de loading dramáticas ("splash screens" no meio do uso são um erro de produtividade).

### 4. Minimalismo premium, não minimalismo vazio

Existe uma diferença enorme entre "minimalista porque é rápido de fazer" e "minimalista porque cada elemento restante foi cuidadosamente decidido". O primeiro parece um placeholder. O segundo parece Things 3 ou Craft — sóbrio, mas com uma qualidade tátil evidente: bordas com o raio certo, uma sombra sutil no lugar certo, um peso de fonte que não é nem fino demais nem bold demais.

Minimalismo premium tem textura: variação sutil de superfícies (fundo da janela levemente diferente do fundo de um painel interno), uma linha de separação quase imperceptível em vez de nenhuma linha, um highlight de seleção com opacidade calibrada em vez de uma cor sólida saturada.

### 5. Performance visual como parte do design

Um app nativo rápido *parece* rápido antes mesmo de qualquer benchmark — porque as transições são curtas, porque não há "pulos" de layout, porque o texto não pisca ao carregar fontes, porque hover responde no frame seguinte. Isso significa que, ao desenhar, cada decisão de motion, blur ou sombra deve ser avaliada também pelo custo de renderização, não só pela aparência estática em um Figma. Um blur de fundo em uma sidebar que fica sempre visível na tela custa caro a cada frame; um blur em um popup que aparece por 200ms e some não custa quase nada perceptível. Desenhe pensando no ciclo de vida real do elemento.

## O "modo de uso" como ferramenta de decisão

Antes de desenhar qualquer tela, identifique qual modo de uso do Evergreen ela representa — isso muda as prioridades de design:

- **Modo comando/captura rápida** (inspirado em Raycast, Maccy): a pessoa quer entrar, executar uma ação, sair. Prioridade máxima: teclado, velocidade de abertura, busca instantânea, zero fricção antes da primeira tecla digitada.
- **Modo organização/planejamento** (inspirado em Things 3, Linear): a pessoa vai passar minutos revisando, reordenando, decidindo prioridades. Prioridade: densidade de informação legível, hierarquia visual clara entre grupos, drag-and-drop e reordenação fluidos.
- **Modo criação/edição de conteúdo** (inspirado em Craft): a pessoa está escrevendo ou compondo algo. Prioridade: tipografia confortável para leitura longa, interface que recua para dar espaço ao conteúdo, barra de ferramentas discreta que só aparece quando relevante (seleção de texto, por exemplo).
- **Modo navegação estrutural** (inspirado em Arc, Linear): a pessoa está se movendo entre seções/projetos/contextos. Prioridade: sidebar como mapa mental confiável, transições de contexto claras mas rápidas, breadcrumbs implícitos pela própria estrutura.

Uma mesma tela pode combinar modos (uma sidebar de navegação ao lado de uma lista densa de organização), mas cada elemento individual deve saber a qual modo pertence.

## O que "parecer feito por IA" realmente significa

Isso não é sobre qualidade técnica — é sobre um conjunto específico e reconhecível de tiques visuais que aparecem quando um design é gerado sem intenção humana editorial por trás. Reconheça esses sinais para evitá-los ativamente (a lista detalhada e acionável está em `anti-patterns.md`, mas os sintomas de raiz são):

1. **Simetria performática** — tudo centralizado, tudo com o mesmo espaçamento, como se a régua tivesse sido aplicada sem julgamento sobre o que realmente precisa de destaque.
2. **Cor como decoração, não como significado** — gradientes, cores vibrantes em elementos que não representam nenhum estado ou ação, "porque fica bonito".
3. **Redundância de affordance** — um botão com ícone E texto E cor de destaque E sombra para uma ação simples, quando qualquer um desses sozinho já bastaria.
4. **Vazio sem propósito** — espaços em branco enormes que não separam nada, só "porque design minimalista tem espaço em branco" (confundindo a causa com o efeito).
5. **Falta de opinião** — quando tudo tem o mesmo peso visual, é sinal de que nenhuma decisão editorial de hierarquia foi tomada. Um bom design tem coisas discretamente feias-de-propósito (texto cinza pequeno) ao lado de coisas deliberadamente fortes (um único CTA escuro).

A defesa contra tudo isso é a mesma: **toda decisão visual precisa ter uma razão funcional articulável**. Se a razão for só "fica bonito" ou "é o padrão", volte e repense.

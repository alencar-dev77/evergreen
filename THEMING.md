# Temas

O Evergreen tem duas aparências, e as duas são escuras: **Evergreen**, a paleta
da casa, e **Apple**, o escuro do macOS. O que muda entre elas é a linguagem —
cor, densidade, espessura de linha, material e curva de movimento. O que **não**
muda é a estrutura: nenhuma tela ganha ou perde um elemento por causa do tema, e
nenhum widget pergunta qual tema está em vigor para decidir o que desenhar.

A escolha mora em `AppSettings.theme`, na tela do Evergreen, e vale para as duas
janelas do app.

## A bandeira

Tudo isto está atrás de `FeatureFlags.themes` (`lib/shared/feature_flags.dart`),
e **hoje ela está desligada**: o app fica no tema da casa e a linha "Aparência"
some da tela — não desabilitada, some. Um controle apagado diz "isto existe, mas
não para você"; aqui a resposta certa é a tela não mencionar uma escolha que
ninguém pode fazer.

Quem manda é `AppSettings.activeTheme`, e é o único ponto do app em que a
bandeira decide alguma coisa. O `theme` cru continua sendo a preferência
guardada: desligar não apaga o que a pessoa escolheu, e religar devolve a
escolha em vez de zerá-la.

O código dos dois temas continua compilando, testado e coberto por goldens dos
dois lados da bandeira — no dia em que ela virar `true`, o que aparece do outro
lado não pode ser uma ruína.

## A regra

> Nenhuma cor, tamanho de fonte, raio, sombra ou espessura de linha escrito à mão
> fora de `lib/core/design/themes/`.

Widget pede ao tema: `context.eg.colors.accent`, `context.eg.text.body`,
`context.eg.shapes.radiusCard`. Se o papel que você precisa não existe, ele
**nasce nos dois temas** — o compilador cobra o segundo, porque todo campo dos
tokens é `required`.

O que continua estático, e de propósito:

| O que | Por quê |
|---|---|
| `AppSpacing` | O ritmo de espaçamento é do produto, não da pele. |
| `AppIconSizes`, `AppBadgeSizes` | Idem: um glifo de 15px é 15px nos dois. |
| `AppDurations` | Um app que fica mais lento ao trocar de aparência estaria mentindo sobre o que a troca faz. Só a **curva** é do tema (`EgMotion.curve`). |
| `AppColors.transparent` | Não é escolha de paleta: é a ausência de superfície. |

## Onde ficam as coisas

```
lib/core/design/
  app_theme_id.dart        # o enum dos temas
  app_theme.dart           # traduz os tokens para o ThemeData do Material
  eg_tokens.dart           # o ThemeExtension + o acessor context.eg
  tokens/                  # a FORMA de cada grupo de tokens (sem valores)
    eg_palette.dart
    eg_type_scale.dart
    eg_shapes.dart
    eg_elevations.dart
    eg_motion.dart
    eg_gradients.dart      # derivados da paleta
  themes/                  # os VALORES — e só aqui existe literal
    evergreen_tokens.dart
    apple_tokens.dart
```

## Como adicionar um token

1. Acrescente o campo em `tokens/eg_*.dart`, `required`, com um comentário
   dizendo **qual papel** ele tem (não qual cor ele é).
2. Acrescente-o ao `lerp` do mesmo arquivo — é o que faz a troca de tema
   atravessar animada em vez de piscar.
3. Responda nos dois temas, em `themes/`. O compilador não deixa esquecer.
4. Use por `context.eg`.

## Como adicionar um tema

Crie `themes/<nome>_tokens.dart` respondendo a todos os tokens, acrescente o
valor ao `AppThemeId` e o ramo ao `EgTokens.of`. O seletor de aparência se
atualiza sozinho: ele percorre `AppThemeId.values` e desenha a miniatura de cada
um **com os tokens do próprio tema**, então não existe ilustração para manter em
dia.

## O que um widget nunca faz

- **Não** olha `context.eg.id` para decidir desenho. Um `if (id == apple)` dentro
  de um widget é um token faltando. A única bandeira que se lê é
  `usesVibrancy`, e só quem desenha painel a lê — a diferença entre vidro e cor
  não cabe num token de cor: um pede `BackdropFilter`, o outro pede um
  `Container`.
- **Não** compõe cor com `withValues` a partir de um token para inventar um
  degrau novo. Degrau novo é token novo.
- **Não** guarda um `EgSurfaceStyle` em `static const`. As colunas da matriz de
  estado saem de `context.eg.surfaces`, que é resolvida por tema.

## As duas janelas

O Hub e a janela flutuante rodam em **engines Flutter separados**, cada um com a
sua cópia em memória do `shared_preferences`. A aparência é escolhida no Hub, e o
painel flutuante só fica sabendo porque relê o disco quando aparece
(`AppSettingsRepository.reload`, chamado pelo `OverlayHost`). É a mesma armadilha
da instrução do resumo e do nome de quem usa.

## O que o tema não alcança

O ícone do aplicativo (Dock, Finder, painéis de permissão do macOS) e o da barra
de menus são arquivos **dentro do bundle**, lidos pelo sistema uma vez. Eles
seguem a paleta do tema da casa e não acompanham a preferência — trocá-los em
tempo de execução pediria mexer no `NSApplication` pelo lado nativo. Dentro da
janela, a marca segue o tema como todo o resto: ela é desenhada com
`context.eg.colors.accent`.

## Conferência visual

```
flutter test --run-skipped -t preview --update-goldens
```

Gera, entre outros, `design_state_matrix_evergreen.png` e
`design_state_matrix_apple.png` (a matriz de estados inteira em cada pele) e
`apple_hub_pin_settings.png` / `apple_pin_overlay_list.png` ao lado dos
equivalentes do tema da casa. Duas imagens lado a lado é a forma mais rápida de
ver se um estado sumiu numa das aparências — um hover que não se vê, uma seleção
sem contraste.

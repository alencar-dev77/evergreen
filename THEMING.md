# Temas

O Evergreen é **dark-only e tem uma pele só**: a "Estufa", em
`lib/core/design/themes/evergreen_tokens.dart`.

## Onde os valores moram

Todo valor visual — cor, tipo, raio, sombra, duração — vem do tema pelo
contexto:

```dart
context.eg.colors.accent
context.eg.text.body
context.eg.shapes.radiusCard
context.eg.elevations.floatingPanel
context.eg.motion.fast
context.eg.gradients.panelSurface
context.eg.surfaces.row
```

Literal de cor, raio ou sombra existe **só** em `themes/evergreen_tokens.dart`.
Um `if` de tema dentro de um widget é um token faltando.

## Como acrescentar um papel

1. Declare o campo no contrato (`tokens/eg_palette.dart`, `eg_type_scale.dart`,
   `eg_shapes.dart`, `eg_elevations.dart`, `eg_motion.dart`). **Todo campo é
   `required`** — é o compilador que cobra o resto.
2. Dê o valor em `evergreen_tokens.dart`, com um comentário dizendo *o que o
   papel significa*, não que cor ele é.
3. Se for um estado interativo, ele entra na matriz `EgSurfaces`
   (`shared/widgets/eg_surface.dart`), não num `if` do widget.
4. Regenere a folha de estados:
   `flutter test --run-skipped -t preview --update-goldens`.

## O tema `apple`, e por que ele saiu

Existiu um segundo tema escuro, que seguia o HIG do macOS. A escolha de
aparência ficou atrás da bandeira `FeatureFlags.themes`, em `false`, desde que
nasceu — ninguém nunca a viu.

Com todo campo de token `required`, o segundo arquivo dobrava o custo de cada
papel novo: o redesenho "Estufa" acrescentou dez papéis, e cada um teria de
nascer duas vezes, uma delas em valores que ninguém veria. Manter uma pele que
não se veste é dívida, não é opção — saiu na v0.16, junto com `AppThemeId`, o
`ThemePicker`, a chave `app.theme` e a própria bandeira.

**A preferência guardada no disco não foi apagada.** Quem tinha escolhido o
Apple continua com `apple` em `app.theme`, esperando.

Se um segundo tema voltar, ele volta como um `EgPalette` completo ao lado do
primeiro e um `EgTokens.of(id)` escolhendo entre os dois — nunca como `if`s
espalhados pelos widgets. A infraestrutura para isso continua de pé: o
`EgTokens` é um `ThemeExtension` e sabe interpolar.

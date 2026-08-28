import 'package:flutter/material.dart';

import '../../shared/widgets/eg_surface.dart';
import 'app_theme_id.dart';
import 'tokens/eg_gradients.dart';
import 'themes/apple_tokens.dart';
import 'themes/evergreen_tokens.dart';
import 'tokens/eg_elevations.dart';
import 'tokens/eg_motion.dart';
import 'tokens/eg_palette.dart';
import 'tokens/eg_shapes.dart';
import 'tokens/eg_type_scale.dart';

/// Os tokens do tema em vigor, pendurados no `ThemeData`.
///
/// É um `ThemeExtension`, e não um singleton nem um `InheritedWidget` próprio,
/// por três motivos práticos: o hot reload continua funcionando, a troca de
/// tema atravessa animada (o Flutter interpola a extensão junto com o resto do
/// tema) e um teste pode montar duas telas com temas diferentes lado a lado —
/// que é exatamente o que o teste de paridade faz.
@immutable
class EgTokens extends ThemeExtension<EgTokens> {
  const EgTokens({
    required this.id,
    required this.colors,
    required this.text,
    required this.shapes,
    required this.elevations,
    required this.motion,
    required this.usesVibrancy,
  });

  /// Qual tema é este. Serve para o seletor marcar o escolhido — **não** para
  /// widget nenhum decidir desenho por `if`: quem tem um `if (id == apple)`
  /// dentro está com um token faltando.
  final AppThemeId id;

  final EgPalette colors;

  /// A escala de texto.
  ///
  /// Chamada `text`, e não `type`: `ThemeExtension` já tem um `type`, que é a
  /// chave com que o Flutter acha a extensão no tema. Sobrescrevê-lo faria
  /// `Theme.of(context).extension<EgTokens>()` devolver nulo — e a tela
  /// inteira morreria num `!` de aparência inocente.
  final EgTypeScale text;
  final EgShapes shapes;
  final EgElevations elevations;
  final EgMotion motion;

  /// Se as superfícies flutuantes são feitas do que está atrás delas.
  ///
  /// É a única bandeira de material do sistema, e existe porque a diferença
  /// entre vidro e cor não cabe num token de cor: um pede `BackdropFilter`,
  /// o outro pede um `Container`. Quem desenha painel olha isto; ninguém mais.
  final bool usesVibrancy;

  static EgTokens of(AppThemeId id) => switch (id) {
    AppThemeId.evergreen => EgTokens(
      id: AppThemeId.evergreen,
      colors: EvergreenTokens.palette,
      text: EvergreenTokens.type,
      shapes: EvergreenTokens.shapes,
      elevations: EvergreenTokens.elevations,
      motion: EvergreenTokens.motion,
      usesVibrancy: false,
    ),
    AppThemeId.apple => EgTokens(
      id: AppThemeId.apple,
      colors: AppleTokens.palette,
      text: AppleTokens.type,
      shapes: AppleTokens.shapes,
      elevations: AppleTokens.elevations,
      motion: AppleTokens.motion,
      usesVibrancy: true,
    ),
  };

  /// Os gradientes de profundidade deste tema — ver `EgGradients`.
  EgGradients get gradients => EgGradients(this);

  /// A matriz de estados (repouso, hover, pressed, selecionado…) resolvida
  /// para este tema — ver `EgSurfaces`.
  EgSurfaces get surfaces => EgSurfaces(this);

  /// A linha divisória do tema, já com cor e espessura — os dois lados da
  /// mesma decisão, e a razão de `AppBorders` ter deixado de ser estático: no
  /// macOS ela tem meio pixel, e meio pixel com a cor errada não é hairline, é
  /// sujeira.
  BorderSide get hairline =>
      BorderSide(color: colors.border, width: shapes.hairline);

  Border get borderAll => Border.fromBorderSide(hairline);
  Border get borderBottom => Border(bottom: hairline);
  Border get borderRight => Border(right: hairline);

  @override
  EgTokens copyWith({
    AppThemeId? id,
    EgPalette? colors,
    EgTypeScale? text,
    EgShapes? shapes,
    EgElevations? elevations,
    EgMotion? motion,
    bool? usesVibrancy,
  }) => EgTokens(
    id: id ?? this.id,
    colors: colors ?? this.colors,
    text: text ?? this.text,
    shapes: shapes ?? this.shapes,
    elevations: elevations ?? this.elevations,
    motion: motion ?? this.motion,
    usesVibrancy: usesVibrancy ?? this.usesVibrancy,
  );

  /// A travessia de um tema para o outro.
  ///
  /// Cor, texto, raio e sombra interpolam de verdade — é isso que faz a troca
  /// parecer a interface se reacomodando em vez de piscar. O que não interpola
  /// é a identidade e a bandeira de vibrancy: meio blur não existe, e a troca
  /// acontece no meio do caminho, quando as cores já estão a meia distância e
  /// ninguém percebe o corte.
  @override
  EgTokens lerp(covariant EgTokens? other, double t) {
    if (other == null) return this;

    return EgTokens(
      id: t < 0.5 ? id : other.id,
      colors: EgPalette.lerp(colors, other.colors, t),
      text: EgTypeScale.lerp(text, other.text, t),
      shapes: EgShapes.lerp(shapes, other.shapes, t),
      elevations: EgElevations.lerp(elevations, other.elevations, t),
      motion: EgMotion.lerp(motion, other.motion, t),
      usesVibrancy: t < 0.5 ? usesVibrancy : other.usesVibrancy,
    );
  }
}

/// O acesso curto aos tokens de dentro de um widget: `context.eg.colors.accent`.
///
/// `eg`, e não `t`: o prefixo é o mesmo dos componentes compartilhados
/// (`EgButton`, `EgPanel`), e num arquivo de feature `context.eg` diz de onde o
/// valor vem — uma letra sozinha não diria.
extension EgTokensContext on BuildContext {
  /// Os tokens do tema em vigor — ou os do tema da casa, quando não há tema
  /// nenhum acima.
  ///
  /// O `!` que estava aqui derrubava a árvore inteira em qualquer subárvore
  /// montada sem o `AppTheme` — um teste de widget que só quer um botão, um
  /// `showDialog` com tema próprio. Cair no Evergreen é a resposta certa para
  /// esse caso: é o tema padrão do produto, e um componente desenhado com ele
  /// continua sendo um componente do Evergreen. Crashar não deixava nada mais
  /// correto, só mais frágil.
  EgTokens get eg =>
      Theme.of(this).extension<EgTokens>() ?? EgTokens.of(AppThemeId.evergreen);
}

import 'package:flutter/material.dart';

import '../../shared/widgets/eg_surface.dart';
import 'themes/evergreen_tokens.dart';
import 'tokens/eg_elevations.dart';
import 'tokens/eg_gradients.dart';
import 'tokens/eg_motion.dart';
import 'tokens/eg_palette.dart';
import 'tokens/eg_shapes.dart';
import 'tokens/eg_type_scale.dart';

/// Os tokens do Evergreen, no lugar onde um widget os alcança:
/// `context.eg.colors.accent`, `context.eg.text.body`,
/// `context.eg.shapes.radiusCard`.
///
/// É um `ThemeExtension` porque é assim que o valor desce a árvore sem ninguém
/// passar parâmetro — e porque o Material sabe interpolar extensões, o que
/// mantém a porta aberta para um segundo tema sem que nenhuma tela precise
/// saber disso.
///
/// **Houve um segundo tema, o `apple`, e ele saiu.** A escolha de aparência
/// estava desligada por bandeira desde que nasceu, e com todo campo de token
/// `required` o segundo arquivo dobrava o custo de cada papel novo: dez papéis
/// do redesenho teriam de nascer duas vezes, um deles em valores que ninguém ia
/// ver. Manter uma pele que não se veste é dívida, não é opção.
@immutable
class EgTokens extends ThemeExtension<EgTokens> {
  const EgTokens({
    required this.colors,
    required this.text,
    required this.shapes,
    required this.elevations,
    required this.motion,
  });

  /// Os tokens do produto.
  factory EgTokens.evergreen() => EgTokens(
    colors: EvergreenTokens.palette,
    text: EvergreenTokens.type,
    shapes: EvergreenTokens.shapes,
    elevations: EvergreenTokens.elevations,
    motion: EvergreenTokens.motion,
  );

  final EgPalette colors;
  final EgTypeScale text;
  final EgShapes shapes;
  final EgElevations elevations;
  final EgMotion motion;

  EgGradients get gradients => EgGradients(this);

  /// A matriz de estados (repouso, hover, pressed, selecionado…) resolvida
  /// para estes tokens — ver `EgSurfaces`.
  EgSurfaces get surfaces => EgSurfaces(this);

  /// O divisor: o que separa duas linhas dentro do mesmo cartão.
  BorderSide get hairline =>
      BorderSide(color: colors.line, width: shapes.hairline);

  /// A borda de um cartão — luz com alfa, não cinza opaco.
  BorderSide get edge => BorderSide(color: colors.edge, width: shapes.hairline);

  Border get borderAll => Border.fromBorderSide(edge);
  Border get borderBottom => Border(bottom: hairline);
  Border get borderRight => Border(right: hairline);

  @override
  EgTokens copyWith({
    EgPalette? colors,
    EgTypeScale? text,
    EgShapes? shapes,
    EgElevations? elevations,
    EgMotion? motion,
  }) => EgTokens(
    colors: colors ?? this.colors,
    text: text ?? this.text,
    shapes: shapes ?? this.shapes,
    elevations: elevations ?? this.elevations,
    motion: motion ?? this.motion,
  );

  @override
  EgTokens lerp(covariant EgTokens? other, double t) {
    if (other == null) return this;

    return EgTokens(
      colors: EgPalette.lerp(colors, other.colors, t),
      text: EgTypeScale.lerp(text, other.text, t),
      shapes: EgShapes.lerp(shapes, other.shapes, t),
      elevations: EgElevations.lerp(elevations, other.elevations, t),
      motion: EgMotion.lerp(motion, other.motion, t),
    );
  }
}

/// O acesso curto aos tokens de dentro de um widget: `context.eg.colors.accent`.
///
/// `eg`, e não `t`: o prefixo é o mesmo dos componentes compartilhados
/// (`EgButton`, `EgPanel`), e num arquivo de feature `context.eg` diz de onde o
/// valor vem — uma letra sozinha não diria.
extension EgTokensContext on BuildContext {
  /// Os tokens do tema em vigor — ou os do produto, quando não há tema nenhum
  /// acima.
  ///
  /// Cair no tema do produto é a resposta certa para uma subárvore montada sem
  /// o `AppTheme`: um teste de widget que só quer um botão, um `showDialog` com
  /// tema próprio. Um `!` aqui derrubava a árvore inteira nesses casos, e não
  /// deixava nada mais correto — só mais frágil.
  EgTokens get eg =>
      Theme.of(this).extension<EgTokens>() ?? EgTokens.evergreen();
}

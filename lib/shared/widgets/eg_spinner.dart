import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';

/// O indicador de "está acontecendo" do Evergreen.
///
/// Pequeno e monocromático, sempre: ele acompanha um trabalho que já tem lugar
/// na tela — o rótulo de um botão, o corpo de uma lista — e não é ele o
/// conteúdo. Um spinner grande e colorido no meio de uma tela de ferramenta
/// anuncia a espera em vez de anunciar o resultado.
///
/// Existe como componente porque a segunda cópia apareceu: o Pin já tinha a
/// dele, e o botão que resume a reunião precisava da mesma coisa. Duas cópias
/// de um traço de 2px são duas chances de ele deixar de ser o mesmo traço.
class EgSpinner extends StatelessWidget {
  const EgSpinner({super.key, this.size = AppIconSizes.lg, this.color});

  /// Diâmetro. O padrão é o do ícone sozinho — dentro de um botão, quem chama
  /// costuma pedir [AppIconSizes.sm], para o traço não competir com o rótulo.
  final double size;

  /// O padrão é o cinza de texto secundário. Dentro de um botão, quem chama
  /// passa a cor de frente da variante, senão o traço some no fundo verde.
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: _strokeWidth,
          color: color ?? AppColors.textSecondary,
        ),
      );

  /// Fino o bastante para não virar um anel grosso no tamanho pequeno, grosso
  /// o bastante para não sumir num display Retina.
  static const _strokeWidth = 2.0;
}

import 'package:flutter/widgets.dart';

import '../../core/design/eg_tokens.dart';

/// Header de seção em caixa alta — "FIXADOS", "RECENTES", "GERAL".
class EgSectionLabel extends StatelessWidget {
  const EgSectionLabel(
    this.text, {
    super.key,
    this.padding = EdgeInsets.zero,
    this.color,
  });

  final String text;
  final EdgeInsetsGeometry padding;

  /// A cor da etiqueta. `null` é a do tema — o cartão destrutivo passa a dele,
  /// para o aviso começar já no nome da seção.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: color == null
            ? context.eg.text.overline
            : context.eg.text.overline.copyWith(color: color),
      ),
    );
  }
}

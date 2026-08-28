import 'package:flutter/widgets.dart';

import '../../core/design/eg_tokens.dart';

/// Header de seção em caixa alta — "FIXADOS", "RECENTES", "GERAL".
class EgSectionLabel extends StatelessWidget {
  const EgSectionLabel(this.text, {super.key, this.padding = EdgeInsets.zero});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: context.eg.text.overline),
    );
  }
}

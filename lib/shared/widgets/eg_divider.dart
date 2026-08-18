import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';

/// Fio de 1px entre duas linhas de uma lista.
///
/// Fica **fora** da linha, e não como borda dela, porque o fundo de hover da
/// linha tem cantos arredondados: uma borda desenhada dentro dele acompanharia
/// a curva e ficaria torta assim que o mouse passasse.
///
/// Sem altura própria — é a borda que ocupa o pixel. Assim a lista não muda de
/// densidade por causa do divisor.
class EgDivider extends StatelessWidget {
  const EgDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(border: AppBorders.bottom),
      child: SizedBox(height: 0, width: double.infinity),
    );
  }
}

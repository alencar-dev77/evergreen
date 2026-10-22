import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../models/clipboard_item_type.dart';
import '../viewmodels/pin_overlay_state.dart';

/// A fila de pílulas logo abaixo da busca: "Tudo" e os tipos que existem no
/// histórico.
///
/// Sem caixa em volta e sem foco próprio — dentro do painel, a moldura seria um
/// card dentro de um card, e o teclado ali pertence ao campo de busca (quem anda
/// pela fila é o `⌘←` / `⌘→`).
///
/// Encostada à esquerda, e não distribuída na largura: a fila cresce e encolhe
/// conforme o histórico, e opções espalhadas mudariam de lugar a cada tipo que
/// entra — o "Tudo" tem que estar sempre no mesmo ponto.
class PinTypeFilterBar extends StatelessWidget {
  const PinTypeFilterBar({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final PinOverlayState state;
  final ValueChanged<ClipboardItemType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: EgSegmentedControl<ClipboardItemType?>(
          value: state.typeFilter,
          options: state.typeFilterOptions,
          labelOf: (type) => type?.filterLabel ?? 'Tudo',
          // Com todos os tipos no histórico os rótulos não cabem nos 420px
          // do painel: os não escolhidos viram o ícone do tipo — o mesmo da
          // linha da lista —, e a fila continua numa linha só.
          iconOf: (type) => type?.icon,
          onChanged: onChanged,
          bare: true,
          focusable: false,
        ),
      ),
    );
  }
}

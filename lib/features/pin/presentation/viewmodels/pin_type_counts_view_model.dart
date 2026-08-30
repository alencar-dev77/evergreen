import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../models/clipboard_item_type.dart';

/// Quantos itens de cada tipo o histórico guarda.
///
/// Notifier, e não uma leitura solta na tela: a contagem muda quando o painel
/// captura (outro engine) e quando o histórico é apagado (aqui), e os dois
/// casos precisam de um lugar para pedir "conte de novo".
class PinTypeCountsViewModel extends Notifier<Map<ClipboardItemType, int>> {
  @override
  Map<ClipboardItemType, int> build() =>
      ref.read(clipboardRepositoryProvider).countByType();

  void refresh() => state = ref.read(clipboardRepositoryProvider).countByType();
}

final pinTypeCountsProvider =
    NotifierProvider<PinTypeCountsViewModel, Map<ClipboardItemType, int>>(
      PinTypeCountsViewModel.new,
    );

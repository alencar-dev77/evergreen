import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/storage/disk_usage_service.dart';
import 'backup_view_model.dart';

final diskUsageViewModelProvider =
    NotifierProvider<DiskUsageViewModel, DiskUsage?>(DiskUsageViewModel.new);

/// Quanto o Evergreen ocupa no disco, para a tela do aplicativo.
///
/// Nulo enquanto mede: a primeira medida chega um instante depois de a tela
/// montar, e a linha mostra um traço até lá em vez de um "0 B" que mentiria.
class DiskUsageViewModel extends Notifier<DiskUsage?> {
  late final DiskUsageService _service;

  @override
  DiskUsage? build() {
    _service = ref.watch(diskUsageServiceProvider);

    // Um backup novo, ou um que a rotação apagou, muda o total — e é a única
    // coisa que muda o disco com esta tela aberta.
    ref.listen(
      backupViewModelProvider.select((state) => state.backups.length),
      (_, _) => unawaited(refresh()),
    );

    unawaited(refresh());
    return null;
  }

  String get directoryLabel => _service.directoryLabel;

  /// Mede de novo. A tela pede ao montar: o áudio de uma reunião e o backup
  /// automático são escritos no engine da janela 0, que não avisa este.
  Future<void> refresh() async {
    final usage = await _service.measure();
    if (!ref.mounted) return;

    state = usage;
  }

  Future<void> reveal() => _service.reveal();
}

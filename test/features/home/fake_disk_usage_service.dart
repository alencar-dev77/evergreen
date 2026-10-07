import 'package:evergreen/core/storage/disk_usage_service.dart';

/// A pasta do aplicativo medida em memória.
///
/// A tela do aplicativo mede o disco ao montar, e no relógio falso do teste de
/// widget a leitura de verdade nunca responderia.
class FakeDiskUsageService implements DiskUsageService {
  FakeDiskUsageService([this.usage = const DiskUsage()]);

  DiskUsage usage;
  int reveals = 0;

  @override
  Future<DiskUsage> measure() async => usage;

  @override
  Future<void> reveal() async => reveals++;

  @override
  String get directoryLabel => '~/Library/Application Support/evergreen';
}

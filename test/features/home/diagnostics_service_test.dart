import 'package:evergreen/core/diagnostics/diagnostic_report.dart';
import 'package:evergreen/core/diagnostics/log_store.dart';
import 'package:evergreen/core/storage/disk_usage_service.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
import 'package:evergreen/features/home/data/diagnostics_service.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/models/module_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_disk_usage_service.dart';

class _Log implements LogStore {
  @override
  void append(String text) {}

  @override
  Future<List<String>> tail(int count) async => ['erro 1'];

  @override
  Future<void> reveal() async {}

  @override
  String get directoryLabel => '~/Diagnóstico';
}

void main() {
  LocalDiagnosticsService service({
    Future<bool> Function()? accessibility,
    Future<EchoCapabilities> Function()? echo,
    ModuleSettings Function()? modules,
  }) => LocalDiagnosticsService(
    log: _Log(),
    disk: FakeDiskUsageService(const DiskUsage(database: 1024)),
    modules: modules ?? ModuleSettings.new,
    accessibility: accessibility ?? () async => true,
    echoCapabilities:
        echo ??
        () async => const EchoCapabilities(
          microphone: PermissionStatus.granted,
          screenRecording: PermissionStatus.notDetermined,
          summaries: SummaryAvailability.available,
        ),
  );

  test('junta permissões, módulos, banco e o registro', () async {
    final snapshot = await service(
      modules: () => const ModuleSettings(disabled: {EvergreenModule.echo}),
    ).collect();

    expect(snapshot.accessibility, DiagnosticPermission.granted);
    expect(snapshot.microphone, DiagnosticPermission.granted);
    expect(snapshot.screenRecording, DiagnosticPermission.notDetermined);
    expect(snapshot.databaseBytes, 1024);
    expect(snapshot.logTail, ['erro 1']);
    expect(snapshot.modules, contains(('Echo', false)));
    expect(snapshot.modules, contains(('Pin', true)));
  });

  test('abaixo do macOS 26, o Echo não acusa permissão negada', () async {
    final snapshot = await service(
      echo: () async => const EchoCapabilities(
        microphone: PermissionStatus.denied,
        screenRecording: PermissionStatus.denied,
        summaries: SummaryAvailability.unsupportedOS,
      ),
    ).collect();

    expect(snapshot.microphone, DiagnosticPermission.unavailable);
    expect(snapshot.screenRecording, DiagnosticPermission.unavailable);
  });

  test(
    'uma fonte que falha vira "não deu para saber", e o resto sai',
    () async {
      final snapshot = await service(
        accessibility: () async => throw StateError('canal fora'),
        echo: () async => throw StateError('canal fora'),
      ).collect();

      expect(snapshot.accessibility, DiagnosticPermission.unknown);
      expect(snapshot.microphone, DiagnosticPermission.unknown);
      expect(snapshot.logTail, ['erro 1']);
    },
  );
}

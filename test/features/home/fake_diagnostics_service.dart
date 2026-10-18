import 'package:evergreen/core/diagnostics/diagnostic_report.dart';
import 'package:evergreen/features/home/data/diagnostics_service.dart';

/// Diagnóstico em memória, para as telas que montam a seção.
class FakeDiagnosticsService implements DiagnosticsService {
  FakeDiagnosticsService({this.snapshot = sample});

  static const sample = DiagnosticSnapshot(
    appVersion: '1.2.3',
    macOS: 'Version 26.1 (Build 25B78)',
    chip: 'Apple M3',
    modules: [('Pin', true), ('Focus', false)],
    accessibility: DiagnosticPermission.granted,
    microphone: DiagnosticPermission.denied,
    screenRecording: DiagnosticPermission.notDetermined,
    databaseBytes: 4096,
    logTail: [],
  );

  final DiagnosticSnapshot snapshot;

  int logReveals = 0;
  int crashReveals = 0;

  @override
  Future<DiagnosticSnapshot> collect() async => snapshot;

  @override
  String get logLabel => '~/Diagnóstico';

  @override
  String get crashReportsLabel => '~/Library/Logs/DiagnosticReports';

  @override
  Future<void> revealLog() async => logReveals++;

  @override
  Future<void> revealCrashReports() async => crashReveals++;
}

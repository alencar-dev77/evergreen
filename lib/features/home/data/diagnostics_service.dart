import 'dart:io';

import '../../../core/app_info.dart';
import '../../../core/diagnostics/diagnostic_report.dart';
import '../../../core/diagnostics/log_store.dart';
import '../../../core/local_model/local_model.dart';
import '../../../core/storage/disk_usage_service.dart';
import '../../echo/models/echo_capabilities.dart';
import '../models/evergreen_module.dart';
import '../models/module_settings.dart';

/// Junta o que o "Copiar diagnóstico" conta, e abre as pastas de onde ele
/// vem.
///
/// Interface pelo motivo de sempre (`NestFileService`): no relógio falso do
/// teste de widget a resposta do disco e dos canais nunca chega, e o botão
/// ficaria esperando para sempre.
abstract interface class DiagnosticsService {
  Future<DiagnosticSnapshot> collect();

  Future<void> revealLog();

  Future<void> revealCrashReports();

  String get logLabel;

  String get crashReportsLabel;
}

/// A implementação de verdade.
///
/// Cada fonte entra como função, e não como o objeto dono dela, para que
/// a falha de uma — o canal do Echo que não respondeu, o `sysctl` que não
/// existe — vire "não deu para saber" naquela linha, e não um diagnóstico que
/// não sai. Quem pede um diagnóstico está, por definição, num dia em que algo
/// não funciona.
class LocalDiagnosticsService implements DiagnosticsService {
  LocalDiagnosticsService({
    required LogStore log,
    required DiskUsageService disk,
    required ModuleSettings Function() modules,
    required Future<bool> Function() accessibility,
    required Future<EchoCapabilities> Function() echoCapabilities,
    LocalModelChoice Function()? localModel,
  }) : _localModel = localModel,
       _log = log,
       _disk = disk,
       _modules = modules,
       _accessibility = accessibility,
       _echoCapabilities = echoCapabilities;

  final LogStore _log;
  final DiskUsageService _disk;
  final ModuleSettings Function() _modules;
  final Future<bool> Function() _accessibility;
  final Future<EchoCapabilities> Function() _echoCapabilities;
  final LocalModelChoice Function()? _localModel;

  /// Quantas linhas do registro vão junto. O bastante para dois ou três erros
  /// com a pilha, e pouco o bastante para caber numa issue sem rolar.
  static const tailLines = 60;

  /// Onde o macOS guarda os relatórios de falha nativa (`.ips`) de todo app.
  static const _crashReports = 'Library/Logs/DiagnosticReports';

  @override
  String get logLabel => _log.directoryLabel;

  @override
  String get crashReportsLabel => '~/$_crashReports';

  @override
  Future<DiagnosticSnapshot> collect() async {
    final settings = _modules();
    final (microphone, screenRecording) = await _echoPermissions();

    return DiagnosticSnapshot(
      appVersion: AppInfo.version,
      macOS: Platform.operatingSystemVersion,
      chip: await _chip(),
      modules: [
        for (final module in EvergreenModule.values)
          (module.name, settings.isEnabled(module)),
      ],
      accessibility: await _accessibilityPermission(),
      microphone: microphone,
      screenRecording: screenRecording,
      databaseBytes: await _databaseBytes(),
      logTail: await _logTail(),
      localModel: _localModelLabel(),
    );
  }

  String _localModelLabel() {
    final choice = _localModel?.call() ?? LocalModelChoice.apple;

    return switch (choice.source) {
      LocalModelSource.apple => LocalModelChoice.appleName,
      LocalModelSource.lmStudio =>
        choice.isIncomplete
            ? 'LM Studio, sem modelo escolhido'
            : 'LM Studio · ${choice.displayName}',
    };
  }

  Future<List<String>> _logTail() async {
    try {
      return await _log.tail(tailLines);
    } on Object {
      return const ['(não deu para ler o registro)'];
    }
  }

  Future<DiagnosticPermission> _accessibilityPermission() async {
    try {
      return await _accessibility()
          ? DiagnosticPermission.granted
          : DiagnosticPermission.denied;
    } on Object {
      return DiagnosticPermission.unknown;
    }
  }

  Future<(DiagnosticPermission, DiagnosticPermission)>
  _echoPermissions() async {
    try {
      final capabilities = await _echoCapabilities();
      // Abaixo do macOS 26 o canal responde "negada" para as duas, sem
      // perguntar ao sistema — é o resumo indisponível que denuncia o caso.
      if (capabilities.summaries == SummaryAvailability.unsupportedOS) {
        return (
          DiagnosticPermission.unavailable,
          DiagnosticPermission.unavailable,
        );
      }
      return (
        _permission(capabilities.microphone),
        _permission(capabilities.screenRecording),
      );
    } on Object {
      return (DiagnosticPermission.unknown, DiagnosticPermission.unknown);
    }
  }

  static DiagnosticPermission _permission(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted => DiagnosticPermission.granted,
        PermissionStatus.denied => DiagnosticPermission.denied,
        PermissionStatus.notDetermined => DiagnosticPermission.notDetermined,
      };

  /// "Apple M3 Pro". `sysctl`, e não um canal: é uma linha de processo, e o
  /// Evergreen não roda em sandbox.
  Future<String> _chip() async {
    try {
      // Pelo caminho inteiro: o PATH de um app aberto pelo Finder é o do
      // launchd, e não convém depender de ele trazer o `/usr/sbin`.
      final result = await Process.run('/usr/sbin/sysctl', [
        '-n',
        'machdep.cpu.brand_string',
      ]);
      return '${result.stdout}'.trim();
    } on Object {
      return '';
    }
  }

  Future<int?> _databaseBytes() async {
    try {
      return (await _disk.measure()).database;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> revealLog() => _log.reveal();

  /// A pasta pode não existir num Mac em que nada nunca caiu; aí abre a de
  /// cima, em vez do alerta de "pasta não encontrada" do Finder.
  @override
  Future<void> revealCrashReports() async {
    final home = Platform.environment['HOME'] ?? '';
    final reports = Directory('$home/$_crashReports');
    final target = reports.existsSync() ? reports : reports.parent;

    await Process.run('open', [target.path]);
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/diagnostics/diagnostic_report.dart';
import '../../data/diagnostics_service.dart';

final diagnosticsViewModelProvider =
    NotifierProvider<DiagnosticsViewModel, bool>(DiagnosticsViewModel.new);

/// O "Copiar diagnóstico" da tela do aplicativo.
///
/// O estado é só "acabou de copiar?": a confirmação toma o lugar da descrição
/// da linha por 3 s e some — a mesma duração do "Resumo copiado" do Echo
/// (`components.md`). Um "copiado" permanente vira sujeira.
class DiagnosticsViewModel extends Notifier<bool> {
  late final DiagnosticsService _service;

  Timer? _copiedTimer;

  /// Juntar o diagnóstico pergunta a dois canais e ao disco; um segundo
  /// clique no meio copiaria duas vezes.
  bool _copying = false;

  static const _copiedDuration = Duration(seconds: 3);

  @override
  bool build() {
    _service = ref.watch(diagnosticsServiceProvider);
    ref.onDispose(() => _copiedTimer?.cancel());
    return false;
  }

  String get logLabel => _service.logLabel;

  String get crashReportsLabel => _service.crashReportsLabel;

  Future<void> copy() async {
    if (_copying) return;
    _copying = true;
    try {
      final snapshot = await _service.collect();
      await Clipboard.setData(
        ClipboardData(text: DiagnosticReport.render(snapshot)),
      );
    } finally {
      _copying = false;
    }
    if (!ref.mounted) return;

    state = true;
    _copiedTimer?.cancel();
    _copiedTimer = Timer(_copiedDuration, () {
      if (ref.mounted) state = false;
    });
  }

  Future<void> revealLog() => _service.revealLog();

  Future<void> revealCrashReports() => _service.revealCrashReports();
}

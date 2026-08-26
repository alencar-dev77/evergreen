import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/providers.dart';
import '../../../../core/app_info.dart';
import '../../../../core/storage/export_service.dart';

/// O que a seção de exportação das preferências mostra.
@immutable
class ExportState {
  const ExportState({this.directoryLabel = '', this.message});

  /// Onde os arquivos ficam, escrito para uma pessoa ler.
  final String directoryLabel;

  /// A última coisa que aconteceu, em uma frase.
  ///
  /// Exportar não tem feedback visível por si — o arquivo nasce numa pasta que
  /// não está na tela —, então a frase é a única prova de que algo aconteceu.
  /// Ela some sozinha: um aviso de sucesso permanente vira sujeira.
  final String? message;

  ExportState copyWith({String? message, bool clearMessage = false}) {
    return ExportState(
      directoryLabel: directoryLabel,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final exportViewModelProvider = NotifierProvider<ExportViewModel, ExportState>(
  ExportViewModel.new,
);

/// Exportar os dados, a partir da tela de preferências.
///
/// Síncrona pelo mesmo motivo do backup: escrever o JSON de um banco desta
/// ordem de grandeza termina em milissegundos, e fingir um estado de
/// carregamento só piscaria a tela.
class ExportViewModel extends Notifier<ExportState> {
  late final ExportService _service;
  Timer? _messageTimer;

  /// Quanto tempo a frase de resultado fica na tela.
  static const _messageDuration = Duration(seconds: 5);

  @override
  ExportState build() {
    _service = ref.watch(exportServiceProvider);
    ref.onDispose(() => _messageTimer?.cancel());

    return ExportState(directoryLabel: _service.directoryLabel);
  }

  void exportNow() {
    try {
      final file = _service.create(appVersion: AppInfo.version);
      _finish('Exportado para ${p.basename(file.path)}.');
    } catch (error) {
      _finish('Não deu para exportar: ${_reason(error)}');
    }
  }

  Future<void> reveal() => _service.reveal();

  void _finish(String message) {
    state = state.copyWith(message: message);

    _messageTimer?.cancel();
    _messageTimer = Timer(_messageDuration, () {
      if (!ref.mounted) return;
      state = state.copyWith(clearMessage: true);
    });
  }

  /// O motivo em uma linha — na tela não pode aparecer um stack trace.
  static String _reason(Object error) =>
      error.toString().split('\n').first.trim();
}

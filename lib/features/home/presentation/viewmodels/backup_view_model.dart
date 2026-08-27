import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/storage/backup_service.dart';
import '../../models/backup_file.dart';

/// O que a seção de backup das preferências mostra.
@immutable
class BackupState {
  const BackupState({
    this.directoryLabel = '',
    this.backups = const [],
    this.selectedPath,
    this.message,
  });

  /// Onde os arquivos ficam, escrito para uma pessoa ler.
  final String directoryLabel;

  /// Os arquivos da pasta, do mais recente para o mais antigo.
  final List<BackupFile> backups;

  /// O backup escolhido para restaurar.
  ///
  /// Por caminho, e não como objeto: a lista é relida do disco a cada operação,
  /// e um objeto guardado aqui envelheceria em silêncio.
  final String? selectedPath;

  /// A última coisa que aconteceu, em uma frase.
  ///
  /// Existe porque criar um backup e restaurar um não têm feedback visível por
  /// si: no primeiro caso a lista ganha uma linha (e essa se vê), mas no
  /// segundo o que mudou está em outra tela do aplicativo. A frase some sozinha
  /// depois de alguns segundos — um aviso permanente de sucesso vira sujeira.
  final String? message;

  BackupFile? get selected {
    if (selectedPath == null) return null;

    for (final backup in backups) {
      if (backup.path == selectedPath) return backup;
    }

    return null;
  }

  bool get isEmpty => backups.isEmpty;

  /// O mais recente que o próprio Evergreen escreveu — o "último backup".
  BackupFile? get latest {
    for (final backup in backups) {
      if (backup.isOurs) return backup;
    }

    return null;
  }

  BackupState copyWith({
    List<BackupFile>? backups,
    String? selectedPath,
    bool clearSelection = false,
    String? message,
    bool clearMessage = false,
  }) {
    return BackupState(
      directoryLabel: directoryLabel,
      backups: backups ?? this.backups,
      selectedPath: clearSelection ? null : selectedPath ?? this.selectedPath,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final backupViewModelProvider = NotifierProvider<BackupViewModel, BackupState>(
  BackupViewModel.new,
);

/// Fazer e restaurar backup, a partir da tela de preferências.
///
/// As operações são síncronas porque o `VACUUM INTO` e a cópia entre tabelas
/// também são: num banco desta ordem de grandeza as duas terminam em
/// milissegundos, e fingir um estado de carregamento só piscaria a tela.
class BackupViewModel extends Notifier<BackupState> {
  late final BackupService _service;
  Timer? _messageTimer;

  /// Quanto tempo a frase de resultado fica na tela.
  static const _messageDuration = Duration(seconds: 5);

  @override
  BackupState build() {
    _service = ref.watch(backupServiceProvider);
    ref.onDispose(() => _messageTimer?.cancel());

    return BackupState(
      directoryLabel: _service.directoryLabel,
      backups: _service.list(),
    );
  }

  /// Relê a pasta. A tela pede ao montar: o backup automático roda no engine da
  /// janela flutuante, e este é o do Hub — um arquivo criado por lá não chega
  /// aqui sozinho.
  void refresh() => state = state.copyWith(backups: _service.list());

  void select(String path) => state = state.copyWith(selectedPath: path);

  void createNow() {
    try {
      _service.create();
      _finish('Backup criado.');
    } catch (error) {
      _finish('Não deu para criar o backup: ${_reason(error)}');
    }
  }

  /// Restaura o backup escolhido.
  ///
  /// A rede — o estado de agora guardado num arquivo antes de a primeira linha
  /// ser apagada — é do serviço, não daqui: ela precisa proteger da limpeza
  /// automática o arquivo que está prestes a ser lido, e só quem lê sabe qual
  /// é. Ver [BackupService.restore].
  void restoreSelected() {
    final backup = state.selected;
    if (backup == null) return;

    try {
      _service.restore(backup);
      _finish(
        'Backup restaurado. O estado anterior ficou guardado na pasta, e os '
        'painéis mostram o conteúdo novo ao abrir.',
      );
    } catch (error) {
      _finish('Não deu para restaurar: ${_reason(error)}');
    }
  }

  Future<void> reveal() => _service.reveal();

  void _finish(String message) {
    state = state.copyWith(backups: _service.list(), message: message);

    _messageTimer?.cancel();
    _messageTimer = Timer(_messageDuration, () {
      if (!ref.mounted) return;
      state = state.copyWith(clearMessage: true);
    });
  }

  /// O motivo em uma linha. A mensagem do SQLite e a do sistema de arquivos já
  /// vêm curtas; o que não pode aparecer na tela é um stack trace.
  static String _reason(Object error) =>
      error.toString().split('\n').first.trim();
}

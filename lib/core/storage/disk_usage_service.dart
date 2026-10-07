import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Quanto o Evergreen ocupa no disco, separado pelo que ele guarda.
///
/// As partes são as pastas que a pessoa pode ver no Finder — o banco, o áudio
/// das reuniões, os backups e as exportações. O que não é nenhuma delas entra
/// no total e só nele: um arquivo solto não merece uma linha na tela.
@immutable
class DiskUsage {
  const DiskUsage({
    this.database = 0,
    this.meetings = 0,
    this.backups = 0,
    this.exports = 0,
    this.other = 0,
  });

  /// O banco com o log do WAL e o índice dele: os três são o mesmo dado, e o
  /// WAL sozinho pode ter o tamanho do banco até o próximo checkpoint.
  final int database;

  /// O áudio das reuniões do Echo — a pasta `Reuniões`.
  final int meetings;

  final int backups;
  final int exports;
  final int other;

  int get total => database + meetings + backups + exports + other;
}

/// Quem mede a pasta do aplicativo.
///
/// Interface pelo motivo do `NestFileService`: no relógio falso do teste de
/// widget a resposta de uma leitura de disco nunca chega, e a tela ficaria
/// esperando pelo número para sempre. O disco de verdade é assunto do teste do
/// [LocalDiskUsageService].
abstract interface class DiskUsageService {
  Future<DiskUsage> measure();

  /// Abre a pasta do aplicativo no Finder.
  Future<void> reveal();

  /// O caminho da pasta como se escreve para uma pessoa (`~/Library/…`).
  String get directoryLabel;
}

class LocalDiskUsageService implements DiskUsageService {
  LocalDiskUsageService({required Directory directory})
    : _directory = directory;

  final Directory _directory;

  /// Os nomes das subpastas são os mesmos que os providers usam para criá-las
  /// (`Reuniões`, `Backups`, `Exportações`).
  static const _meetings = 'Reuniões';
  static const _backups = 'Backups';
  static const _exports = 'Exportações';
  static const _databasePrefix = 'evergreen.db';

  @override
  Future<DiskUsage> measure() async {
    if (!await _directory.exists()) return const DiskUsage();

    var database = 0;
    var meetings = 0;
    var backups = 0;
    var exports = 0;
    var other = 0;

    await for (final entity in _directory.list(followLinks: false)) {
      final name = p.basename(entity.path);

      if (entity is Directory) {
        final size = await _sizeOf(entity);
        switch (name) {
          case _meetings:
            meetings += size;
          case _backups:
            backups += size;
          case _exports:
            exports += size;
          default:
            other += size;
        }
      } else if (entity is File) {
        final size = (await entity.stat()).size;
        if (name.startsWith(_databasePrefix)) {
          database += size;
        } else {
          other += size;
        }
      }
    }

    return DiskUsage(
      database: database,
      meetings: meetings,
      backups: backups,
      exports: exports,
      other: other,
    );
  }

  /// Soma os arquivos debaixo de [directory]. Um arquivo que some entre a
  /// listagem e o `stat` — o áudio que a varredura do Echo acabou de apagar —
  /// conta como zero, em vez de derrubar a medida inteira.
  static Future<int> _sizeOf(Directory directory) async {
    var total = 0;

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;

      try {
        total += (await entity.stat()).size;
      } on FileSystemException {
        continue;
      }
    }

    return total;
  }

  /// `open` do próprio macOS, como o `BackupService.reveal`.
  @override
  Future<void> reveal() async {
    await Process.run('open', [_directory.path]);
  }

  @override
  String get directoryLabel {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return _directory.path;

    return _directory.path.startsWith(home)
        ? '~${_directory.path.substring(home.length)}'
        : _directory.path;
  }
}

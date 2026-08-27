import 'dart:io';

import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/storage/backup_service.dart';
import 'package:evergreen/core/storage/export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Um serviço de backup sobre um banco em memória e uma pasta temporária.
///
/// Toda tela de preferências do aplicativo passa por aqui: a seção de backup
/// lê a pasta ao montar, e sem isto o teste pediria o banco de verdade — que
/// não existe sob `flutter test`.
///
/// A pasta e o banco são desmontados com o teste.
BackupService temporaryBackupService({Database? database}) {
  final directory = Directory.systemTemp.createTempSync('evergreen-backup');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  final db = database ?? sqlite3.openInMemory();
  if (database == null) {
    AppDatabase.migrate(db);
    addTearDown(db.close);
  }

  return BackupService(
    database: db,
    directory: Directory('${directory.path}/Backups'),
  );
}

/// Um serviço de exportação sobre um banco em memória e uma pasta temporária.
///
/// Pelo mesmo motivo do backup: a seção de exportação lê a pasta ao montar.
ExportService temporaryExportService({Database? database}) {
  final directory = Directory.systemTemp.createTempSync('evergreen-export');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  final db = database ?? sqlite3.openInMemory();
  if (database == null) {
    AppDatabase.migrate(db);
    addTearDown(db.close);
  }

  return ExportService(
    database: db,
    directory: Directory('${directory.path}/Exports'),
  );
}

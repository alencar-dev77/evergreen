import 'dart:io';

import 'package:evergreen/core/storage/disk_usage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('evergreen-disk');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  void write(String relative, int bytes) {
    File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 0));
  }

  test('separa a pasta do aplicativo pelo que ela guarda', () async {
    write('evergreen.db', 100);
    write('evergreen.db-wal', 40);
    write('evergreen.db-shm', 8);
    write('Reuniões/a.m4a', 500);
    write('Reuniões/b.m4a', 250);
    write('Backups/evergreen-backup-1.db', 120);
    write('Exportações/reuniao.md', 12);
    write('solto.txt', 3);

    final usage = await LocalDiskUsageService(directory: root).measure();

    // O WAL e o índice dele são o mesmo dado do banco.
    expect(usage.database, 148);
    expect(usage.meetings, 750);
    expect(usage.backups, 120);
    expect(usage.exports, 12);
    expect(usage.other, 3);
    expect(usage.total, 1033);
  });

  test('pasta que ainda não existe ocupa zero', () async {
    final missing = Directory(p.join(root.path, 'nada'));

    final usage = await LocalDiskUsageService(directory: missing).measure();

    expect(usage.total, 0);
  });
}

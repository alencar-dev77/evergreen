import 'dart:io';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/storage/backup_service.dart';
import 'package:evergreen/features/home/presentation/viewmodels/backup_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late Directory root;
  late BackupService service;

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);

    root = Directory.systemTemp.createTempSync('evergreen-backup-vm');
    service = BackupService(
      database: db,
      directory: Directory('${root.path}/Backups'),
    );
  });

  tearDown(() {
    db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ProviderContainer containerWith(BackupService backup) {
    final container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(backup)],
    );
    addTearDown(container.dispose);
    return container;
  }

  void insertItem(String content, {int copiedAt = 1}) {
    db.execute(
      'INSERT INTO clipboard_items (content, type, is_pinned, copied_at) '
      "VALUES (?, 'text', 0, ?);",
      [content, copiedAt],
    );
  }

  test('fazer backup agora põe o arquivo na lista', () {
    final container = containerWith(service);
    expect(container.read(backupViewModelProvider).isEmpty, isTrue);

    container.read(backupViewModelProvider.notifier).createNow();

    final state = container.read(backupViewModelProvider);
    expect(state.backups, hasLength(1));
    expect(state.latest, isNotNull);
    expect(state.message, 'Backup criado.');
  });

  test('restaurar guarda o estado de agora antes de trocar tudo', () {
    insertItem('conteúdo antigo');
    final backup = service.create(at: DateTime(2026, 8, 20, 10));

    db.execute('DELETE FROM clipboard_items;');
    insertItem('conteúdo de agora', copiedAt: 2);

    final container = containerWith(service);
    final viewModel = container.read(backupViewModelProvider.notifier)
      ..refresh()
      ..select(backup.path);

    viewModel.restoreSelected();

    // O conteúdo voltou...
    final restored = db
        .select('SELECT content FROM clipboard_items;')
        .map((row) => row['content'] as String);
    expect(restored, ['conteúdo antigo']);

    // ...e o que estava na tela antes virou um backup novo, porque ter clicado
    // na linha errada não pode custar o dia de trabalho de hoje.
    final state = container.read(backupViewModelProvider);
    expect(state.backups, hasLength(2));
    expect(state.message, startsWith('Backup restaurado'));
  });

  test('sem nada escolhido, restaurar não faz nada', () {
    service.create();

    final container = containerWith(service);
    container.read(backupViewModelProvider.notifier)
      ..refresh()
      ..restoreSelected();

    expect(container.read(backupViewModelProvider).backups, hasLength(1));
    expect(container.read(backupViewModelProvider).message, isNull);
  });

  test('a lista vem do mais recente para o mais antigo', () {
    service.create(at: DateTime(2026, 8, 20, 10));
    service.create(at: DateTime(2026, 8, 24, 10));
    service.create(at: DateTime(2026, 8, 22, 10));

    final backups = containerWith(
      service,
    ).read(backupViewModelProvider).backups;

    expect(backups.map((backup) => backup.createdAt.day), [24, 22, 20]);
  });

  test('falhar ao gravar vira uma frase na tela, e não uma exceção', () {
    // Uma "pasta" que na verdade é um arquivo: criar dentro dela é impossível.
    final blocked = File('${root.path}/nao-e-pasta')..writeAsStringSync('x');
    final broken = BackupService(
      database: db,
      directory: Directory('${blocked.path}/Backups'),
    );

    final container = containerWith(broken);
    container.read(backupViewModelProvider.notifier).createNow();

    final message = container.read(backupViewModelProvider).message;
    expect(message, startsWith('Não deu para criar o backup'));
    // Uma linha só: a tela mostra o motivo, nunca um stack trace.
    expect(message, isNot(contains('\n')));
  });
}

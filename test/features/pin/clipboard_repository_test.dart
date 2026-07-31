import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/pin/data/clipboard_repository.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Cobre a ordenação dos fixados direto no SQLite — o `FakeClipboardRepository`
/// imita esse comportamento nos testes de widget, e é aqui que se confere que a
/// imitação corresponde ao banco de verdade.
void main() {
  late Database database;
  late SqliteClipboardRepository repository;

  setUp(() {
    database = sqlite3.openInMemory();
    AppDatabase.migrate(database);
    repository = SqliteClipboardRepository(database);
  });

  tearDown(() => database.close());

  /// Relógio de fixação do fixture, em milissegundos.
  ///
  /// `setPinned` carimba `DateTime.now()`, e várias chamadas em sequência caem
  /// no mesmo milissegundo — no teste os fixados empatariam e a ordem cairia no
  /// desempate por data de cópia. Carimbar à mão é o que dá a cada um a posição
  /// que ele teria se a pessoa os tivesse fixado em momentos diferentes.
  var clock = 1000;

  /// Insere e fixa, na ordem da chamada — é o que define a ordem dos fixados.
  int pin(String content) {
    final item = repository.upsert(ClipboardItem.capture(content));
    repository.setPinned(item.id!, isPinned: true);
    database.execute(
      'UPDATE clipboard_items SET pinned_at = ? WHERE id = ?;',
      [clock++, item.id],
    );
    return item.id!;
  }

  List<String> pinnedOrder() => repository
      .loadAll()
      .where((item) => item.isPinned)
      .map((item) => item.content)
      .toList();

  test('troca dois fixados de lugar', () {
    final alfa = pin('alfa');
    final beta = pin('beta');
    pin('gama');

    expect(pinnedOrder(), ['alfa', 'beta', 'gama']);

    repository.swapPinnedOrder(alfa, beta);

    expect(pinnedOrder(), ['beta', 'alfa', 'gama']);
  });

  test('a troca é simétrica: desfazer volta à ordem original', () {
    final alfa = pin('alfa');
    final beta = pin('beta');

    repository.swapPinnedOrder(alfa, beta);
    repository.swapPinnedOrder(alfa, beta);

    expect(pinnedOrder(), ['alfa', 'beta']);
  });

  test('troca funciona mesmo com os dois fixados no mesmo instante', () {
    // Dois `setPinned` no mesmo milissegundo empatam o `pinned_at`; sem o
    // desempate a troca escreveria o mesmo valor nos dois e nada se moveria.
    final alfa = pin('alfa');
    final beta = pin('beta');
    database.execute('UPDATE clipboard_items SET pinned_at = 1000;');

    repository.swapPinnedOrder(alfa, beta);

    final order = pinnedOrder();
    expect(order, hasLength(2));
    expect(order.first, isNot(order.last));
  });

  test('não mexe em item que não está fixado', () {
    final alfa = pin('alfa');
    final solto = repository.upsert(ClipboardItem.capture('solto')).id!;

    repository.swapPinnedOrder(alfa, solto);

    expect(pinnedOrder(), ['alfa']);
    final recente = repository.loadAll().firstWhere((it) => it.id == solto);
    expect(recente.isPinned, isFalse);
    expect(recente.pinnedAt, isNull);
  });

  test('o apelido é guardado e sobrevive a copiar o item de novo', () {
    final item = repository.upsert(ClipboardItem.capture('12345678900'));

    repository.setAlias(item.id!, 'chave pix');
    // Recopiar passa pelo mesmo `ON CONFLICT` da captura: só a data muda.
    repository.upsert(ClipboardItem.capture('12345678900'));

    final stored = repository.loadAll().single;
    expect(stored.alias, 'chave pix');
    expect(stored.content, '12345678900');
  });

  test('apelido em branco apaga o que havia', () {
    final item = repository.upsert(ClipboardItem.capture('12345678900'));
    repository.setAlias(item.id!, 'chave pix');

    repository.setAlias(item.id!, '   ');

    expect(repository.loadAll().single.alias, isNull);
  });

  test('fixar não mexe no apelido', () {
    final item = repository.upsert(ClipboardItem.capture('12345678900'));
    repository.setAlias(item.id!, 'chave pix');

    repository.setPinned(item.id!, isPinned: true);

    expect(repository.loadAll().single.alias, 'chave pix');
  });

  test('desafixar e refixar joga o item para o fim dos fixados', () {
    final alfa = pin('alfa');
    pin('beta');

    repository.setPinned(alfa, isPinned: false);
    repository.setPinned(alfa, isPinned: true);

    expect(pinnedOrder(), ['beta', 'alfa']);
  });
}

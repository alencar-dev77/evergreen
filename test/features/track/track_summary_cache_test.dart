import 'package:evergreen/features/track/data/track_summary_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O parágrafo que o modelo já escreveu, guardado no plist.
///
/// Não é uma tabela de propósito: o Track não escreve no banco, e este texto é
/// derivado do que os outros módulos gravaram — se sumir, refaz-se.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrackSummaryCache cache;

  final terca = DateTime(2026, 8, 18);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = TrackSummaryCache(await SharedPreferences.getInstance());
  });

  test('devolve o que guardou, para a mesma assinatura', () async {
    await cache.write(terca, '2/50', 'Foi um dia de duas sessões.');

    expect(cache.read(terca, '2/50'), 'Foi um dia de duas sessões.');
  });

  test('assinatura diferente é dia diferente, e o texto não serve', () async {
    await cache.write(terca, '2/50', 'Foi um dia de duas sessões.');

    // Uma sessão a mais entrou depois que o parágrafo foi escrito: ele passaria
    // a contradizer os números ao lado dele na tela.
    expect(cache.read(terca, '3/75'), isNull);
  });

  test('dia sem parágrafo guardado responde nada', () {
    expect(cache.read(terca, '2/50'), isNull);
  });

  test('guarda os últimos dias e esquece os mais antigos', () async {
    for (var day = 1; day <= TrackSummaryCache.maxDays + 3; day++) {
      await cache.write(DateTime(2026, 8, day), 'sig', 'dia $day');
    }

    // O plist não pode virar um depósito de parágrafos de meses atrás — e um
    // dia daquela distância nem chega a ser aberto, porque o histórico do Focus
    // zera toda segunda.
    expect(cache.read(DateTime(2026, 8, 1), 'sig'), isNull);
    expect(cache.read(DateTime(2026, 8, 3), 'sig'), isNull);
    expect(cache.read(DateTime(2026, 8, 4), 'sig'), 'dia 4');
    expect(
      cache.read(DateTime(2026, 8, TrackSummaryCache.maxDays + 3), 'sig'),
      'dia ${TrackSummaryCache.maxDays + 3}',
    );
  });

  test('plist ilegível é cache vazio, não uma exceção', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.track.summaries': 'isto não é json',
    });
    final broken = TrackSummaryCache(await SharedPreferences.getInstance());

    expect(broken.read(terca, '2/50'), isNull);
    // E continua servindo para escrever por cima.
    await broken.write(terca, '2/50', 'agora sim');
    expect(broken.read(terca, '2/50'), 'agora sim');
  });
}

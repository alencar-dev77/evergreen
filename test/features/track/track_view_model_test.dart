import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/track/models/track_day.dart';
import 'package:evergreen/features/track/models/track_range.dart';
import 'package:evergreen/features/track/presentation/viewmodels/track_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../echo/fake_echo_channel.dart';
import 'fake_track_repository.dart';

void main() {
  // O cache do parágrafo mora no plist, e o plist de teste precisa do binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Quarta-feira às 15h30 — "ontem" cai na mesma semana.
  final now = DateTime(2026, 8, 19, 15, 30);
  DateTime day(int daysAgo) => DateTime(now.year, now.month, now.day - daysAgo);

  TrackDay withFocus(int daysAgo, int minutes) => TrackDay(
    date: day(daysAgo),
    focus: [
      TrackEntry(
        at: day(daysAgo).add(const Duration(hours: 9)),
        duration: Duration(minutes: minutes),
      ),
    ],
  );

  late FakeTrackRepository repository;
  late FakeEchoChannel channel;
  late SharedPreferences prefs;

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [
        trackRepositoryProvider.overrideWithValue(repository),
        echoChannelProvider.overrideWithValue(channel),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    repository = FakeTrackRepository([withFocus(0, 25), withFocus(1, 50)]);
    channel = FakeEchoChannel();

    // Um plist limpo por teste: o cache do parágrafo sobrevive de propósito
    // entre aberturas do Hub, e sobreviveria entre os testes também.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('a tela abre na semana, com hoje na primeira linha', () {
    final state = containerWith().read(trackViewModelProvider);

    expect(state.range, TrackRange.week);
    expect(state.days.first.date, day(0));
    expect(repository.loadedSince, DateTime(2026, 8, 17)); // segunda-feira
  });

  test('hoje entra na lista mesmo sem nada registrado', () {
    repository.days = [withFocus(2, 25)];

    final state = containerWith().read(trackViewModelProvider);

    expect(state.days.first.date, day(0));
    expect(state.days.first.isEmpty, isTrue);
  });

  test('o recorte de hoje relê a partir da meia-noite', () {
    final container = containerWith();
    container.read(trackViewModelProvider.notifier).setRange(TrackRange.today);

    expect(container.read(trackViewModelProvider).range, TrackRange.today);
    expect(repository.loadedSince, DateTime(2026, 8, 19));
  });

  test('trocar de recorte não fecha o dia aberto que continua na lista', () {
    final container = containerWith();
    final viewModel = container.read(trackViewModelProvider.notifier);

    viewModel.select(day(0));
    viewModel.setRange(TrackRange.today);

    expect(container.read(trackViewModelProvider).selectedDate, day(0));
  });

  test('o dia que sai do recorte deixa de estar aberto', () {
    final container = containerWith();
    final viewModel = container.read(trackViewModelProvider.notifier);

    viewModel.select(day(1));
    viewModel.setRange(TrackRange.today);

    // Sem isto sobraria uma região de 480px mostrando um dia que a lista ao
    // lado já não tem.
    expect(container.read(trackViewModelProvider).selectedDate, isNull);
  });

  test('abrir um dia pede o parágrafo uma vez só', () async {
    final container = containerWith();
    final viewModel = container.read(trackViewModelProvider.notifier);

    viewModel.select(day(0));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(trackViewModelProvider).selectedSummary.text,
      'resumo',
    );

    viewModel.closeSelection();
    viewModel.select(day(0));
    await Future<void>.delayed(Duration.zero);

    expect(channel.summarizedTexts, hasLength(1));
  });

  test('o parágrafo volta na abertura seguinte, sem pedir de novo', () async {
    final first = containerWith();
    first.read(trackViewModelProvider.notifier).select(day(0));
    await Future<void>.delayed(Duration.zero);
    expect(channel.summarizedTexts, hasLength(1));

    // O Hub fechou e abriu — outro container, o mesmo plist. Ontem não muda
    // mais, e reescrever a mesma frase custaria o modelo de novo.
    first.dispose();
    final second = containerWith();
    second.read(trackViewModelProvider.notifier).select(day(0));
    await Future<void>.delayed(Duration.zero);

    expect(second.read(trackViewModelProvider).selectedSummary.text, 'resumo');
    expect(channel.summarizedTexts, hasLength(1));
  });

  test(
    'o parágrafo guardado é descartado se o dia mudou desde então',
    () async {
      final first = containerWith();
      first.read(trackViewModelProvider.notifier).select(day(0));
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      // Uma sessão a mais no mesmo dia: a assinatura muda, e o texto guardado
      // fala de um dia que não é mais este.
      repository.days = [
        TrackDay(
          date: day(0),
          focus: [
            TrackEntry(
              at: day(0).add(const Duration(hours: 9)),
              duration: const Duration(minutes: 25),
            ),
            TrackEntry(
              at: day(0).add(const Duration(hours: 14)),
              duration: const Duration(minutes: 30),
            ),
          ],
        ),
      ];

      final second = containerWith();
      // Nada de resumo velho na tela antes mesmo de alguém abrir o dia.
      expect(second.read(trackViewModelProvider).summaries, isEmpty);

      second.read(trackViewModelProvider.notifier).select(day(0));
      await Future<void>.delayed(Duration.zero);

      // Foi reescrito, e não reaproveitado.
      expect(channel.summarizedTexts, hasLength(2));
    },
  );

  test('o modelo indisponível não é guardado como resposta', () async {
    channel.failWith = const EchoException('unsupported_os', 'macOS antigo');

    final first = containerWith();
    first.read(trackViewModelProvider.notifier).select(day(0));
    await Future<void>.delayed(Duration.zero);
    expect(first.read(trackViewModelProvider).selectedSummary.hasText, isFalse);
    first.dispose();

    // "O modelo não estava disponível" é uma condição da máquina naquele
    // instante, não um fato sobre o dia: na abertura seguinte se tenta de novo.
    channel.failWith = null;
    final second = containerWith();
    second.read(trackViewModelProvider.notifier).select(day(0));
    await Future<void>.delayed(Duration.zero);

    expect(second.read(trackViewModelProvider).selectedSummary.text, 'resumo');
  });

  test('o parágrafo é descartado quando o dia muda por baixo dele', () async {
    final container = containerWith();
    final viewModel = container.read(trackViewModelProvider.notifier);

    viewModel.select(day(0));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(trackViewModelProvider).selectedSummary.hasText,
      isTrue,
    );

    // Uma sessão registrada com o Hub aberto: os números mudam, e o parágrafo
    // que falava em uma sessão passaria a mentir ao lado deles.
    repository.days = [
      TrackDay(
        date: day(0),
        focus: [
          TrackEntry(
            at: day(0).add(const Duration(hours: 9)),
            duration: const Duration(minutes: 25),
          ),
          TrackEntry(
            at: day(0).add(const Duration(hours: 14)),
            duration: const Duration(minutes: 40),
          ),
        ],
      ),
      withFocus(1, 50),
    ];
    viewModel.refresh();

    expect(
      container.read(trackViewModelProvider).selectedSummary.hasText,
      isFalse,
    );
  });

  test('o balanço soma os dias do recorte', () {
    final totals = containerWith().read(trackViewModelProvider).totals;

    expect(totals.focus, const Duration(minutes: 75));
    expect(totals.focusSessions, 2);
  });
}

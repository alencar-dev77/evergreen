import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/leaf/models/leaf_note.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_state.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/fake_notification_service.dart';
import 'fake_leaf_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLeafRepository repository;
  late FakeNotificationService notifications;

  final clock = DateTime(2026, 8, 4, 10);

  setUp(() {
    repository = FakeLeafRepository();
    notifications = FakeNotificationService();
  });

  ProviderContainer containerFor() {
    final container = ProviderContainer(
      overrides: [
        leafRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => clock),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );

    addTearDown(container.dispose);
    return container;
  }

  LeafState stateOf(ProviderContainer container) =>
      container.read(leafViewModelProvider);

  LeafViewModel viewModelOf(ProviderContainer container) =>
      container.read(leafViewModelProvider.notifier);

  /// Cola [count] anotações na parede, da vaga 1 em diante.
  void fill(ProviderContainer container, int count) {
    final viewModel = viewModelOf(container);

    for (var i = 1; i <= count; i++) {
      viewModel.startNote();
      viewModel.commitEdit('anotação $i');
    }
  }

  test('anotar ocupa a primeira vaga livre e guarda o texto', () {
    final container = containerFor();

    viewModelOf(container).startNote();
    expect(stateOf(container).editingSlot, 1);
    expect(stateOf(container).isDraft, isTrue);

    viewModelOf(container).commitEdit('ligar pro contador');

    final note = stateOf(container).noteAt(1);
    expect(note?.content, 'ligar pro contador');
    expect(stateOf(container).isEditing, isFalse);
    expect(repository.loadAll(), hasLength(1));
  });

  test('rascunho em branco não vira anotação', () {
    final container = containerFor();

    viewModelOf(container).startNote();
    viewModelOf(container).commitEdit('   ');

    expect(stateOf(container).notes, isEmpty);
    expect(repository.loadAll(), isEmpty);
  });

  test('esvaziar o texto de uma anotação existente apaga o cartão', () {
    final container = containerFor();
    fill(container, 1);

    viewModelOf(container).editSlot(1);
    viewModelOf(container).commitEdit('');

    expect(stateOf(container).notes, isEmpty);
    expect(repository.loadAll(), isEmpty);
  });

  test('quebra de linha é preservada — é o ⇧⏎ separando dois assuntos', () {
    final container = containerFor();

    viewModelOf(container).startNote();
    viewModelOf(container).commitEdit('duas\nlinhas');

    expect(stateOf(container).noteAt(1)?.content, 'duas\nlinhas');
  });

  test('linha em branco do ⇧⏎ duplo é preservada — separa dois blocos', () {
    final container = containerFor();

    viewModelOf(container).startNote();
    viewModelOf(container).commitEdit('topo\n\nfundo');

    expect(stateOf(container).noteAt(1)?.content, 'topo\n\nfundo');
  });

  test('linhas em branco a mais viram uma só', () {
    final container = containerFor();

    viewModelOf(container).startNote();
    viewModelOf(container).commitEdit('\n\ntopo\n\n\n\nfundo\n\n');

    expect(stateOf(container).noteAt(1)?.content, 'topo\n\nfundo');
  });

  test('desistir do rascunho não deixa rastro', () {
    final container = containerFor();

    viewModelOf(container).startNote();
    viewModelOf(container).cancelEdit();

    expect(stateOf(container).isEditing, isFalse);
    expect(stateOf(container).notes, isEmpty);
  });

  test('a parede para em nove — a décima não abre cartão', () {
    final container = containerFor();
    fill(container, LeafNote.maxNotes);

    expect(stateOf(container).isFull, isTrue);
    expect(stateOf(container).firstFreeSlot, isNull);

    viewModelOf(container).startNote();

    expect(stateOf(container).isEditing, isFalse);
    expect(stateOf(container).notes, hasLength(LeafNote.maxNotes));
  });

  test('apagar fecha o buraco: as de baixo sobem uma vaga', () {
    final container = containerFor();
    fill(container, 4);

    viewModelOf(container).selectSlot(2);
    viewModelOf(container).deleteSelected();

    // A parede não fica furada — 3 vira 2, 4 vira 3, e ela encolhe.
    expect(stateOf(container).notes, hasLength(3));
    expect(stateOf(container).noteAt(1)?.content, 'anotação 1');
    expect(stateOf(container).noteAt(2)?.content, 'anotação 3');
    expect(stateOf(container).noteAt(3)?.content, 'anotação 4');
    expect(stateOf(container).noteAt(4), isNull);

    // E o banco enxerga o mesmo, não só a tela.
    expect(repository.loadAll().map((note) => note.slot), [1, 2, 3]);
  });

  test('a parede não encolhe: o teclado é que anda menos', () {
    final container = containerFor();
    fill(container, 4);

    // A parede é sempre a parede: nove vagas, três linhas, com dois cartões ou
    // com nove. O número de uma vaga é o endereço dela, e endereço não muda.
    expect(stateOf(container).rows, 3);
    // O teclado anda até a primeira livre — a quinta, com quatro coladas.
    expect(stateOf(container).lastSelectableSlot, 5);

    viewModelOf(container).selectSlot(4);
    viewModelOf(container).deleteSelected();

    expect(stateOf(container).rows, 3);
    expect(stateOf(container).lastSelectableSlot, 4);
  });

  test('a seleção fica na vaga, que agora é de quem subiu', () {
    final container = containerFor();
    fill(container, 3);

    viewModelOf(container).selectSlot(2);
    viewModelOf(container).deleteSelected();

    expect(stateOf(container).selectedSlot, 2);
    expect(stateOf(container).selectedNote?.content, 'anotação 3');
  });

  test('apagar a última recua a seleção para o fim da parede', () {
    final container = containerFor();
    fill(container, 3);

    viewModelOf(container).selectSlot(3);
    viewModelOf(container).deleteSelected();

    // A vaga 3 virou a livre: continua existindo, agora como convite.
    expect(stateOf(container).selectedSlot, 3);
    expect(stateOf(container).firstFreeSlot, 3);
  });

  test('a seleção anda pela grade em duas dimensões e para nas bordas', () {
    final container = containerFor();
    fill(container, 5);

    viewModelOf(container).selectSlot(1);

    viewModelOf(container).moveSelection(columns: 1);
    expect(stateOf(container).selectedSlot, 2);

    viewModelOf(container).moveSelection(rows: 1);
    expect(stateOf(container).selectedSlot, 5);

    // Terceira coluna da segunda linha é a vaga livre (6), que existe.
    viewModelOf(container).moveSelection(columns: 1);
    expect(stateOf(container).selectedSlot, 6);

    // Não há terceira linha desenhada: descer não faz nada.
    viewModelOf(container).moveSelection(rows: 1);
    expect(stateOf(container).selectedSlot, 6);

    viewModelOf(container).moveSelection(columns: 1);
    expect(stateOf(container).selectedSlot, 6);
  });

  test('a grade desenha as nove vagas, cheia ou vazia', () {
    final container = containerFor();

    expect(stateOf(container).rows, 3);
    expect(stateOf(container).lastVisibleSlot, 9);

    fill(container, 6);

    expect(stateOf(container).rows, 3);
    expect(stateOf(container).lastVisibleSlot, 9);
  });

  testWidgets('copiar leva o texto para a área de transferência', (
    tester,
  ) async {
    final container = containerFor();
    fill(container, 2);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );

    expect(await viewModelOf(container).copySlot(2), isTrue);
    expect(copied, 'anotação 2');

    // Vaga vazia não copia nada — é o que impede o painel de fechar à toa.
    expect(await viewModelOf(container).copySlot(7), isFalse);
  });

  group('a data que o cartão mostra', () {
    /// Um container com relógio que anda — o do resto do arquivo é fixo, e uma
    /// data de edição precisa de duas horas diferentes para dizer alguma coisa.
    (ProviderContainer, void Function(DateTime)) movable() {
      var now = clock;

      final container = ProviderContainer(
        overrides: [
          leafRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      return (container, (moment) => now = moment);
    }

    test('editar o cartão passa a data para a hora da edição', () {
      final (container, travelTo) = movable();
      final viewModel = viewModelOf(container);

      viewModel
        ..startNote()
        ..commitEdit('cobrar o jurídico');
      expect(stateOf(container).noteAt(1)!.changedAt, clock);

      final later = clock.add(const Duration(days: 21));
      travelTo(later);
      viewModel
        ..editSlot(1)
        ..commitEdit('cobrar o jurídico até sexta');

      final note = stateOf(container).noteAt(1)!;
      // A criação continua onde estava: é ela que explica a vaga na parede.
      expect(note.createdAt, clock);
      expect(note.updatedAt, later);
      // E é esta que o cartão mostra — antes ele dizia "há 3 semanas" sobre um
      // recado escrito agora.
      expect(note.changedAt, later);
      expect(repository.loadAll().single.updatedAt, later);
    });

    test('sair do campo sem mudar nada não envelhece o cartão', () {
      final (container, travelTo) = movable();
      final viewModel = viewModelOf(container);

      viewModel
        ..startNote()
        ..commitEdit('ligar pro contador');

      travelTo(clock.add(const Duration(days: 21)));
      // O campo confirma sozinho ao perder o foco: abrir o cartão e sair sem
      // escrever nada acontece o tempo todo, e não é uma edição.
      viewModel
        ..editSlot(1)
        ..commitEdit('ligar pro contador');

      expect(stateOf(container).noteAt(1)!.updatedAt, isNull);
      expect(stateOf(container).noteAt(1)!.changedAt, clock);
    });
  });

  group('desfazer o apagar', () {
    test('devolve o cartão à vaga em que ele estava', () {
      final container = containerFor();
      fill(container, 3);

      viewModelOf(container)
        ..selectSlot(2)
        ..deleteSelected();
      expect(stateOf(container).notes.map((note) => note.content), [
        'anotação 1',
        'anotação 3',
      ]);
      expect(stateOf(container).canUndoDelete, isTrue);

      viewModelOf(container).undoDelete();

      expect(stateOf(container).notes.map((note) => note.content), [
        'anotação 1',
        'anotação 2',
        'anotação 3',
      ]);
      // No banco também, e com as vagas contíguas.
      expect(repository.loadAll().map((note) => note.slot), [1, 2, 3]);
      expect(repository.loadAll().map((note) => note.content), [
        'anotação 1',
        'anotação 2',
        'anotação 3',
      ]);
      // A seleção vai para o cartão que voltou: é onde o olho está.
      expect(stateOf(container).selectedSlot, 2);
      // Uma vez só — o Leaf não tem pilha de desfazer.
      expect(stateOf(container).canUndoDelete, isFalse);
    });

    test('esvaziar o campo apaga, e é disto que o desfazer é a rede', () {
      final container = containerFor();
      fill(container, 1);

      // Um cartão vazio na parede não diz nada a ninguém, então esvaziá-lo é a
      // forma de jogá-lo fora — e a mais fácil de fazer sem querer.
      viewModelOf(container)
        ..editSlot(1)
        ..commitEdit('   ');
      expect(stateOf(container).notes, isEmpty);
      expect(stateOf(container).canUndoDelete, isTrue);

      viewModelOf(container).undoDelete();

      expect(stateOf(container).noteAt(1)?.content, 'anotação 1');
    });

    test('o cartão devolvido volta com as datas que tinha', () {
      final container = containerFor();
      fill(container, 1);
      final before = stateOf(container).noteAt(1)!;

      viewModelOf(container)
        ..selectSlot(1)
        ..deleteSelected()
        ..undoDelete();

      final after = stateOf(container).noteAt(1)!;
      // Devolver não é escrever de novo: apresentá-lo como "agora" apagaria a
      // única pista de quando aquele recado foi escrito.
      expect(after.createdAt, before.createdAt);
      expect(after.changedAt, before.changedAt);
    });

    test('escrever outra anotação não cancela a oferta', () {
      final container = containerFor();
      fill(container, 3);

      viewModelOf(container)
        ..selectSlot(2)
        ..deleteSelected()
        ..startNote();
      viewModelOf(container).commitEdit('a que veio depois');

      viewModelOf(container).undoDelete();

      // O cartão volta para a vaga dele e empurra o resto para baixo.
      expect(stateOf(container).notes.map((note) => note.content), [
        'anotação 1',
        'anotação 2',
        'anotação 3',
        'a que veio depois',
      ]);
    });

    test('a parede que encheu retira a oferta em vez de prometê-la', () {
      final container = containerFor();
      fill(container, LeafNote.maxNotes);

      viewModelOf(container)
        ..selectSlot(3)
        ..deleteSelected();
      expect(stateOf(container).canUndoDelete, isTrue);

      viewModelOf(container).startNote();
      viewModelOf(container).commitEdit('a nona de novo');

      // Não há vaga para devolver o cartão, e a dica some do rodapé junto.
      expect(stateOf(container).isFull, isTrue);
      expect(stateOf(container).canUndoDelete, isFalse);
    });

    test('fechar e reabrir o painel não encerra a oferta', () async {
      final container = containerFor();
      fill(container, 2);

      viewModelOf(container)
        ..selectSlot(1)
        ..deleteSelected();
      expect(stateOf(container).canUndoDelete, isTrue);

      await viewModelOf(container).prepareForOpen();

      // Fechar o Leaf é o gesto seguinte mais provável depois de apagar por
      // engano — o painel some sozinho ao perder o foco. Se a oferta morresse
      // aí, o `⌘Z` quase nunca daria tempo de ser cobrado.
      expect(stateOf(container).canUndoDelete, isTrue);

      viewModelOf(container).undoDelete();
      expect(stateOf(container).notes, hasLength(2));
    });

    test('apagar dois seguidos devolve os dois, do último para o primeiro', () {
      final container = containerFor();
      fill(container, 3);

      final first = stateOf(container).noteAt(1)!.content;
      final second = stateOf(container).noteAt(2)!.content;

      // Apaga a vaga 1; quem estava na 2 sobe para ela, e apagar a 1 de novo
      // arranca o segundo cartão.
      viewModelOf(container)
        ..selectSlot(1)
        ..deleteSelected()
        ..selectSlot(1)
        ..deleteSelected();
      expect(stateOf(container).notes, hasLength(1));

      // O último a sair é o primeiro a voltar.
      viewModelOf(container).undoDelete();
      expect(
        stateOf(container).notes.map((note) => note.content),
        contains(second),
      );

      // E o de antes dele continua ao alcance: era isto que se perdia quando a
      // oferta guardava um cartão só.
      expect(stateOf(container).canUndoDelete, isTrue);
      viewModelOf(container).undoDelete();
      expect(
        stateOf(container).notes.map((note) => note.content),
        containsAll(<String>[first, second]),
      );
      expect(stateOf(container).canUndoDelete, isFalse);
    });
  });

  test('reabrir o painel relê a parede e larga a edição pendente', () async {
    final container = containerFor();
    fill(container, 1);

    viewModelOf(container).editSlot(1);
    expect(stateOf(container).isEditing, isTrue);

    // O Hub roda em outro engine: esvaziar por lá não passa por esta ViewModel.
    repository.clearAll();
    await viewModelOf(container).prepareForOpen();

    expect(stateOf(container).isEditing, isFalse);
    expect(stateOf(container).notes, isEmpty);
  });

  group('lembrete', () {
    test('o sino vira o seletor, e marcar agenda no sistema', () {
      final container = containerFor();
      fill(container, 2);
      final note = stateOf(container).noteAt(2)!;

      viewModelOf(container).remindSlot(2);
      expect(stateOf(container).remindingSlot, 2);

      final at = clock.add(const Duration(hours: 1));
      viewModelOf(container).setReminder(at);

      expect(stateOf(container).isReminding, isFalse);
      expect(stateOf(container).noteAt(2)?.remindAt, at);
      expect(repository.loadAll()[1].remindAt, at);

      final (notification, scheduledAt) =
          notifications.scheduled['leaf.${note.id}']!;
      expect(scheduledAt, at);
      expect(notification.body, 'anotação 2');
    });

    test('o campo só marca o que entendeu', () {
      final container = containerFor();
      fill(container, 1);

      viewModelOf(container).remindSlot(1);
      viewModelOf(container).setReminderFromText('quando der');
      expect(stateOf(container).isReminding, isTrue);
      expect(notifications.scheduled, isEmpty);

      viewModelOf(container).setReminderFromText('em 45 min');
      expect(
        stateOf(container).noteAt(1)?.remindAt,
        clock.add(const Duration(minutes: 45)),
      );
    });

    test('remover tira do cartão e do sistema', () {
      final container = containerFor();
      fill(container, 1);
      final id = stateOf(container).noteAt(1)!.id;

      viewModelOf(container)
        ..remindSlot(1)
        ..setReminder(clock.add(const Duration(hours: 3)))
        ..remindSlot(1)
        ..removeReminder();

      expect(stateOf(container).noteAt(1)?.remindAt, isNull);
      expect(notifications.cancelled, ['leaf.$id']);
    });

    test('reescrever o cartão reagenda com o texto novo', () {
      final container = containerFor();
      fill(container, 1);
      final id = stateOf(container).noteAt(1)!.id;

      viewModelOf(container)
        ..remindSlot(1)
        ..setReminder(clock.add(const Duration(hours: 1)))
        ..editSlot(1)
        ..commitEdit('ligar pro Marcos\nantes das 15h');

      final (notification, _) = notifications.scheduled['leaf.$id']!;
      expect(notification.title, 'ligar pro Marcos');
      expect(notification.body, 'antes das 15h');
    });

    test('apagar cancela; desfazer devolve o lembrete', () {
      final container = containerFor();
      fill(container, 1);
      final at = clock.add(const Duration(hours: 1));

      viewModelOf(container)
        ..remindSlot(1)
        ..setReminder(at)
        ..deleteSelected();
      expect(notifications.scheduled, isEmpty);

      viewModelOf(container).undoDelete();

      final restored = stateOf(container).noteAt(1)!;
      expect(restored.remindAt, at);
      expect(notifications.scheduled['leaf.${restored.id}']?.$2, at);
    });

    test('adiar empurra 30 min a partir de agora', () {
      final container = containerFor();
      fill(container, 1);
      final id = stateOf(container).noteAt(1)!.id;

      viewModelOf(container).snooze(id);

      expect(
        notifications.scheduled['leaf.$id']?.$2,
        clock.add(const Duration(minutes: 30)),
      );
    });

    test('lembrete que já tocou sai do cartão na releitura', () async {
      repository = FakeLeafRepository([
        LeafNote(
          id: 1,
          slot: 1,
          content: 'já foi',
          createdAt: clock,
          remindAt: clock.subtract(const Duration(minutes: 5)),
        ),
      ]);
      final container = containerFor();

      expect(stateOf(container).noteAt(1)?.remindAt, isNull);
      expect(repository.loadAll().single.remindAt, isNull);
    });

    test('desligar e religar o módulo tira e devolve os agendamentos', () {
      final container = containerFor();
      fill(container, 1);
      final id = stateOf(container).noteAt(1)!.id;
      final at = clock.add(const Duration(hours: 2));
      viewModelOf(container)
        ..remindSlot(1)
        ..setReminder(at)
        ..unscheduleReminders();

      expect(notifications.scheduled, isEmpty);
      expect(stateOf(container).noteAt(1)?.remindAt, at);

      viewModelOf(container).scheduleReminders();
      expect(notifications.scheduled['leaf.$id']?.$2, at);
    });
  });
}

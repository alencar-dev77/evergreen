import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/leaf/models/leaf_note.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_state.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_leaf_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLeafRepository repository;

  final clock = DateTime(2026, 8, 4, 10);

  setUp(() => repository = FakeLeafRepository());

  ProviderContainer containerFor() {
    final container = ProviderContainer(
      overrides: [
        leafRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => clock),
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
    expect(
      repository.loadAll().map((note) => note.slot),
      [1, 2, 3],
    );
  });

  test('a parede encolhe de linha quando a última esvazia', () {
    final container = containerFor();
    fill(container, 4);

    // 4 anotações + a vaga que convida = 5 vagas visíveis, duas linhas.
    expect(stateOf(container).rows, 2);

    viewModelOf(container).selectSlot(4);
    viewModelOf(container).deleteSelected();

    // 3 anotações + a vaga livre = 4 vagas... ainda duas linhas.
    expect(stateOf(container).rows, 2);

    viewModelOf(container).selectSlot(3);
    viewModelOf(container).deleteSelected();

    // 2 anotações + a vaga livre cabem numa linha só.
    expect(stateOf(container).rows, 1);
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

  test('a grade só desenha as linhas que tem o que mostrar', () {
    final container = containerFor();

    // Parede vazia: uma linha, só com a vaga que convida.
    expect(stateOf(container).rows, 1);

    fill(container, 3);
    expect(stateOf(container).rows, 2);

    fill(container, 6);
    expect(stateOf(container).rows, 3);
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
      expect(
        stateOf(container).notes.map((note) => note.content),
        ['anotação 1', 'anotação 3'],
      );
      expect(stateOf(container).canUndoDelete, isTrue);

      viewModelOf(container).undoDelete();

      expect(
        stateOf(container).notes.map((note) => note.content),
        ['anotação 1', 'anotação 2', 'anotação 3'],
      );
      // No banco também, e com as vagas contíguas.
      expect(repository.loadAll().map((note) => note.slot), [1, 2, 3]);
      expect(
        repository.loadAll().map((note) => note.content),
        ['anotação 1', 'anotação 2', 'anotação 3'],
      );
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
      expect(
        stateOf(container).notes.map((note) => note.content),
        ['anotação 1', 'anotação 2', 'anotação 3', 'a que veio depois'],
      );
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

    test('fechar o painel encerra a oferta', () async {
      final container = containerFor();
      fill(container, 2);

      viewModelOf(container)
        ..selectSlot(1)
        ..deleteSelected();
      expect(stateOf(container).canUndoDelete, isTrue);

      await viewModelOf(container).prepareForOpen();

      // O desfazer é para o engano de um segundo atrás, não para o de ontem.
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
}

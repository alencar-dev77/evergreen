import 'package:evergreen/features/echo/models/echo_spectrum.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_state.dart';
import 'package:evergreen/features/focus/models/focus_phase.dart';
import 'package:evergreen/features/focus/models/focus_settings.dart';
import 'package:evergreen/features/focus/presentation/viewmodels/focus_timer_state.dart';
import 'package:evergreen/features/nest/models/nest_item.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_state.dart';
import 'package:evergreen/features/notch/models/notch_activity.dart';
import 'package:evergreen/features/notch/models/notch_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const settings = FocusSettings();

  const recording = EchoRecorderState(
    phase: EchoPhase.recording,
    elapsed: Duration(minutes: 12, seconds: 34),
    spectrum: EchoSpectrum(mic: [0.123, 0.5], system: [0.987]),
  );

  const focusing = FocusTimerState(
    settings: settings,
    status: FocusStatus.running,
    remaining: Duration(minutes: 24, seconds: 13),
    total: Duration(minutes: 25),
    activity: '  Relatório  ',
  );

  group('Echo', () {
    test('só aparece gravando', () {
      expect(NotchActivity.echo(const EchoRecorderState()), isNull);
      expect(
        NotchActivity.echo(
          const EchoRecorderState(phase: EchoPhase.transcribing),
        ),
        isNull,
      );
    });

    test('gravando: o relógio da barra, o som e pausar ou parar', () {
      final activity = NotchActivity.echo(recording)!;

      expect(activity.module, NotchModule.echo);
      expect(activity.isRecording, isTrue);
      expect(activity.title, 'Gravando');
      expect(activity.clock, '12:34');
      expect(activity.mic, [0.12, 0.5]);
      expect(activity.system, [0.99]);
      expect(activity.actions.map((action) => action.id), [
        NotchAction.pause,
        NotchAction.stop,
      ]);
    });

    test('sem texto ao vivo, a ilha não oferece transcrição', () {
      expect(NotchActivity.echo(recording)!.transcript, isNull);
      expect(NotchActivity.echo(recording)!.toMap()['transcript'], isNull);
    });

    test('com texto ao vivo, vão só os trechos mais novos', () {
      final activity = NotchActivity.echo(
        recording.copyWith(
          isTranscribingLive: true,
          liveText: ['um', 'dois', 'três', 'quatro', 'cinco', 'seis'],
        ),
      )!;

      expect(activity.transcript, ['três', 'quatro', 'cinco', 'seis']);
      expect(activity.toMap()['transcriptLabels'], {
        'show': 'Transcrição',
        'hide': 'Recolher',
        'empty': 'Ouvindo…',
      });
    });

    test('ao vivo e ainda sem frase: a lista vazia, não nula', () {
      final activity = NotchActivity.echo(
        recording.copyWith(isTranscribingLive: true),
      )!;

      expect(activity.transcript, isEmpty);
    });

    test('pausada: o som some e o botão vira retomar', () {
      final activity = NotchActivity.echo(recording.copyWith(isPaused: true))!;

      expect(activity.title, 'Pausado');
      expect(activity.isPaused, isTrue);
      expect(activity.mic, isEmpty);
      expect(activity.actions.first.id, NotchAction.resume);
    });
  });

  group('Focus', () {
    test('só aparece com a sessão de pé', () {
      expect(NotchActivity.focus(FocusTimerState.idle(settings)), isNull);
      expect(
        NotchActivity.focus(focusing.copyWith(status: FocusStatus.finished)),
        isNull,
      );
    });

    test('contando: a fase, a atividade e o que falta', () {
      final activity = NotchActivity.focus(focusing)!;

      expect(activity.module, NotchModule.focus);
      expect(activity.isRecording, isFalse);
      expect(activity.title, 'Foco');
      expect(activity.detail, 'Relatório');
      expect(activity.clock, '24:13');
      expect(activity.progress, closeTo(47 / 1500, 1 / 200));
      expect(activity.actions.last.label, 'Encerrar');
    });

    test('a pausa do ciclo não é o foco', () {
      final activity = NotchActivity.focus(
        focusing.copyWith(phase: FocusPhase.rest),
      )!;

      expect(activity.title, 'Pausa');
      expect(activity.isRest, isTrue);
    });

    test('suspensa: pausado, e o botão vira retomar', () {
      final activity = NotchActivity.focus(
        focusing.copyWith(status: FocusStatus.paused),
      )!;

      expect(activity.title, 'Pausado');
      expect(activity.actions.first.id, NotchAction.resume);
    });
  });

  group('Nest', () {
    NestItem item(String name) => NestItem(
      path: '/tmp/$name',
      isDirectory: false,
      sizeInBytes: 10,
      modifiedAt: DateTime(2026, 10, 15),
    );

    final pile = NestState(items: [item('a.pdf'), item('b.png')]);

    test('vazia, não há o que esperar no notch', () {
      expect(NotchActivity.nest(const NestState(), onScreen: false), isNull);
    });

    test('com o painel à vista, a ilha não repete o que está embaixo', () {
      expect(NotchActivity.nest(pile, onScreen: true), isNull);
    });

    test('a bandeja e a contagem; o mouse em cima pede o painel', () {
      final activity = NotchActivity.nest(pile, onScreen: false)!;
      final map = activity.toMap();

      expect(activity.module, NotchModule.nest);
      expect(activity.clock, '2');
      expect(activity.detail, '2 arquivos');
      expect(map['indicator'], 'shelf');
      expect(map['opensOnHover'], isTrue);
      expect(map['actions'], isEmpty);
    });

    test('a reunião, depois a pilha, depois o foco', () {
      final running = NotchActivity.running(
        echo: recording,
        focus: focusing,
        nest: pile,
      );

      expect(running.map((activity) => activity.module), [
        NotchModule.echo,
        NotchModule.nest,
        NotchModule.focus,
      ]);
    });
  });

  test('a reunião vem antes do foco', () {
    final running = NotchActivity.running(echo: recording, focus: focusing);

    expect(running.map((activity) => activity.module), [
      NotchModule.echo,
      NotchModule.focus,
    ]);
  });

  test('nada rodando, lista vazia', () {
    expect(
      NotchActivity.running(
        echo: const EchoRecorderState(),
        focus: FocusTimerState.idle(settings),
      ),
      isEmpty,
    );
  });

  test('igualdade por valor, para só mandar ao canal o que mudou', () {
    expect(NotchActivity.focus(focusing), NotchActivity.focus(focusing));
    expect(
      NotchActivity.focus(focusing),
      isNot(
        NotchActivity.focus(
          focusing.copyWith(remaining: const Duration(minutes: 24)),
        ),
      ),
    );
  });

  test('o mapa que vai para o lado nativo', () {
    final map = NotchActivity.echo(recording)!.toMap();

    expect(map['module'], 'echo');
    expect(map['indicator'], 'recording');
    expect(map['clock'], '12:34');
    expect(map['actions'], [
      {'id': 'pause', 'label': 'Pausar'},
      {'id': 'stop', 'label': 'Parar'},
    ]);
  });
}

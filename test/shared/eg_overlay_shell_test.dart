import 'package:evergreen/shared/widgets/eg_overlay_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// As duas exceções que o Echo pediu à casca compartilhada: arrastar o painel
/// pelo fundo e não fechar quando o foco vai para a reunião.
void main() {
  late List<String> calls;

  const channel = MethodChannel('window_manager');

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      // A pergunta que o fechamento por blur faz antes de fechar: "o foco
      // voltou?". Não voltou — é o caminho que interessa testar.
      if (call.method == 'isFocused') return false;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Entrega à casca o mesmo evento que o lado nativo entregaria.
  Future<void> sendBlur(WidgetTester tester) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onEvent', {'eventName': 'blur'}),
      ),
      null,
    );
    // A casca espera a margem de tolerância antes de confirmar o blur.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }

  Future<int> pumpShell(
    WidgetTester tester, {
    required bool dismissOnBlur,
    bool draggable = false,
  }) async {
    var closed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: EgOverlayShell(
          onClose: () => closed++,
          dismissOnBlur: dismissOnBlur,
          draggable: draggable,
          child: const _Painel(),
        ),
      ),
    );
    await tester.pump();

    return closed;
  }

  group('fechar por foco perdido', () {
    testWidgets('o padrão continua sendo fechar', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(
            onClose: () => closed++,
            child: const _Painel(),
          ),
        ),
      );
      await tester.pump();

      await sendBlur(tester);

      expect(closed, 1);
    });

    testWidgets('com dismissOnBlur desligado, o painel fica', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(
            onClose: () => closed++,
            dismissOnBlur: false,
            child: const _Painel(),
          ),
        ),
      );
      await tester.pump();

      await sendBlur(tester);

      expect(closed, 0);
      // E nem chega a perguntar ao sistema se o foco voltou: sai antes.
      expect(calls, isNot(contains('isFocused')));
    });
  });

  group('arrastar', () {
    testWidgets('painel arrastável entrega o gesto ao macOS', (tester) async {
      await pumpShell(tester, dismissOnBlur: true, draggable: true);

      await tester.drag(find.byKey(const Key('painel')), const Offset(80, 40));
      await tester.pump();

      expect(calls, contains('startDragging'));
    });

    testWidgets('sem draggable, arrastar não move a janela', (tester) async {
      await pumpShell(tester, dismissOnBlur: true);

      await tester.drag(find.byKey(const Key('painel')), const Offset(80, 40));
      await tester.pump();

      expect(calls, isNot(contains('startDragging')));
    });

    testWidgets('arrastar não fecha o painel', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(
            onClose: () => closed++,
            draggable: true,
            child: const _Painel(),
          ),
        ),
      );
      await tester.pump();

      // O fundo do painel também é o que intercepta o clique-fora; puxar dali
      // não pode ser confundido com um toque na barreira.
      await tester.drag(find.byKey(const Key('painel')), const Offset(80, 40));
      await tester.pump();

      expect(closed, 0);
    });
  });
}

/// Um painel que pinta de verdade: o `drag` do teste precisa acertá-lo no hit
/// test, senão o gesto chega pela barreira e o teste passa pelo motivo errado.
class _Painel extends StatelessWidget {
  const _Painel();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('painel'),
        width: 200,
        height: 120,
        color: const Color(0xFF141414),
      );
}

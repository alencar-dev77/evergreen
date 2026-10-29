import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/shared/widgets/eg_overlay_shell.dart';
import 'package:flutter/gestures.dart';
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
    bool draggable = true,
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

  group('o teclado não escapa do painel', () {
    /// O que quebrava: um painel podia aparecer sem que nada pedisse o teclado
    /// — trocar de painel com a janela já na tela não dispara `didBecomeKey`,
    /// então não há `onWindowFocus` nem `onShow`. Sem nó focado, nenhum
    /// `Shortcuts` é consultado: o painel fica na tela e cada tecla vira o bipe
    /// do macOS.
    testWidgets(
      'o painel que nasce sem ninguém pedir foco ainda ouve o teclado',
      (tester) async {
        final teclas = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.arrowDown):
                      ActivateIntent(),
                },
                child: Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) => teclas.add('↓'),
                    ),
                  },
                  // Nenhum campo, nenhum autofocus, nenhum `onShow`: exatamente o
                  // painel trocado com a janela já visível.
                  child: EgOverlayShell(onClose: () {}, child: const _Painel()),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

        expect(teclas, ['↓']);
      },
    );

    testWidgets('o nó do módulo tem preferência sobre o da casca', (
      tester,
    ) async {
      final doModulo = FocusNode(debugLabel: 'do-modulo');
      addTearDown(doModulo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(
            onClose: () {},
            focusNode: doModulo,
            child: const _Painel(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Quem sabe onde o teclado deve ficar é o painel, quando ele tem opinião.
      expect(doModulo.hasFocus, isTrue);
    });

    testWidgets('o campo do módulo não é atropelado pela casca', (
      tester,
    ) async {
      final doCampo = FocusNode(debugLabel: 'campo-do-modulo');
      addTearDown(doCampo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: EgOverlayShell(
              onClose: () {},
              child: TextField(focusNode: doCampo, autofocus: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // A rede é rede, não dono: com um campo focado no painel, o teclado é
      // dele — senão o Pin abriria sem cursor na busca.
      expect(doCampo.hasFocus, isTrue);
    });
  });

  group('fechar por foco perdido', () {
    testWidgets('o padrão continua sendo fechar', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(onClose: () => closed++, child: const _Painel()),
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

    /// O que a #162 pedia: os painéis que não diziam nada nasciam presos no
    /// centro da tela, e só o Echo e o Nest saíam do lugar.
    testWidgets('o painel que não diz nada se arrasta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(onClose: () {}, child: const _Painel()),
        ),
      );
      await tester.pump();

      await tester.drag(find.byKey(const Key('painel')), const Offset(80, 40));
      await tester.pump();

      expect(calls, contains('startDragging'));
    });

    /// O clique tolera 18 px de mão tremendo, e o arrasto de fábrica começava
    /// com 2: no meio, a linha do Pin perdia o clique e a janela andava.
    testWidgets('o clique que treme continua sendo clique', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EgOverlayShell(
            onClose: () {},
            child: GestureDetector(onTap: () => taps++, child: const _Painel()),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('painel'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(6, 4));
      await gesture.up();
      await tester.pump();

      expect(taps, 1);
      expect(calls, isNot(contains('startDragging')));
    });

    testWidgets('sem draggable, arrastar não move a janela', (tester) async {
      await pumpShell(tester, dismissOnBlur: true, draggable: false);

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

  group('saindo do notch', () {
    tearDown(OverlayWindow.instance.resetForTest);

    Future<void> pumpAtNotch(WidgetTester tester) async {
      OverlayWindow.instance.notchAnchor.value = const Size(220, 38);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: EgOverlayShell(onClose: () {}, child: const _Painel()),
        ),
      );
    }

    testWidgets('o painel encosta logo abaixo do recorte, centrado nele', (
      tester,
    ) async {
      await pumpAtNotch(tester);
      await tester.pumpAndSettle();

      final panel = tester.getRect(find.byKey(const Key('painel')));
      final screen = tester.getRect(find.byType(EgOverlayShell));

      expect(panel.top, 38 + 8);
      expect(panel.center.dx, screen.center.dx);
    });

    testWidgets('entra crescendo do recorte, e termina sem pílula nenhuma', (
      tester,
    ) async {
      await pumpAtNotch(tester);

      // No meio da entrada a pílula está desenhada por cima do painel.
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.descendant(
          of: find.byType(EgOverlayShell),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byKey(const Key('painel')),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('sem o notch, o painel volta ao centro', (tester) async {
      await pumpAtNotch(tester);
      await tester.pumpAndSettle();

      OverlayWindow.instance.notchAnchor.value = null;
      await tester.pump();

      final panel = tester.getRect(find.byKey(const Key('painel')));
      final screen = tester.getRect(find.byType(EgOverlayShell));
      expect(panel.center, screen.center);
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

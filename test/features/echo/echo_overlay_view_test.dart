import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_recorder_view_model.dart';
import 'package:evergreen/features/echo/presentation/views/echo_overlay_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';

void main() {
  late SharedPreferences preferences;
  late Database db;

  setUp(() async {
    OverlayWindow.instance.resetForTest();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const EchoOverlayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// `OverlayWindow.hide` começa avisando o lado nativo (`beginHide`), então é
  /// essa chamada que diz "o painel está indo embora" sem precisar de janela de
  /// verdade no ambiente de teste.
  List<String> watchClosing() {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('previous_app_focus');

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    return calls;
  }


  /// Entrega à casca um evento de janela como o lado nativo entregaria.
  ///
  /// É por aqui que o painel descobre que ganhou o foco (e recarrega as
  /// permissões, em `onShow`) e que o perdeu.
  Future<void> sendWindowEvent(WidgetTester tester, String event) async {
    const channel = MethodChannel('window_manager');

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onEvent', {'eventName': event}),
      ),
      null,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Esc fecha o painel', (tester) async {
    final closing = watchClosing();
    await pumpPanel(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closing, contains('beginHide'));
  });

  /// O Echo não tem campo de texto — quem segura o teclado é o próprio painel
  /// —, então o clique não tem como levar o foco embora. O teste prende isso
  /// com um teste, e não com herança de casca, como nos outros quatro painéis.
  testWidgets('clicar no painel não emudece o Esc', (tester) async {
    final closing = watchClosing();
    await pumpPanel(tester);

    await tester.tapAt(tester.getCenter(find.text('Antes de gravar')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closing, contains('beginHide'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  /// O painel do Echo é o único que fica na frente de uma reunião em curso, e
  /// por isso é o único que não some quando a pessoa clica de volta nela.
  group('gravando, o painel não fecha sozinho', () {
    /// Responde à pergunta que o fechamento por blur faz antes de fechar
    /// ("o foco voltou?") com um "não" — o caminho que de fato fecharia.
    void answerWindowManager() {
      const channel = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isFocused') return false;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    testWidgets('gravando, perder o foco não fecha', (tester) async {
      answerWindowManager();
      final closing = watchClosing();
      await pumpPanel(tester);

      // Quem relê as permissões antes de o painel aparecer é o `OverlayHost`,
      // não a própria tela — sem esta chamada o painel fica em "Antes de
      // gravar" e o Enter não tem o que fazer.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EchoOverlayView)),
      );
      await container
          .read(echoRecorderViewModelProvider.notifier)
          .prepareForOpen();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Sem isto o teste passaria por não ter saído do lugar.
      expect(
        container.read(echoRecorderViewModelProvider).isRecording,
        isTrue,
        reason: 'o Enter precisa ter começado a gravação',
      );

      // Começar a gravar fecha o painel de propósito — quem apertou o atalho
      // antes da reunião quer voltar para a reunião. O que se testa é o blur
      // *depois* disso, com a gravação correndo.
      closing.clear();

      await sendWindowEvent(tester, 'blur');
      await tester.pump(const Duration(milliseconds: 200));

      expect(closing, isEmpty);
    });

    testWidgets('parado, perder o foco fecha como antes', (tester) async {
      answerWindowManager();
      final closing = watchClosing();
      await pumpPanel(tester);

      await sendWindowEvent(tester, 'focus');
      closing.clear();

      await sendWindowEvent(tester, 'blur');
      await tester.pump(const Duration(milliseconds: 200));

      expect(closing, contains('beginHide'));
    });
  });
}

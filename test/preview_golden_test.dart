@Tags(['preview'])
library;

import 'dart:io';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_colors.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:evergreen/features/focus/models/focus_session_note.dart';
import 'package:evergreen/features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import 'package:evergreen/features/focus/presentation/views/focus_overlay_view.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import 'package:evergreen/features/pin/presentation/views/pin_overlay_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/focus/fake_focus_session_repository.dart';
import 'features/pin/fake_clipboard_repository.dart';

/// Goldens usados como conferência visual do design durante o desenvolvimento.
///
/// Rode com `flutter test --update-goldens --tags preview` para regerar as
/// imagens em `test/goldens/`. Não fazem parte da suíte padrão: são um apoio de
/// revisão, não uma trava de regressão.
void main() {
  setUpAll(_loadFonts);

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  final base = DateTime(2026, 7, 23, 12);

  ClipboardItem item(int id, String content, {bool isPinned = false}) =>
      ClipboardItem.capture(content, at: base.subtract(Duration(minutes: id)))
          .copyWith(id: id, isPinned: isPinned);

  final repository = FakeClipboardRepository([
    item(1, 'Flutter', isPinned: true),
    item(2, 'git pull origin develop', isPinned: true),
    item(4, 'https://pub.dev/packages/sqlite3'),
    item(6, 'Senha temporária: xK9#mPz2'),
    item(9, 'flutter pub get'),
    item(14, 'https://github.com/evergreen/pin'),
    item(30, 'const AppColors.greenPrimary = Color(0xFF22C55E);'),
  ]);

  // Ancoradas no dia de hoje, e não em `base`: o histórico rotula as datas
  // como "Hoje"/"Ontem", que é como a tela realmente se apresenta a quem usa.
  final anchor = DateTime.now();

  final sessions = FakeFocusSessionRepository([
    FocusSession(
      id: 1,
      startedAt: DateTime(anchor.year, anchor.month, anchor.day, 9, 12),
      duration: const Duration(minutes: 25),
      activity: 'Refatorar o módulo de auth',
      summary: 'Terminei a migração do repositório',
      notes: const [
        FocusSessionNote(minute: 12, text: 'terminei a task e comecei outra'),
      ],
    ),
    FocusSession(
      id: 2,
      startedAt: DateTime(anchor.year, anchor.month, anchor.day, 10, 5),
      duration: const Duration(minutes: 25),
      activity: 'Revisar a PR do design system',
    ),
    FocusSession(
      id: 3,
      startedAt: DateTime(anchor.year, anchor.month, anchor.day, 14, 40),
      duration: const Duration(minutes: 45),
    ),
  ]);

  /// [beforeSettle] roda entre a montagem e o `pumpAndSettle` — é onde o
  /// histórico entra. Antes disso o overlay mostra o indicador de carregamento,
  /// que é indeterminado e nunca deixaria o `pumpAndSettle` terminar.
  /// [fakeClock] troca o relógio da aplicação pelo do binding, que anda com
  /// `tester.pump`. Só o painel em sessão precisa disso; nas telas do Hub o
  /// relógio falso jogaria as datas para 2015 e o histórico perderia o "Hoje".
  Future<void> pump(
    WidgetTester tester,
    Widget home,
    Size size, {
    VoidCallback? beforeSettle,
    bool fakeClock = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(repository),
          focusSessionRepositoryProvider.overrideWithValue(sessions),
          sharedPreferencesProvider.overrideWithValue(preferences),
          if (fakeClock)
            clockProvider.overrideWithValue(() => tester.binding.clock.now()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: ColoredBox(color: AppColors.background, child: home),
        ),
      ),
    );

    beforeSettle?.call();
    await tester.pumpAndSettle();
  }

  testWidgets('overlay do Pin — lista', (tester) async {
    await pump(
      tester,
      const PinOverlayView(),
      const Size(1120, 1000),
      beforeSettle: () => _loadHistory(tester),
    );

    await expectLater(
      find.byType(PinOverlayView),
      matchesGoldenFile('goldens/pin_overlay_list.png'),
    );
  });

  testWidgets('overlay do Pin — preview aberto', (tester) async {
    await pump(
      tester,
      const PinOverlayView(),
      const Size(1120, 1000),
      beforeSettle: () => _loadHistory(tester),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinOverlayView),
      matchesGoldenFile('goldens/pin_overlay_preview.png'),
    );
  });

  testWidgets('Hub — configurações do Pin', (tester) async {
    await pump(tester, const HubView(), const Size(1800, 1200));

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_pin_settings.png'),
    );
  });

  testWidgets('painel do Focus — partida', (tester) async {
    await pump(tester, const FocusOverlayView(), const Size(1120, 800));

    await expectLater(
      find.byType(FocusOverlayView),
      matchesGoldenFile('goldens/focus_overlay_idle.png'),
    );
  });

  testWidgets('painel do Focus — sessão em andamento', (tester) async {
    await pump(
      tester,
      const FocusOverlayView(),
      const Size(1120, 800),
      fakeClock: true,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FocusOverlayView)),
    );
    final viewModel = container.read(focusTimerViewModelProvider.notifier);
    viewModel.start(activity: 'Refatorar o módulo de auth');

    await tester.pump(const Duration(minutes: 3, seconds: 20));
    viewModel.addNote('terminei a task e comecei outra');

    await tester.pump(const Duration(minutes: 2, seconds: 27));
    // Tempo para o foco assentar no painel e a borda do campo terminar a
    // transição — senão o campo de anotação congela com a borda de foco que
    // ele não tem no uso real.
    await tester.pump(const Duration(milliseconds: 120));

    await expectLater(
      find.byType(FocusOverlayView),
      matchesGoldenFile('goldens/focus_overlay_running.png'),
    );

    container.read(focusTimerViewModelProvider.notifier).dismiss();
  });

  testWidgets('Hub — detalhe de uma sessão', (tester) async {
    await pump(tester, const HubView(), const Size(1800, 1400));

    await tester.tap(find.text(EvergreenModule.focus.name));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refatorar o módulo de auth'));
    await tester.pumpAndSettle();

    // O diálogo vive na rota de cima, fora da subárvore do Hub — capturar o
    // app inteiro é o que traz o véu e o painel para a imagem.
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hub_focus_session.png'),
    );
  });

  testWidgets('Hub — preferências do aplicativo', (tester) async {
    await pump(tester, const HubView(), const Size(1800, 1200));

    await tester.tap(find.text('Preferências do aplicativo'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_app_settings.png'),
    );
  });

  testWidgets('Hub — Focus', (tester) async {
    await pump(tester, const HubView(), const Size(1800, 1900));

    await tester.tap(find.text(EvergreenModule.focus.name));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubView),
      matchesGoldenFile('goldens/hub_focus.png'),
    );
  });
}

void _loadHistory(WidgetTester tester) {
  final element = tester.element(find.byType(PinOverlayView));
  ProviderScope.containerOf(element)
      .read(pinOverlayViewModelProvider.notifier)
      .load();
}

/// Carrega uma fonte real do sistema para que os goldens mostrem texto de
/// verdade — a fonte padrão dos testes desenha cada glifo como um quadrado.
Future<void> _loadFonts() async {
  const faces = {
    'Inter': [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ],
    // Sem uma mono real, os key-caps mediriam errado e esconderiam problemas de
    // largura na barra de dicas.
    'SF Mono': ['/System/Library/Fonts/Supplemental/Andale Mono.ttf'],
  };

  for (final entry in faces.entries) {
    final loader = FontLoader(entry.key);
    var loaded = false;

    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      loaded = true;
    }

    if (loaded) await loader.load();
  }
}

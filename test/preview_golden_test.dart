@Tags(['preview'])
library;

import 'dart:io';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_colors.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import 'package:evergreen/features/pin/presentation/views/pin_overlay_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// [beforeSettle] roda entre a montagem e o `pumpAndSettle` — é onde o
  /// histórico entra. Antes disso o overlay mostra o indicador de carregamento,
  /// que é indeterminado e nunca deixaria o `pumpAndSettle` terminar.
  Future<void> pump(
    WidgetTester tester,
    Widget home,
    Size size, {
    VoidCallback? beforeSettle,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
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

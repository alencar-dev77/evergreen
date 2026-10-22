import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/local_model/lm_studio_launcher.dart';
import 'package:evergreen/features/home/presentation/viewmodels/local_model_view_model.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/local_model/fake_lm_studio_http.dart';
import '../focus/fake_focus_session_repository.dart';
import '../pin/fake_clipboard_repository.dart';
import '../pin/fake_pin_image_store.dart';
import 'backup_fixture.dart';
import 'fake_diagnostics_service.dart';
import 'fake_disk_usage_service.dart';

/// O `lms` de mentira: "ligar" o servidor é só virar a chave do servidor
/// falso.
class _FakeLauncher implements LmStudioLauncher {
  _FakeLauncher(this.http);

  final FakeLmStudioHttp http;
  bool installed = true;
  int starts = 0;

  @override
  bool get isInstalled => installed;

  @override
  Future<bool> startServer() async {
    starts++;
    http.offline = false;
    return true;
  }
}

/// A linha "Modelo local" na tela do aplicativo, e a bolinha da barra lateral
/// que diz se o modelo está na memória.
void main() {
  late SharedPreferences preferences;
  late FakeLmStudioHttp http;
  late _FakeLauncher launcher;

  Future<void> setUpWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues({
      'app.onboarding_seen_build': AppInfo.readBuildStamp(),
      'app.user_name': 'Lucas',
      ...values,
    });
    preferences = await SharedPreferences.getInstance();
    http = FakeLmStudioHttp();
    launcher = _FakeLauncher(http);
  }

  const lmStudio = {
    'app.local_model_source': 'lm_studio',
    'app.local_model_id': 'qwen3.5-4b-mlx',
    'app.local_model_name': 'Qwen3.5 4B',
  };

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Evergreen',
      packageName: 'com.evergreen.app',
      version: '0.3.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppInfo.load();
  });

  Future<void> pumpAppSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageStoreProvider.overrideWithValue(FakePinImageStore()),
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository(),
          ),
          focusSessionRepositoryProvider.overrideWithValue(
            FakeFocusSessionRepository(),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          backupServiceProvider.overrideWithValue(temporaryBackupService()),
          diskUsageServiceProvider.overrideWithValue(FakeDiskUsageService()),
          diagnosticsServiceProvider.overrideWithValue(
            FakeDiagnosticsService(),
          ),
          lmStudioHttpProvider.overrideWithValue(http),
          lmStudioLauncherProvider.overrideWithValue(launcher),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicativo'));
    await tester.pumpAndSettle();
  }

  Finder dot(String message) => find.byWidgetPredicate(
    (widget) => widget is Tooltip && widget.message == message,
  );

  testWidgets('com o padrão, só a origem — e nada de bolinha', (tester) async {
    await setUpWith({});
    await pumpAppSettings(tester);

    expect(find.text('MODELO LOCAL'), findsOneWidget);
    expect(find.text('Quem escreve'), findsOneWidget);
    expect(find.text('Servidor do LM Studio desligado'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && (widget.message ?? '').contains('LM Studio'),
      ),
      findsNothing,
    );
    // Com o Apple Intelligence, ninguém pergunta nada ao LM Studio.
    expect(http.loaded, isEmpty);
  });

  testWidgets('escolher o LM Studio lista os modelos e já escolhe o primeiro', (
    tester,
  ) async {
    await setUpWith({});
    await pumpAppSettings(tester);

    await tester.tap(find.text('LM Studio'));
    await tester.pumpAndSettle();

    expect(find.text('Qwen3.5 4B'), findsOneWidget);
    expect(find.text('Lê até 262 mil tokens'), findsOneWidget);
    expect(find.text('Em uso'), findsOneWidget);
    expect(preferences.getString('app.local_model_id'), 'qwen3.5-4b-mlx');
    expect(preferences.getString('app.local_model_name'), 'Qwen3.5 4B');

    // Voltar ao padrão apaga as três chaves.
    await tester.tap(find.text('Apple Intelligence'));
    await tester.pumpAndSettle();
    expect(preferences.getString('app.local_model_source'), isNull);
    expect(preferences.getString('app.local_model_id'), isNull);
  });

  testWidgets('servidor desligado: a linha diz isso e "Ligar" liga', (
    tester,
  ) async {
    await setUpWith(lmStudio);
    http.offline = true;
    await pumpAppSettings(tester);

    expect(find.text('Servidor do LM Studio desligado'), findsOneWidget);
    // O Evergreen nunca liga o servidor sozinho.
    expect(launcher.starts, 0);

    await tester.tap(find.text('Ligar'));
    await tester.pumpAndSettle();

    expect(launcher.starts, 1);
    expect(find.text('Servidor do LM Studio desligado'), findsNothing);
    expect(find.text('Qwen3.5 4B'), findsOneWidget);
  });

  testWidgets('servidor que pede token diz isso, e não "desligado"', (
    tester,
  ) async {
    await setUpWith(lmStudio);
    http.status = 401;
    await pumpAppSettings(tester);

    expect(find.text('O LM Studio recusou a conexão'), findsOneWidget);
    expect(find.textContaining('token de API'), findsOneWidget);
    expect(find.text('Servidor do LM Studio desligado'), findsNothing);
  });

  testWidgets('ligar um servidor que pede token mantém o motivo na tela', (
    tester,
  ) async {
    await setUpWith(lmStudio);
    http.offline = true;
    await pumpAppSettings(tester);

    http.status = 401;
    await tester.tap(find.text('Ligar'));
    await tester.pumpAndSettle();

    expect(find.text('O LM Studio recusou a conexão'), findsOneWidget);
    expect(find.textContaining('token de API'), findsOneWidget);
  });

  testWidgets('sem o LM Studio instalado, a linha diz isso sem botão', (
    tester,
  ) async {
    await setUpWith(lmStudio);
    launcher.installed = false;
    await pumpAppSettings(tester);

    expect(find.text('LM Studio não encontrado'), findsOneWidget);
    expect(find.text('Ligar'), findsNothing);
  });

  testWidgets(
    'a bolinha acende com o modelo na memória e apaga quando ele sai',
    (tester) async {
      await setUpWith(lmStudio);
      http.loaded['qwen3.5-4b-mlx'] = 32768;
      await pumpAppSettings(tester);

      expect(dot('Qwen3.5 4B na memória do LM Studio'), findsOneWidget);
      expect(find.text('Lê até 262 mil tokens · na memória'), findsOneWidget);

      // O resumo terminou e o portão descarregou: na pergunta seguinte, apaga.
      http.loaded.clear();
      await tester.pump(LocalModelViewModel.pollInterval);
      await tester.pumpAndSettle();

      expect(dot('Nenhum modelo na memória do LM Studio'), findsOneWidget);
    },
  );
}

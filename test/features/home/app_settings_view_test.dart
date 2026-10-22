import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
import 'package:evergreen/core/storage/backup_service.dart';
import 'package:evergreen/core/storage/disk_usage_service.dart';
import 'package:evergreen/core/system/uninstall_service.dart';
import 'package:evergreen/core/system/update_service.dart';
import 'package:evergreen/core/window/hub_destination.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/app_settings_view.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/backup_list.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_update.dart';
import 'package:evergreen/features/pin/presentation/views/pin_settings_view.dart';
import 'package:evergreen/shared/feature_flags.dart';
import 'package:evergreen/shared/widgets/eg_confirm_dialog.dart';
import 'package:evergreen/shared/widgets/eg_settings_row.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../focus/fake_focus_session_repository.dart';
import 'backup_fixture.dart';
import 'fake_diagnostics_service.dart';
import 'fake_update_service.dart';
import 'fake_disk_usage_service.dart';
import '../pin/fake_clipboard_repository.dart';
import '../pin/fake_pin_image_store.dart';

void main() {
  late SharedPreferences preferences;
  late BackupService backup;
  late FakeDiskUsageService disk;
  late FakeDiagnosticsService diagnostics;
  late _FakeUninstallService uninstall;
  late FakeUpdateService updates;

  setUp(() async {
    // Duas chaves, dois caminhos de primeira vez que este teste não quer: a
    // apresentação de boas-vindas (que espera seis cliques em "Próximo") e a
    // pergunta do nome (que leva o Hub para a tela do aplicativo). Aqui o app
    // já foi apresentado nesta build e já sabe com quem fala.
    SharedPreferences.setMockInitialValues({
      'app.onboarding_seen_build': AppInfo.readBuildStamp(),
      'app.user_name': 'Lucas',
    });
    preferences = await SharedPreferences.getInstance();

    // A versão do rodapé "Sobre" vem do bundle, que não existe em teste.
    PackageInfo.setMockInitialValues(
      appName: 'Evergreen',
      packageName: 'com.evergreen.app',
      version: '0.3.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppInfo.load();
    backup = temporaryBackupService();
    disk = FakeDiskUsageService();
    diagnostics = FakeDiagnosticsService();
    uninstall = _FakeUninstallService();
    updates = FakeUpdateService();
  });

  Future<void> pumpHub(WidgetTester tester) async {
    // Alta: com as seções de backup e de restauração a tela de preferências
    // passou a rolar, e um `tap` em algo fora do viewport não acerta nada —
    // falharia como se o controle não respondesse.
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
          // A seção de backup lê a pasta dela ao montar —
          // em teste as duas são temporárias.
          backupServiceProvider.overrideWithValue(backup),
          diskUsageServiceProvider.overrideWithValue(disk),
          diagnosticsServiceProvider.overrideWithValue(diagnostics),
          // A de verdade encerra o processo — e a suíte junto.
          uninstallServiceProvider.overrideWithValue(uninstall),
          updateServiceProvider.overrideWithValue(updates),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('a marca da barra lateral abre as preferências do aplicativo', (
    tester,
  ) async {
    await pumpHub(tester);

    // O Hub abre no Pin, e o que é do aplicativo não mora mais lá.
    expect(find.byType(PinSettingsView), findsOneWidget);
    expect(find.text('Iniciar com o macOS'), findsNothing);

    await tester.tap(find.text('Aplicativo'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSettingsView), findsOneWidget);
    expect(find.text('Iniciar com o macOS'), findsOneWidget);
    expect(find.text('Abrir minimizado'), findsOneWidget);
    // O atalho que abre esta janela finalmente tem onde ser ensinado.
    expect(find.text('Abrir preferências'), findsOneWidget);
    expect(find.textContaining('Evergreen v'), findsOneWidget);
  });

  testWidgets('voltar para um módulo troca o painel', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.text('Aplicativo').first);
    await tester.pumpAndSettle();
    // `.first` é o item da barra lateral: a tela do aplicativo lista todas as
    // teclas do app, e o nome de cada módulo aparece lá também.
    await tester.tap(find.text(EvergreenModule.pin.name).first);
    await tester.pumpAndSettle();

    expect(find.byType(AppSettingsView), findsNothing);
    expect(find.byType(PinSettingsView), findsOneWidget);
  });

  /// O nome existe para o modelo local ter como chamar quem está do outro lado:
  /// sem ele, o resumo da reunião diz "a pessoa" e a transcrição diz "Você".
  group('o nome', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Aplicativo'));
      await tester.pumpAndSettle();
    }

    testWidgets('preenchido, é uma linha comum em Geral', (tester) async {
      await openSettings(tester);

      expect(find.text('Seu nome'), findsOneWidget);
      // A pergunta de primeira vez não aparece mais para quem já respondeu.
      expect(find.text('COMO VOCÊ SE CHAMA'), findsNothing);
    });

    testWidgets('sair do campo guarda o que foi escrito', (tester) async {
      await openSettings(tester);

      await tester.enterText(find.byType(TextField).first, '  Ana  ');
      // Sem Enter: o que guarda é perder o foco, como toda preferência do
      // Evergreen. E o nome é guardado sem o espaço sobrando, porque ele vira
      // rótulo na transcrição e texto dentro da instrução do modelo.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(preferences.getString('app.user_name'), 'Ana');
    });
  });

  /// A primeira vez de uma instalação: a cena da marca termina e o Hub cai na
  /// tela do aplicativo, onde a pergunta espera com o cursor dentro. Uma vez
  /// por instalação, inclusive para quem deixar em branco — pergunta que reabre
  /// a cada Hub vira cobrança.
  /// Só existe com a abertura animada ligada: é o fim dela que leva o Hub para
  /// esta tela. Desligada, a pergunta do nome continua onde sempre esteve, no
  /// topo daqui — só ninguém é levado até ela.
  group('a primeira vez', skip: !FeatureFlags.intro, () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    testWidgets('sem nome, a abertura entrega a pergunta', (tester) async {
      await pumpHub(tester);

      expect(find.byType(AppSettingsView), findsOneWidget);
      expect(find.byType(PinSettingsView), findsNothing);
      expect(find.text('COMO VOCÊ SE CHAMA'), findsOneWidget);

      // Com o cursor dentro: a pergunta se responde sem tocar no mouse.
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.autofocus, isTrue);
    });

    testWidgets('respondida, a pergunta some da tela', (tester) async {
      await pumpHub(tester);

      await tester.enterText(find.byType(TextField).first, 'Ana');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('COMO VOCÊ SE CHAMA'), findsNothing);
      expect(find.text('Seu nome'), findsOneWidget);
    });
  });

  /// O backup é do banco inteiro, e por isso mora aqui e não na tela de módulo
  /// nenhum — a mesma razão pela qual "iniciar com o macOS" saiu do Pin.
  group('espaço em disco', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Aplicativo'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o total e as partes que existem', (tester) async {
      disk.usage = const DiskUsage(
        database: 3 * 1024 * 1024,
        meetings: 8 * 1024 * 1024,
      );
      await openSettings(tester);

      expect(find.text('ESPAÇO EM DISCO'), findsOneWidget);
      expect(find.text('11,0 MB'), findsOneWidget);
      // Backups e exportações vazios não viram "0 B".
      expect(
        find.text('Banco 3,0 MB · Áudio das reuniões 8,0 MB'),
        findsOneWidget,
      );
    });

    testWidgets('pasta vazia diz que não há nada guardado', (tester) async {
      await openSettings(tester);

      expect(find.text('Nada guardado ainda.'), findsOneWidget);
      expect(find.text('0 B'), findsOneWidget);
    });

    testWidgets('um backup novo mede o disco de novo', (tester) async {
      await openSettings(tester);
      expect(find.text('0 B'), findsOneWidget);

      disk.usage = const DiskUsage(backups: 2048);
      await tester.tap(find.text('Fazer backup'));
      await tester.pumpAndSettle();

      expect(find.text('2 KB'), findsOneWidget);
    });

    testWidgets('mostra a pasta do aplicativo no Finder', (tester) async {
      await openSettings(tester);

      expect(find.text(disk.directoryLabel), findsOneWidget);
      await tester.tap(find.text('Mostrar no Finder').first);
      await tester.pumpAndSettle();

      expect(disk.reveals, 1);
    });
  });

  group('diagnóstico', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Aplicativo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Falhas do macOS'));
      await tester.pumpAndSettle();
    }

    testWidgets('copiar põe o relatório na área de transferência e confirma', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await openSettings(tester);
      expect(find.textContaining('Nada do que você copiou'), findsOneWidget);

      await tester.tap(find.text('Copiar'));
      await tester.pump();

      expect(copied, startsWith('## Diagnóstico do Evergreen'));
      expect(copied, contains('- Chip: Apple M3'));
      expect(find.text('Diagnóstico copiado.'), findsOneWidget);

      // A confirmação some sozinha, e a descrição volta.
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('Nada do que você copiou'), findsOneWidget);
    });

    testWidgets('as duas pastas abrem no Finder', (tester) async {
      await openSettings(tester);

      expect(find.text(diagnostics.logLabel), findsOneWidget);
      Finder revealIn(String row) => find.descendant(
        of: find.ancestor(
          of: find.text(row),
          matching: find.byType(EgSettingsRow),
        ),
        matching: find.text('Mostrar no Finder'),
      );

      await tester.tap(revealIn('Registro de erros'));
      await tester.pump();
      expect(diagnostics.logReveals, 1);
      expect(diagnostics.crashReveals, 0);

      await tester.tap(revealIn('Falhas do macOS'));
      await tester.pump();

      expect(diagnostics.logReveals, 1);
      expect(diagnostics.crashReveals, 1);
    });
  });

  group('backup', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Aplicativo'));
      await tester.pumpAndSettle();
    }

    testWidgets('a tela diz onde os arquivos ficam', (tester) async {
      await openSettings(tester);

      expect(find.text('Backup semanal automático'), findsOneWidget);
      expect(find.text('Pasta dos backups'), findsOneWidget);
      // A pergunta "onde isso foi parar" não pode depender de abrir o Finder.
      expect(find.text(backup.directoryLabel), findsOneWidget);
    });

    testWidgets('sem backup nenhum não há o que restaurar', (tester) async {
      await openSettings(tester);

      expect(find.byType(BackupList), findsNothing);
      expect(find.text('Nenhum backup ainda.'), findsOneWidget);
      expect(find.textContaining('A pasta está vazia'), findsOneWidget);
    });

    testWidgets('fazer backup agora põe a linha na lista', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Fazer backup'));
      await tester.pumpAndSettle();

      expect(find.byType(BackupList), findsOneWidget);
      expect(find.text('Backup criado.'), findsOneWidget);
      // A lista ganhar uma linha é o feedback principal; a frase é o reforço.
      expect(backup.list(), hasLength(1));
    });

    testWidgets('restaurar só acende com um backup escolhido', (tester) async {
      backup.create(at: DateTime(2026, 8, 20, 10));
      await openSettings(tester);

      final button = find.text('Restaurar');
      expect(button, findsOneWidget);

      // Sem escolher, o botão fica apagado em vez de sumir: a ação continua
      // visível, dizendo o que falta para ela existir.
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(EgConfirmDialog), findsNothing);

      await tester.tap(find.byType(BackupList));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Restaurar apaga tudo de uma vez — a pergunta de sim ou não é a única
      // coisa que ainda abre um modal no Evergreen.
      expect(find.byType(EgConfirmDialog), findsOneWidget);
      expect(find.text('Restaurar este backup?'), findsOneWidget);
    });

    testWidgets('a rede da restauração se apresenta na lista', (tester) async {
      backup.create(at: DateTime(2026, 8, 20, 10));
      await openSettings(tester);

      await tester.tap(find.byType(BackupList));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.pumpAndSettle();
      // O botão do diálogo, que está por cima do da tela.
      await tester.tap(find.text('Restaurar').last);
      await tester.pumpAndSettle();

      // Os arquivos do Evergreen aparecem só pela data: sem esta etiqueta, a
      // cópia de emergência seria mais uma linha igual às outras — e é ela que
      // se procura no minuto em que se percebe que a linha clicada era a
      // errada.
      expect(find.text('antes de restaurar'), findsOneWidget);
    });
  });

  group('Atualizações', () {
    Future<void> openAppSettings(WidgetTester tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Aplicativo').first);
      await tester.pumpAndSettle();
    }

    testWidgets('a preferência e o "procurar agora" falam com o Sparkle', (
      tester,
    ) async {
      updates.current = const UpdateState(
        available: true,
        automaticChecks: true,
        canCheck: true,
      );
      await openAppSettings(tester);

      expect(
        find.text('Procurar atualizações automaticamente'),
        findsOneWidget,
      );
      expect(find.text('Ainda não procurou.'), findsOneWidget);

      await tester.ensureVisible(
        find.text('Procurar atualizações automaticamente'),
      );
      final toggle = find.ancestor(
        of: find.text('Procurar atualizações automaticamente'),
        matching: find.byType(EgSettingsRow),
      );
      await tester.tap(
        find.descendant(of: toggle, matching: find.byType(EgToggle)),
      );
      await tester.pumpAndSettle();
      expect(updates.current.automaticChecks, isFalse);

      await tester.ensureVisible(find.text('Procurar'));
      await tester.tap(find.text('Procurar'));
      await tester.pumpAndSettle();
      expect(updates.checks, 1);
    });

    testWidgets('a versão nova acende o "Aplicativo" e abre as novidades', (
      tester,
    ) async {
      updates.current = UpdateState(
        available: true,
        automaticChecks: true,
        canCheck: true,
        phase: UpdatePhase.available,
        version: '1.0.3',
        notes: UpdateNote.parse(
          '<h3>1.0.3</h3><ul><li>Filtros numa linha</li></ul>',
        ),
      );
      await pumpHub(tester);

      // A bolinha mora no botão que leva à tela do aplicativo.
      expect(
        find.bySemanticsLabel(RegExp('Aplicativo, versão 1.0.3 disponível')),
        findsOneWidget,
      );

      await tester.tap(find.text('Aplicativo').first);
      await tester.pumpAndSettle();
      expect(find.text('Versão 1.0.3 disponível'), findsOneWidget);

      await tester.ensureVisible(find.text('Ver novidades'));
      await tester.tap(find.text('Ver novidades'));
      await tester.pumpAndSettle();
      expect(find.byType(HubUpdate), findsOneWidget);
      expect(find.text('Filtros numa linha'), findsOneWidget);

      // "Agora não" fecha a tela e a versão continua anunciada.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HubUpdate), findsNothing);
      expect(find.text('Versão 1.0.3 disponível'), findsOneWidget);

      await tester.ensureVisible(find.text('Ver novidades'));
      await tester.tap(find.text('Ver novidades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atualizar e reiniciar'));
      await tester.pumpAndSettle();
      expect(updates.installs, 1);
    });

    testWidgets('o menu da barra leva direto às novidades', (tester) async {
      updates.current = const UpdateState(
        available: true,
        phase: UpdatePhase.available,
        version: '1.0.3',
      );
      // O item do menu roda na janela 0 e deixa o pedido no disco.
      await preferences.setString('hub.pending_module', HubDestination.update);
      await pumpHub(tester);

      expect(find.byType(HubUpdate), findsOneWidget);
    });

    testWidgets('baixando, o botão mostra o andamento e o Esc não fecha', (
      tester,
    ) async {
      updates.current = const UpdateState(
        available: true,
        phase: UpdatePhase.downloading,
        version: '1.0.3',
        progress: 0.42,
      );
      // O item do menu roda na janela 0 e deixa o pedido no disco.
      await preferences.setString('hub.pending_module', HubDestination.update);
      await pumpHub(tester);

      expect(find.text('Baixando… 42%'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(HubUpdate), findsOneWidget);

      // A releitura de meio em meio segundo fica pendente: o teste a desliga
      // tirando a árvore.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('numa build de desenvolvimento, diz que não se atualiza', (
      tester,
    ) async {
      updates.current = const UpdateState();
      await openAppSettings(tester);

      expect(find.text('Esta cópia não se atualiza sozinha'), findsOneWidget);
      expect(find.text('Procurar'), findsNothing);
    });
  });

  group('Desinstalar', () {
    Future<void> openAppSettings(WidgetTester tester) async {
      await pumpHub(tester);
      await tester.tap(find.text('Aplicativo').first);
      await tester.pumpAndSettle();
      // É a última seção da tela, abaixo da dobra.
      await tester.ensureVisible(find.text('Desinstalar').last);
      await tester.pumpAndSettle();
    }

    testWidgets('aparece na tela do aplicativo, e cancelar não apaga nada', (
      tester,
    ) async {
      await openAppSettings(tester);

      expect(find.text('Desinstalar o Evergreen'), findsOneWidget);

      await tester.tap(find.text('Desinstalar').last);
      await tester.pumpAndSettle();
      expect(find.byType(EgConfirmDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(EgConfirmDialog), findsNothing);
      expect(uninstall.calls, 0);
    });

    testWidgets('confirmar desinstala', (tester) async {
      await openAppSettings(tester);

      await tester.tap(find.text('Desinstalar').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(EgConfirmDialog),
          matching: find.text('Desinstalar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(uninstall.calls, 1);
    });

    testWidgets('o menu da barra cai na tela do aplicativo com a pergunta', (
      tester,
    ) async {
      // O item do menu roda na janela 0 e deixa o pedido no disco, que é o
      // que o Hub lê ao nascer.
      await preferences.setString(
        'hub.pending_module',
        HubDestination.uninstall,
      );

      await pumpHub(tester);

      expect(find.byType(AppSettingsView), findsOneWidget);
      expect(find.text('Desinstalar o Evergreen?'), findsOneWidget);
      expect(uninstall.calls, 0, reason: 'perguntar não é desinstalar');
    });
  });
}

class _FakeUninstallService implements UninstallService {
  int calls = 0;

  @override
  Future<void> uninstall() async => calls++;
}

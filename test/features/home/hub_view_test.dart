import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/leaf/data/leaf_repository.dart';
import 'package:evergreen/features/track/data/track_repository.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/viewmodels/hub_detail_view_model.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/module_switch.dart';
import 'package:evergreen/shared/widgets/eg_screen_header.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../focus/fake_focus_session_repository.dart';
import '../echo/fake_echo_channel.dart';
import '../pin/fake_clipboard_repository.dart';
import 'backup_fixture.dart';
import 'fake_module_settings_notifier.dart';
import '../echo/fake_export_service.dart';

void main() {
  late SharedPreferences preferences;

  /// Um banco de verdade, em memória: o Echo lê as reuniões dele e o Track lê
  /// as quatro tabelas que os módulos escrevem.
  late Database db;

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

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
  });

  tearDown(() => db.close());

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository([]),
          ),
          focusSessionRepositoryProvider.overrideWithValue(
            FakeFocusSessionRepository(),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          // A janela 0, que é quem aplica o interruptor de módulo, não existe
          // dentro de um teste — e a resposta do canal dela nunca chegaria no
          // relógio falso do binding.
          moduleSettingsNotifierProvider.overrideWithValue(
            FakeModuleSettingsNotifier(),
          ),
          // O Echo lê as reuniões do banco e pergunta ao sistema o que a
          // máquina permite — nem um nem outro existem dentro de um teste.
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
          exportServiceProvider.overrideWithValue(FakeExportService()),
          // O Track lê o mesmo banco — ele não tem tabela própria.
          trackRepositoryProvider.overrideWithValue(SqliteTrackRepository(db)),
          // A tela do Leaf lê a parede para dizer quantas vagas estão em uso.
          leafRepositoryProvider.overrideWithValue(SqliteLeafRepository(db)),
          // A tela do aplicativo lê a pasta de backups ao
          // montar.
          backupServiceProvider.overrideWithValue(
            temporaryBackupService(database: db),
          ),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Registra o que o Hub pede à janela dele.
  ///
  /// `WindowController.hide` fala pelo canal do `desktop_multi_window`, que num
  /// teste não tem lado nativo — o mock é o que deixa a intenção de esconder
  /// observável.
  /// Registra quando o Hub vai atrás da própria janela para escondê-la.
  ///
  /// O `hide` em si não acontece em teste — ele passa pelo despachante de
  /// canais do `desktop_multi_window`, que registra um handler real e, com ele,
  /// engole qualquer mock. O que dá para observar, e é o que importa aqui, é o
  /// passo anterior: perguntar ao engine qual é a janela dele. Ninguém mais no
  /// Hub faz essa pergunta, então ela só aparece quando o Esc decidiu sair.
  List<String> watchWindowLookups() {
    final lookups = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('mixin.one/desktop_multi_window');

    messenger.setMockMethodCallHandler(channel, (call) async {
      lookups.add(call.method);
      return call.method == 'getWindowDefinition'
          ? {'windowId': '1', 'windowArgument': 'hub'}
          : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    return lookups;
  }

  group('esc', () {
    testWidgets('sem nada aberto, esconde a janela do Hub', (tester) async {
      final lookups = watchWindowLookups();
      await pumpHub(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(lookups, contains('getWindowDefinition'));
    });

    /// Depois de sair de um campo de texto, o Esc seguinte ainda esconde.
    ///
    /// Só no macOS, que é onde o `TextField` larga o foco a cada clique fora
    /// dele — e o foco largado ia parar no escopo da rota, acima do
    /// `CallbackShortcuts` do Hub. Dali nenhuma tecla voltava a descer: um
    /// clique num campo de preferência deixava a janela sem Esc até ser
    /// reaberta. Nas outras plataformas o campo não larga nada, e o teste
    /// passaria sem testar.
    testWidgets(
      'depois de sair de um campo, o Esc ainda esconde a janela',
      (tester) async {
        final lookups = watchWindowLookups();
        await pumpHub(tester);

        // O Echo é a única tela do Hub com campo de texto — e ele mora na aba
        // de ajustes, que não é a que abre: quem abre o Echo vem ver as
        // reuniões.
        await tester.tap(find.text('Echo').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
        final field = find.byType(TextField).first;
        await tester.dragUntilVisible(
          field,
          find.byType(SingleChildScrollView).first,
          const Offset(0, -80),
        );
        await tester.tap(field);
        await tester.pumpAndSettle();

        // Um clique em qualquer outro lugar da janela tira o cursor do campo.
        await tester.tap(find.text('Evergreen').first);
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(lookups, contains('getWindowDefinition'));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('com a região aberta, fecha a região e a janela fica', (
      tester,
    ) async {
      final lookups = watchWindowLookups();
      await pumpHub(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HubView)),
      );
      container.read(hubDetailProvider.notifier).open(EvergreenModule.echo);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Um Esc desfaz uma coisa só, e a de dentro vem primeiro.
      expect(container.read(hubDetailProvider), isNull);
      expect(lookups, isEmpty);
    });
  });

  /// Nenhuma tela do Hub pode estourar na largura mínima da janela (720px, em
  /// `MainFlutterWindow.swift`). É a largura em que a pessoa pode deixar a
  /// janela, e uma linha de configuração que não cabe vira uma faixa listrada
  /// atravessando a tela.
  ///
  /// Não há `expect`: um `RenderFlex overflowed` já reprova o teste sozinho.
  testWidgets('nenhuma tela estoura na largura mínima da janela', (
    tester,
  ) async {
    await pumpHub(tester);

    tester.view.physicalSize = const Size(720, 900);
    await tester.pumpAndSettle();

    for (final module in EvergreenModule.values) {
      // `.first` é o item da barra lateral: o módulo aberto tem o mesmo nome no
      // cabeçalho da tela, e a barra vem antes na árvore.
      await tester.tap(find.text(module.name).first);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Aplicativo'));
    await tester.pumpAndSettle();
  });

  /// A tela de um módulo curto (o Awake) tem menos conteúdo que a janela, e a
  /// área de detalhe rola: sem esticar a linha do Hub, ela encolhia até a altura
  /// do conteúdo e o `Row` a centralizava verticalmente — o módulo abria com o
  /// texto no meio da tela enquanto Pin e Focus abriam no topo.
  testWidgets('toda tela do Hub começa no topo, cheia ou vazia', (
    tester,
  ) async {
    await pumpHub(tester);

    double topOf(EvergreenModule module) {
      // `.last` porque o nome do módulo aparece duas vezes: na barra lateral e
      // no cabeçalho da tela.
      return tester.getTopLeft(find.text(module.name).last).dy;
    }

    final expected = topOf(EvergreenModule.pin);

    for (final module in EvergreenModule.values) {
      await tester.tap(find.text(module.name).first);
      await tester.pumpAndSettle();

      expect(
        topOf(module),
        expected,
        reason: 'o cabeçalho de ${module.name} não começa na mesma altura',
      );
    }
  });

  group('ligar e desligar um módulo', () {
    /// Abre a tela de um módulo pela barra lateral.
    Future<void> open(WidgetTester tester, EvergreenModule module) async {
      await tester.tap(find.text(module.name).first);
      await tester.pumpAndSettle();
    }

    /// A tranca que o [ModuleGate] fecha por cima da tela do módulo.
    Finder closedGate() => find.descendant(
      of: find.byType(ModuleGate),
      matching: find.byType(ExcludeFocus),
    );

    /// Vira o interruptor mestre da tela aberta — o do topo, não os do módulo.
    Future<void> flip(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(EgMasterSwitch),
          matching: find.byType(EgToggle),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('todo módulo disponível abre com o interruptor no topo', (
      tester,
    ) async {
      await pumpHub(tester);

      for (final module in EvergreenModule.values.where((m) => m.isAvailable)) {
        await open(tester, module);

        // O Track é o único sem interruptor: ele não liga nem desliga, se
        // apaga quando os módulos que o alimentam se apagam. No lugar da
        // chave, ele diz o que é.
        if (module == EvergreenModule.track) {
          expect(find.byType(EgMasterSwitch), findsNothing);
          expect(find.text('nada é gravado aqui'), findsOneWidget);
          continue;
        }

        expect(
          find.byType(EgMasterSwitch),
          findsOneWidget,
          reason: 'o ${module.name} abriu sem interruptor',
        );
      }
    });

    testWidgets('desligado, o módulo continua na lista e some do resto', (
      tester,
    ) async {
      await pumpHub(tester);
      await open(tester, EvergreenModule.leaf);

      await flip(tester);

      // Continua na barra lateral — é por ela que se religa. Some da lista é o
      // beco sem saída que este arranjo existe para evitar.
      expect(find.text('Leaf'), findsWidgets);
      expect(find.text('Desligado'), findsOneWidget);

      // E o corpo da tela fica apagado e fora de alcance: o `ExcludeFocus` é o
      // que o `ModuleGate` põe por fora de tudo, e nada mais no app usa um.
      expect(closedGate(), findsOneWidget);
    });

    testWidgets('religar devolve a tela inteira', (tester) async {
      await pumpHub(tester);
      await open(tester, EvergreenModule.leaf);

      await flip(tester);
      expect(find.text('Desligado'), findsOneWidget);

      await flip(tester);
      expect(find.text('Desligado'), findsNothing);
      expect(closedGate(), findsNothing);
    });
  });
}

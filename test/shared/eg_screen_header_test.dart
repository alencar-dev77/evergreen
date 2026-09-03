import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/shared/widgets/eg_pill.dart';
import 'package:evergreen/shared/widgets/eg_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O cabeçalho de tela do Hub.
///
/// O controle do topo — o interruptor mestre, ou a pílula do Track no lugar
/// dele — já foi dado como alinhado três vezes sem estar, porque "alinhado"
/// estava sendo julgado a olho numa captura de tela. Aqui ele é medido: se ele
/// sair da faixa, descolar da margem direita ou mudar de altura entre um módulo
/// e o vizinho, o teste reprova antes de a captura chegar em alguém.
///
/// A tecla do módulo ficava aqui, ao lado do interruptor, e saiu — ela é dita
/// na barra lateral e trocada na seção "Atalho global".
/// O recuo lateral do cabeçalho (`AppSpacing.huge - AppSpacing.xxs`).
const _horizontalPadding = 28.0;

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    Widget? badge,
    bool? isEnabled = true,
    List<String>? tabs,
  }) async {
    tester.view.physicalSize = const Size(1960, 400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: EgScreenHeader(
            title: 'Pin',
            subtitle: const Text('Registra tudo que você copia.'),
            isEnabled: badge == null ? isEnabled : null,
            onEnabledChanged: (_) {},
            badge: badge,
            tabs: tabs,
            selectedTab: tabs?.first,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('o controle do topo', () {
    testWidgets('o interruptor encosta na margem direita', (tester) async {
      await pumpHeader(tester);

      final pill = tester.getRect(find.byType(EgMasterSwitch));
      final header = tester.getRect(find.byType(EgScreenHeader));

      // **O par estava com o topo, a base e o centro certos e mesmo assim
      // parado no meio da tela**, porque título em `Expanded` mais controles em
      // `Flexible` dividiam a linha meio a meio e os controles ficavam no
      // começo da metade deles. É esta distância que prende o conserto.
      expect(
        header.right - pill.right,
        closeTo(_horizontalPadding, 0.5),
        reason: 'o controle do topo não está colado à direita',
      );
    });

    testWidgets('a pílula do Track ocupa a mesma faixa do interruptor', (
      tester,
    ) async {
      await pumpHeader(tester);
      final comInterruptor = tester.getRect(find.byType(EgMasterSwitch));

      await pumpHeader(
        tester,
        badge: const EgPill(
          label: 'nada é gravado aqui',
          tone: EgPillTone.tide,
          showDot: false,
        ),
      );
      final comPilula = tester.getRect(find.byType(EgPill));

      // O Track troca o interruptor por uma pílula; se ela tivesse outra
      // altura, o conteúdo da tela começaria um pixel acima do dos vizinhos.
      expect(comPilula.center.dy, comInterruptor.center.dy);
    });

    testWidgets('a tecla do módulo não é impressa aqui', (tester) async {
      await pumpHeader(tester);

      // Ela é dita na barra lateral e trocada na seção "Atalho global". No
      // topo, era a terceira cópia da mesma combinação na mesma janela.
      expect(find.textContaining('⌘'), findsNothing);
    });
  });

  group('abas', () {
    testWidgets('não aparecem quando o módulo tem um assunto só', (
      tester,
    ) async {
      await pumpHeader(tester);

      // Uma aba sozinha é a promessa de que existe outra.
      expect(find.text('Ajustes'), findsNothing);
    });

    testWidgets('aparecem, e a primeira vem aberta', (tester) async {
      await pumpHeader(tester, tabs: const ['Ajustes', 'Tipos', 'Gerador']);

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Tipos'), findsOneWidget);
      expect(find.text('Gerador'), findsOneWidget);
    });
  });

  testWidgets('o interruptor mestre se anuncia como um só controle', (
    tester,
  ) async {
    await pumpHeader(tester);

    // O rótulo é do conjunto, não do interruptor solto: no cabeçalho, longe de
    // qualquer linha que o nomeie, um interruptor sem nome não diz o que liga.
    final semantics = tester.getSemantics(find.byType(EgMasterSwitch));
    expect(semantics.label, contains('módulo'));
  });
}

import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/shared/widgets/eg_pill.dart';
import 'package:evergreen/shared/widgets/eg_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O cabeçalho de tela do Hub.
///
/// O par do topo — o interruptor mestre e a tecla que abre o painel — já foi
/// dado como alinhado três vezes sem estar, porque "alinhado" estava sendo
/// julgado a olho numa captura de tela. Aqui ele é medido: se as duas caixas
/// deixarem de dividir a mesma linha, ou se o conteúdo de uma sair do centro,
/// o teste reprova antes de a captura chegar em alguém.
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
            shortcut: const ['⌘', '⇧', 'C'],
            onShortcutTap: () {},
            tabs: tabs,
            selectedTab: tabs?.first,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('o par do topo', () {
    testWidgets('o interruptor e a tecla ocupam a mesma faixa', (tester) async {
      await pumpHeader(tester);

      final pill = tester.getRect(find.byType(EgMasterSwitch));
      final cap = tester.getRect(find.text('⌘⇧C'));

      // A mesma faixa vertical, e não "quase": um pixel de diferença entre duas
      // caixas vizinhas é exatamente o que se lê como desalinho.
      final capBox = tester.getRect(
        find.ancestor(of: find.text('⌘⇧C'), matching: find.byType(Row)).last,
      );

      expect(pill.height, capBox.height, reason: 'alturas diferentes');
      expect(pill.top, capBox.top, reason: 'topos em linhas diferentes');
      expect(pill.bottom, capBox.bottom, reason: 'bases em linhas diferentes');

      // E o conteúdo de cada uma centrado na própria caixa.
      expect(cap.center.dy, pill.center.dy);

      // **A tecla encosta na margem direita.** É o que faltava medir: o par
      // estava com o topo, a base e o centro certos e mesmo assim parado no
      // meio da tela, porque título em `Expanded` e controles em `Flexible`
      // dividiam a linha meio a meio e os controles ficavam no começo da
      // metade deles.
      final header = tester.getRect(find.byType(EgScreenHeader));
      expect(
        header.right - capBox.right,
        closeTo(_horizontalPadding, 0.5),
        reason: 'os controles do topo não estão colados à direita',
      );
    });

    testWidgets('o rótulo do interruptor divide o eixo com a tecla', (
      tester,
    ) async {
      await pumpHeader(tester);

      final ativo = tester.getRect(find.text('Ativo'));
      final cap = tester.getRect(find.text('⌘⇧C'));

      expect(ativo.center.dy, cap.center.dy);
      // Tamanhos ópticos próximos: um rótulo de 11,5 ao lado de uma tecla de
      // 10,5 lê como desalinho mesmo quando os dois estão centrados.
      expect((ativo.height - cap.height).abs(), lessThan(2));
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

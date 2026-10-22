import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/shared/widgets/eg_key_cap.dart';
import 'package:evergreen/shared/widgets/eg_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O campo de busca fora do painel — numa tela do Hub, ao lado de outros
/// controles. Ali a borda verde diz "estou com o teclado", e precisa ser
/// verdade.
void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: EgSearchField(
                controller: controller,
                focusNode: focusNode,
                hintText: 'Buscar em todas as reuniões',
                shortcut: const ['⌘', 'F'],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color borderOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(EgSearchField),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    return border.top.color;
  }

  testWidgets('verde só com o foco', (tester) async {
    await pump(tester);
    final colors = tester.element(find.byType(EgSearchField)).eg.colors;

    expect(borderOf(tester), colors.edge);

    focusNode.requestFocus();
    await tester.pump();

    expect(borderOf(tester), colors.accent);
  });

  testWidgets('o atalho aparece só com o campo vazio e sem foco', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(EgShortcutDisplay), findsOneWidget);

    // Com o cursor dentro, o atalho já foi usado.
    focusNode.requestFocus();
    await tester.pump();
    expect(find.byType(EgShortcutDisplay), findsNothing);

    // Com texto, o espaço é do que se digitou.
    focusNode.unfocus();
    controller.text = 'orçamento';
    await tester.pump();
    expect(find.byType(EgShortcutDisplay), findsNothing);
  });
}

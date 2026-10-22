import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/shared/widgets/eg_icon.dart';
import 'package:evergreen/shared/widgets/eg_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fila do Pin com todos os tipos no histórico não cabe nos 420px do
/// painel. Sem ícones o controle quebra linha; com eles, fica numa linha só.
void main() {
  const options = <String?>[
    null,
    'Textos',
    'Links',
    'E-mails',
    'Telefones',
    'CPF',
    'CNPJ',
    'Imagens',
    'Comandos',
  ];

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    String? value,
    bool withIcons = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: EgSegmentedControl<String?>(
              value: value,
              options: options,
              labelOf: (option) => option ?? 'Tudo',
              onChanged: (_) {},
              bare: true,
              focusable: false,
              iconOf: withIcons
                  ? (option) => option == null ? null : EgIconData.document
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('com largura, os rótulos aparecem e não há ícone', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    expect(find.text('Imagens'), findsOneWidget);
    expect(find.byType(EgIcon), findsNothing);
  });

  testWidgets('sem largura, vira ícone e fica numa linha só', (tester) async {
    await pump(tester, width: 404, value: 'Imagens');

    // O "Tudo" não tem ícone e continua escrito; a escolhida mostra os dois.
    expect(find.text('Tudo'), findsOneWidget);
    expect(find.text('Imagens'), findsOneWidget);
    expect(find.text('Textos'), findsNothing);
    expect(find.byType(EgIcon), findsNWidgets(options.length - 1));

    final top = tester.getTopLeft(find.text('Tudo')).dy;
    for (final icon in tester.widgetList<EgIcon>(find.byType(EgIcon))) {
      final y = tester.getCenter(find.byWidget(icon)).dy;
      expect((y - top).abs(), lessThan(20), reason: 'quebrou linha');
    }
  });

  testWidgets('sem ícones, continua quebrando linha como antes', (
    tester,
  ) async {
    await pump(tester, width: 404, withIcons: false);

    expect(find.text('Comandos'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Comandos')).dy,
      greaterThan(tester.getTopLeft(find.text('Tudo')).dy),
    );
  });
}

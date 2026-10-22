import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/shared/widgets/eg_segmented_control.dart';
import 'package:evergreen/shared/widgets/eg_settings_card.dart';
import 'package:evergreen/shared/widgets/eg_settings_row.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A linha de configuração, medida.
///
/// O desalinho dos interruptores do Focus — cada um parando num x diferente,
/// conforme o comprimento da explicação da linha — não quebra nenhum outro
/// teste e não aparece em nenhum erro: só numa captura de tela. Aqui ele é
/// medido, e a regra que ele feria (o controle mora na borda do cartão, o
/// rótulo fica com o resto) vale junto com a que veio antes dela — quem se
/// mede primeiro continua sendo o controle.
void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<Widget> rows, {
    double width = 340,
  }) async {
    tester.view.physicalSize = const Size(1960, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: EgSettingsCard(title: 'Funcionalidades', children: rows),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a coluna da direita', () {
    testWidgets('os interruptores param todos no mesmo x', (tester) async {
      await pumpCard(tester, [
        EgSettingsRow.toggle(
          label: 'Utilizar apenas Pomodoro',
          description:
              'Só o cronômetro: sem atividade nem resumo. O histórico '
              'registra as sessões mesmo assim.',
          value: false,
          onChanged: (_) {},
        ),
        EgSettingsRow.toggle(
          label: 'Tocar som ao finalizar',
          description: 'O som de alerta do próprio macOS.',
          value: true,
          onChanged: (_) {},
        ),
        EgSettingsRow.toggle(label: 'Avisar na tela', value: true),
      ]);

      final toggles = tester
          .widgetList<EgToggle>(find.byType(EgToggle))
          .toList();
      expect(toggles, hasLength(3));

      final edges = <double>{
        for (var i = 0; i < toggles.length; i++)
          tester.getRect(find.byType(EgToggle).at(i)).right,
      };

      // Um conjunto de um valor só: explicação curta, longa ou nenhuma, a
      // resposta da linha fica sempre na mesma distância da borda do cartão.
      expect(edges, hasLength(1));
    });
  });

  group('o seletor que não cabe ao lado do texto', () {
    /// Quatro opções com rótulo de texto: é o idioma da transcrição do Echo, a
    /// fila que quebrava em duas fileiras e deixava o "ES" parecendo um item
    /// esquecido embaixo dos outros três.
    Widget languages() => EgSegmentedControl<String>(
      value: 'PT-BR',
      options: const ['PT-BR', 'PT-PT', 'EN', 'ES'],
      labelOf: (option) => option,
      onChanged: (_) {},
    );

    testWidgets('desce inteiro, e continua numa fileira só', (tester) async {
      await pumpCard(tester, [
        EgSettingsRow(
          label: 'Idioma da transcrição',
          description:
              'No idioma errado, a transcrição não sai pior: sai '
              'inútil.',
          trailing: languages(),
        ),
      ]);

      final control = tester.getRect(find.byType(EgSegmentedControl<String>));
      final label = tester.getRect(find.text('Idioma da transcrição'));

      // Debaixo do texto, e alinhado com ele — não à direita, procurando um
      // lugar.
      expect(control.top, greaterThan(label.bottom));
      expect(control.left, label.left);

      // Uma fileira só: a altura é a de um segmento, e não a de dois.
      final oneRow = await _aloneSize(tester, languages());
      expect(control.height, oneRow.height);
      expect(control.width, oneRow.width);
    });
  });

  group('a linha de campo de texto', () {
    testWidgets('o rótulo dela começa onde começam os outros', (tester) async {
      await pumpCard(tester, [
        EgSettingsRow.toggle(
          label: 'Transcrever ao vivo',
          value: true,
          onChanged: (_) {},
        ),
        EgSettingsRow.field(
          label: 'Como você quer o resumo',
          field: const SizedBox(height: 40),
        ),
      ]);

      // O recuo lateral é do cartão. Pedido de novo pela linha, ele dobrava — e
      // o cartão ficava com uma linha recuada no meio das outras.
      expect(
        tester.getRect(find.text('Como você quer o resumo')).left,
        tester.getRect(find.text('Transcrever ao vivo')).left,
      );
    });
  });

  group('o controle largo', () {
    /// Cinco opções são o seletor de durações do Focus, que é o caso que fez a
    /// regra existir: medido depois do rótulo, ele quebrava em fileiras.
    Widget durations() => EgSegmentedControl<int>(
      value: 25,
      options: const [15, 25, 40, 50, 90],
      labelOf: (minutes) => '$minutes min',
      onChanged: (_) {},
    );

    testWidgets('fica com a largura que teria sozinho', (tester) async {
      await pumpCard(tester, [
        EgSettingsRow(label: 'Duração da sessão', trailing: durations()),
      ], width: 900);
      final inRow = tester.getRect(find.byType(EgSegmentedControl<int>)).width;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: IntrinsicWidth(child: durations()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final alone = tester.getRect(find.byType(EgSegmentedControl<int>)).width;

      expect(inRow, alone);
    });
  });
}

/// O tamanho que um controle tem quando ninguém o aperta.
Future<Size> _aloneSize(WidgetTester tester, Widget control) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(child: control),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return tester.getRect(find.byWidget(control)).size;
}

import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/models/pin_quick_shortcut.dart';
import 'package:evergreen/features/nest/models/nest_item.dart';
import 'package:evergreen/features/nest/presentation/widgets/nest_item_card.dart';
import 'package:evergreen/features/pin/presentation/widgets/pin_list_item.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_icon.dart';
import 'package:evergreen/shared/widgets/eg_key_cap.dart';
import 'package:evergreen/shared/widgets/eg_settings_row.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O que o VoiceOver encontra na interface do Evergreen.
///
/// Existe porque nada disto aparece na tela: um rótulo semântico que some não
/// quebra nenhum pixel e não falha nenhum outro teste — ele simplesmente deixa
/// de existir, em silêncio. É o mesmo motivo pelo qual a matriz de estados
/// visuais tem um golden.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('elemento interativo', () {
    testWidgets('botão se anuncia como botão, com o rótulo visível', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, EgButton(label: 'Copiar', onPressed: () {}));

      expect(
        tester.getSemantics(find.byType(EgButton)),
        isSemantics(
          label: 'Copiar',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('botão sem ação se anuncia desabilitado', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const EgButton(label: 'Restaurar'));

      expect(
        tester.getSemantics(find.byType(EgButton)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );

      handle.dispose();
    });

    testWidgets('botão só de ícone toma o nome do tooltip', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        EgIconButton(
          icon: EgIconData.star,
          tooltip: 'Fixar (⌘P)',
          onPressed: () {},
        ),
      );

      // Sem isto ele é, para quem não vê a tela, um botão sem nome nenhum.
      expect(find.bySemanticsLabel('Fixar (⌘P)'), findsOneWidget);

      handle.dispose();
    });
  });

  group('estado que só a cor mostraria', () {
    testWidgets('a linha escolhida se anuncia escolhida', (tester) async {
      final handle = tester.ensureSemantics();
      final item = ClipboardItem.capture('12345678900');

      await pump(
        tester,
        SizedBox(
          width: 400,
          child: PinListItem(item: item, isSelected: true, onTap: () {}),
        ),
      );

      expect(
        tester.getSemantics(find.byType(PinListItem)),
        isSemantics(isSelected: true, hasSelectedState: true),
      );

      handle.dispose();
    });

    testWidgets('a linha não escolhida fica calada sobre isso', (tester) async {
      final handle = tester.ensureSemantics();
      final item = ClipboardItem.capture('12345678900');

      await pump(
        tester,
        SizedBox(
          width: 400,
          child: PinListItem(item: item, isSelected: false, onTap: () {}),
        ),
      );

      // "Não selecionado" em toda linha é ruído: o padrão do macOS é anunciar
      // só o item escolhido.
      expect(
        tester.getSemantics(find.byType(PinListItem)),
        isSemantics(hasSelectedState: false),
      );

      handle.dispose();
    });

    testWidgets('a linha da prateleira diz o nome e o que o arquivo é', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        SizedBox(
          width: 400,
          child: NestItemCard(
            item: NestItem(
              path: '/Users/eu/Documentos/contrato.pdf',
              isDirectory: false,
              sizeInBytes: 2048,
              modifiedAt: DateTime(2026, 8, 28),
            ),
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      // A miniatura é uma imagem sem texto: sem esta frase a lista sai como uma
      // sequência de nomes de arquivo sem nada que os distinga.
      expect(
        tester.getSemantics(find.byType(NestItemCard)),
        isSemantics(label: 'contrato.pdf, 2 KB'),
      );

      handle.dispose();
    });

    testWidgets('o arquivo que sumiu diz isso, e não só fica apagado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        SizedBox(
          width: 400,
          child: NestItemCard(
            item: NestItem(
              path: '/Users/eu/Documentos/contrato.pdf',
              isDirectory: false,
              sizeInBytes: 2048,
              modifiedAt: DateTime(2026, 8, 28),
              isMissing: true,
            ),
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(NestItemCard)),
        isSemantics(label: 'contrato.pdf, não está mais no lugar'),
      );

      handle.dispose();
    });

    testWidgets('o interruptor é interruptor, não botão', (tester) async {
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        SizedBox(
          width: 600,
          child: EgSettingsRow.toggle(
            label: 'Iniciar com o macOS',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      // O rótulo está na linha e o estado no controle: só juntos eles dizem
      // alguma coisa, e por isso a linha inteira é um item só.
      expect(
        tester.getSemantics(find.byType(EgToggle)),
        isSemantics(
          label: 'Iniciar com o macOS',
          hasToggledState: true,
          isToggled: true,
          isButton: false,
        ),
      );

      handle.dispose();
    });
  });

  group('o que o desenho não fala', () {
    testWidgets('a linha do Pin diz o que é, o tipo e o atalho', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final item = ClipboardItem.capture(
        'um texto qualquer',
      ).copyWith(alias: 'anotação', isPinned: true);

      await pump(
        tester,
        SizedBox(
          width: 400,
          child: PinListItem(
            item: item,
            isSelected: false,
            shortcut: const PinQuickShortcut(
              group: PinShortcutGroup.pinned,
              number: 2,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(PinListItem)),
        isSemantics(
          label: 'anotação: um texto qualquer, Texto, fixado, atalho Option 2',
        ),
      );

      handle.dispose();
    });

    testWidgets('o atalho é falado por extenso, não pelos símbolos', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const EgShortcutDisplay(keys: ['⌘', '⇧', 'C']));

      // `⌘⇧C` lido caractere a caractere não ensina o atalho a ninguém.
      expect(
        tester.getSemantics(find.byType(EgShortcutDisplay)),
        isSemantics(label: 'Atalho Command Shift C'),
      );

      handle.dispose();
    });

    testWidgets('ícone é decorativo enquanto ninguém o nomeia', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const EgIcon(EgIconData.star));

      // O pai é quem nomeia: nomear os dois faria o leitor dizer duas vezes.
      expect(
        find.descendant(
          of: find.byType(EgIcon),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('ícone nomeado vira imagem com legenda', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const EgIcon(EgIconData.star, semanticLabel: 'Guardada'),
      );

      expect(
        tester.getSemantics(find.byType(EgIcon)),
        isSemantics(label: 'Guardada', isImage: true),
      );

      handle.dispose();
    });
  });
}

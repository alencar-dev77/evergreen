import 'package:evergreen/core/design/app_colors.dart';
import 'package:evergreen/core/design/app_theme_id.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/shared/widgets/eg_hoverable.dart';
import 'package:flutter_test/flutter_test.dart';

/// A ordem de precedência da matriz de estado é a regra que mais barato se
/// quebra sem ninguém notar: basta um `if` a mais na ordem errada, num
/// componente só, para "onde o teclado está" sumir quando o mouse passa por
/// cima. Estes testes prendem a tabela documentada em `EgSurfaceStyle`.
void main() {
  // Os tokens do tema da casa, sem árvore de widgets: a ordem de precedência
  // não depende de pele nenhuma, e prendê-la num tema só mantém o teste sobre a
  // tabela em vez de sobre as cores.
  final eg = EgTokens.of(AppThemeId.evergreen);
  final style = eg.surfaces.row;

  const rest = EgInteraction();
  const hovered = EgInteraction(isHovered: true);
  const pressed = EgInteraction(isPressed: true);
  const focused = EgInteraction(isFocused: true);

  group('precedência de estados', () {
    test('repouso é a superfície de repouso', () {
      expect(style.backgroundFor(rest), AppColors.transparent);
    });

    test('hover e foco compartilham a superfície', () {
      expect(style.backgroundFor(hovered), eg.colors.hover);
      expect(style.backgroundFor(focused), eg.colors.hover);
    });

    test('pressed vence hover', () {
      expect(
        style.backgroundFor(
          const EgInteraction(isHovered: true, isPressed: true),
        ),
        eg.colors.pressed,
      );
    });

    test('selecionado vence pressed e hover', () {
      expect(
        style.backgroundFor(
          const EgInteraction(isHovered: true, isPressed: true),
          isSelected: true,
        ),
        eg.colors.selection,
      );
    });

    test('desabilitado vence tudo e volta ao repouso', () {
      expect(
        style.backgroundFor(
          const EgInteraction(isHovered: true, isPressed: true),
          isSelected: true,
          isEnabled: false,
        ),
        AppColors.transparent,
      );
    });
  });

  group('seleção e hover nunca são a mesma cor', () {
    test('em todas as colunas com estado selecionado', () {
      final styles = [eg.surfaces.row, eg.surfaces.card, eg.surfaces.segment];

      for (final style in styles) {
        expect(style.selected, isNotNull);
        expect(
          style.selected,
          isNot(style.hover),
          reason: 'seleção é accent, hover é neutro (colors.md)',
        );
      }
    });
  });

  group('conteúdo', () {
    test('o texto só reage à seleção quando a coluna prevê isso', () {
      expect(style.foregroundFor(hovered), eg.colors.textPrimary);
      expect(
        style.foregroundFor(rest, isSelected: true),
        eg.colors.accentLight,
      );
    });

    test('sem superfície própria, é o conteúdo que reage ao mouse', () {
      final ghost = eg.surfaces.ghost;
      expect(ghost.foregroundFor(rest), eg.colors.textSecondary);
      expect(ghost.foregroundFor(hovered), eg.colors.textPrimary);
      expect(ghost.foregroundFor(pressed), eg.colors.textPrimary);
    });
  });

  group('anel de foco', () {
    test('só aparece com o foco de teclado', () {
      expect(style.shadowFor(rest, eg), isNull);
      expect(style.shadowFor(hovered, eg), isNull);
      expect(style.shadowFor(focused, eg), isNotNull);
    });

    test('não aparece em controle desabilitado', () {
      expect(style.shadowFor(focused, eg, isEnabled: false), isNull);
    });
  });

  group('aresta de seleção', () {
    test('só aparece no estado selecionado', () {
      expect(style.edgeFor(rest), isNull);
      expect(style.edgeFor(hovered), isNull);
      expect(style.edgeFor(pressed), isNull);
      expect(style.edgeFor(focused), isNull);
      expect(style.edgeFor(rest, isSelected: true), eg.colors.accent);
    });

    test('vale para as colunas que ocupam a largura de um bloco', () {
      expect(eg.surfaces.row.selectedEdge, isNotNull);
      expect(eg.surfaces.card.selectedEdge, isNotNull);
    });

    test('a pílula do segmented control não tem aresta', () {
      // Numa pílula de 60px a aresta viraria metade do componente — ali o que
      // marca a escolha é a superfície.
      expect(eg.surfaces.segment.selectedEdge, isNull);
    });

    test('quem não tem seleção não tem aresta', () {
      for (final column in [
        eg.surfaces.ghost,
        eg.surfaces.primary,
        eg.surfaces.secondary,
        eg.surfaces.destructive,
      ]) {
        expect(column.selectedEdge, isNull);
      }
    });
  });
}

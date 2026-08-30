import 'package:evergreen/core/design/app_colors.dart';
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
  final eg = EgTokens.evergreen();
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
      // Contra o que a própria coluna declara, e não contra um token nomeado:
      // o que se prende aqui é a ordem, não a cor. Quando a paleta muda, este
      // teste continua dizendo a mesma coisa.
      expect(style.backgroundFor(hovered), style.hover);
      expect(style.backgroundFor(focused), style.hover);
    });

    test('pressed vence hover', () {
      expect(
        style.backgroundFor(
          const EgInteraction(isHovered: true, isPressed: true),
        ),
        style.pressed,
      );
    });

    test('selecionado vence pressed e hover', () {
      expect(
        style.backgroundFor(
          const EgInteraction(isHovered: true, isPressed: true),
          isSelected: true,
        ),
        style.selected,
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
      final styles = [
        eg.surfaces.row,
        eg.surfaces.sidebarItem,
        eg.surfaces.glassRow,
        eg.surfaces.card,
        eg.surfaces.segment,
      ];

      for (final style in styles) {
        expect(style.selected, isNotNull);
        expect(
          style.selected,
          isNot(style.hover),
          reason:
              'selecionado é um degrau acima do hover — se empatam, passar o '
              'mouse numa linha vizinha a faz parecer a escolhida',
        );
      }
    });
  });

  group('conteúdo', () {
    test('o texto só reage à seleção quando a coluna prevê isso', () {
      // A linha em repouso fala baixo; selecionada, sobe para o primeiro
      // plano. É metade da assinatura de seleção do "Estufa" — a outra metade
      // é a superfície elevada, e nenhuma das duas é cor.
      expect(style.foregroundFor(rest), eg.colors.textSecondary);
      expect(style.foregroundFor(rest, isSelected: true), eg.colors.textPrimary);

      // Uma coluna sem noção de seleção devolve o mesmo conteúdo de sempre.
      final primary = eg.surfaces.primary;
      expect(
        primary.foregroundFor(rest, isSelected: true),
        primary.foregroundFor(rest),
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

  group('linha de luz da seleção', () {
    test('só acende no estado selecionado', () {
      expect(style.hairlineFor(rest), isNull);
      expect(style.hairlineFor(hovered), isNull);
      expect(style.hairlineFor(pressed), isNull);
      expect(style.hairlineFor(focused), isNull);
      expect(
        style.hairlineFor(rest, isSelected: true),
        eg.elevations.rowInnerHairline,
      );
    });

    test('vale para as colunas que ocupam a largura de um bloco', () {
      expect(eg.surfaces.row.innerHairline, isNotNull);
      expect(eg.surfaces.card.innerHairline, isNotNull);
      expect(eg.surfaces.glassRow.innerHairline, isNotNull);
    });

    test('a pílula do segmented control não tem linha de luz', () {
      // Numa pílula de 60px a linha viraria a metade de cima do componente —
      // ali o que marca a escolha é a superfície mais o peso do rótulo.
      expect(eg.surfaces.segment.innerHairline, isNull);
    });

    test('quem não tem seleção não tem linha de luz', () {
      for (final column in [
        eg.surfaces.ghost,
        eg.surfaces.primary,
        eg.surfaces.neutralStrong,
        eg.surfaces.secondary,
        eg.surfaces.destructive,
      ]) {
        expect(column.innerHairline, isNull);
      }
    });
  });

  group('o verde perdeu papéis', () {
    test('selecionado não é accent em nenhuma família', () {
      for (final column in [
        eg.surfaces.row,
        eg.surfaces.sidebarItem,
        eg.surfaces.card,
        eg.surfaces.segment,
      ]) {
        expect(column.selected, isNot(eg.colors.accent));
      }
    });

    test('o anel de foco é branco, e não accent', () {
      expect(eg.colors.focusRing.r, eg.colors.focusRing.g);
      expect(eg.colors.focusRing.g, eg.colors.focusRing.b);
    });

    test('accent só é superfície de repouso na ação primária', () {
      final comAccent = [
        eg.surfaces.row,
        eg.surfaces.sidebarItem,
        eg.surfaces.glassRow,
        eg.surfaces.ghost,
        eg.surfaces.segment,
        eg.surfaces.card,
        eg.surfaces.neutralStrong,
        eg.surfaces.secondary,
        eg.surfaces.destructive,
      ].where((column) => column.rest == eg.colors.accent);

      expect(comAccent, isEmpty);
      expect(eg.surfaces.primary.rest, eg.colors.accent);
    });
  });
}

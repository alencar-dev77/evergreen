import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_gradients.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/leaf_note.dart';

/// Medidas do cartão da parede.
///
/// Vivem aqui, e não em `app_metrics.dart`, porque são geometria deste módulo —
/// como o `_panelWidth` de cada painel do overlay. O que é do design system
/// (espaçamento, raio, cor) continua vindo dos tokens.
abstract final class LeafCardMetrics {
  /// Largura do cartão. Com três colunas e o respiro de [gap], fecha o painel
  /// em 778 (ver `LeafGrid.widthFor`).
  static const width = 236.0;

  /// Altura do cartão.
  ///
  /// É o teto, não uma preferência: três linhas de cartão mais o rodapé de
  /// dicas precisam caber inteiras na janela flutuante, que tem 800px de altura
  /// (ver `OverlayWindow`) e é centralizada na tela. Com 200, a parede cheia
  /// fecha em 706 e ainda sobra a margem da sombra; um cartão mais alto faria a
  /// última linha ser cortada pela borda da janela.
  ///
  /// É o que separa "anotação de reunião" de "recado de post-it": em 236x200
  /// cabem [LeafNote.maxLength] caracteres em nove linhas — quatro vezes a área
  /// do quadrado pequeno com que o módulo nasceu.
  static const height = 200.0;

  static const gap = AppSpacing.lg;

  /// Quantas linhas de texto o cartão mostra.
  static const contentLines = 9;
}

/// Um cartão colado na parede.
///
/// Não é um post-it de papel: sem amarelo, sem sombra e sem inclinação. A
/// sensação de post-it vem do comportamento — efêmero, sempre à vista, jogado
/// fora sem cerimônia —, não da textura. Cor aqui só significa estado
/// (selecionado), como em qualquer outra superfície do Evergreen.
class LeafNoteCard extends StatelessWidget {
  const LeafNoteCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    this.now,
  });

  final LeafNote note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Injetável para o teste não depender do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      // A vaga é o endereço do cartão na parede — é por ela que se fala dele
      // ("o três"), e ela está desenhada como um número solto no rodapé, que
      // lido cru sai como um algarismo sem assunto.
      semanticLabel: 'Vaga ${note.slot}, ${note.content}',
      selected: isSelected ? true : null,
      builder: (context, state) {
        return _LeafCardSurface(
          state: state,
          isSelected: isSelected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Text(
                  note.content,
                  maxLines: LeafCardMetrics.contentLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyCompact,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _footer(state.isHovered),
            ],
          ),
        );
      },
    );
  }

  /// Número da vaga à esquerda, idade à direita — e, com o mouse em cima, a
  /// lixeira no lugar da idade.
  ///
  /// Trocar em vez de somar: a lixeira precisa de um lugar previsível e o
  /// cartão não tem largura para os dois, e sobrepor o texto seria pior. É a
  /// mesma regra das ações que só aparecem no hover da linha, no Pin.
  Widget _footer(bool isHovered) {
    return Row(
      children: [
        Text(
          '${note.slot}',
          style: AppTypography.monoSmall.copyWith(
            color: isSelected ? AppColors.greenLight : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        if (isHovered)
          _DeleteAffordance(onTap: onDelete)
        else
          Text(
            RelativeTime.format(note.createdAt, now: now),
            style: AppTypography.captionXS.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// A vaga livre que convida a próxima anotação.
///
/// Existe por duas razões, e nenhuma delas é decoração: é o alvo de mouse do
/// `⌘+` (nenhuma ação do Evergreen é só de teclado) e é o que explica, sem
/// texto nenhum, que ainda há espaço na parede — quando ele some, a parede está
/// cheia.
class LeafNewNoteCell extends StatelessWidget {
  const LeafNewNoteCell({
    super.key,
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      // Um `+` desenhado não diz nada a quem não vê a tela — e o que ele conta
      // (que ainda cabe anotação na parede) é justamente o que não está
      // escrito em lugar nenhum.
      semanticLabel: 'Vaga livre, escrever anotação',
      selected: isSelected ? true : null,
      builder: (context, state) {
        return _LeafCardSurface(
          state: state,
          isSelected: isSelected,
          isEmpty: true,
          child: Center(
            child: EgIcon(
              EgIconData.plus,
              size: AppIconSizes.lg,
              color: isSelected || state.isHovered
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
            ),
          ),
        );
      },
    );
  }
}

/// A caixa do cartão: tamanho, superfície, borda e estados.
///
/// Compartilhada pelo cartão com anotação, pela vaga vazia e pelo cartão em
/// edição, para que os três tenham exatamente a mesma silhueta — trocar de
/// estado não pode mexer no tamanho de nada.
///
/// Os estados saem da matriz do design system ([EgSurfaceStyle]); o que este
/// módulo acrescenta são duas colunas próprias: a vaga livre, que em repouso é
/// só um contorno, e o cartão em edição, cuja borda accent é o único sinal de
/// que o teclado agora pertence a ele.
class _LeafCardSurface extends StatelessWidget {
  const _LeafCardSurface({
    required this.child,
    required this.isSelected,
    this.state = const EgInteraction(),
    this.isEditing = false,
    this.isEmpty = false,
  });

  final Widget child;
  final bool isSelected;
  final EgInteraction state;
  final bool isEditing;

  /// A vaga livre: em repouso ela é só um contorno, sem superfície própria.
  final bool isEmpty;

  /// A vaga livre. Igual ao cartão, menos a superfície de repouso — o que a
  /// desenha é a borda.
  static const _emptyStyle = EgSurfaceStyle(
    rest: AppColors.transparent,
    hover: AppColors.hover,
    pressed: AppColors.pressed,
    selected: AppColors.selection,
    foreground: AppColors.textPrimary,
    border: AppColors.border,
    selectedBorder: AppColors.greenDeep,
    selectedEdge: AppColors.greenPrimary,
  );

  /// O cartão sendo escrito: borda accent cheia, em vez do [AppColors.greenDeep]
  /// do apenas-selecionado. É um degrau a mais na mesma cor, não uma cor nova.
  static const _editingStyle = EgSurfaceStyle(
    rest: AppColors.card,
    restGradient: AppGradients.cardSurface,
    hover: AppColors.hover,
    pressed: AppColors.pressed,
    selected: AppColors.selection,
    foreground: AppColors.textPrimary,
    border: AppColors.greenPrimary,
    selectedBorder: AppColors.greenPrimary,
    // A aresta acompanha o cartão para dentro da edição: ela é o "aqui está o
    // teclado" de toda superfície selecionada do app, e sumir bem na hora em
    // que o teclado passa a ser mesmo do cartão seria dizer o contrário.
    selectedEdge: AppColors.greenPrimary,
  );

  EgSurfaceStyle get _style {
    if (isEditing) return _editingStyle;
    return isEmpty ? _emptyStyle : EgSurfaceStyle.card;
  }

  @override
  Widget build(BuildContext context) {
    // Seleção vence hover: uma é onde o teclado está, a outra é onde o mouse
    // passou, e quando coincidem a que importa é a do teclado. Quem garante
    // essa ordem é a matriz, não este arquivo.
    return EgSurface(
      state: state,
      style: _style,
      isSelected: isSelected,
      width: LeafCardMetrics.width,
      height: LeafCardMetrics.height,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadii.cardAll,
      child: child,
    );
  }
}

/// A lixeira que aparece no rodapé do cartão sob o mouse.
class _DeleteAffordance extends StatelessWidget {
  const _DeleteAffordance({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      semanticLabel: 'Apagar anotação',
      builder: (context, state) => EgIcon(
        EgIconData.trash,
        size: AppIconSizes.xs,
        // Vermelho já sob o mouse, e não só no clique: é a única ação
        // destrutiva do cartão, e ela precisa se anunciar antes de acontecer.
        color: state.isHovered || state.isPressed
            ? AppColors.error
            : AppColors.textTertiary,
      ),
    );
  }
}

/// O cartão enquanto está sendo escrito.
///
/// É o mesmo cartão, com o texto virando campo no lugar onde ele já estava —
/// nada abre, nada cresce, nada muda de posição. A borda accent é o único sinal
/// de que o teclado agora pertence a este cartão, seguindo o `EgTextField`.
class LeafNoteEditor extends StatelessWidget {
  const LeafNoteEditor({
    super.key,
    required this.slot,
    required this.controller,
    required this.focusNode,
  });

  final int slot;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// A partir de quantos caracteres restantes o contador aparece.
  ///
  /// Só perto do fim: um contador permanente ensinaria a pessoa a escrever
  /// olhando para o número, e o limite existe para caber no cartão, não para
  /// ser administrado.
  static const _counterThreshold = 15;

  @override
  Widget build(BuildContext context) {
    return _LeafCardSurface(
      isSelected: true,
      isEditing: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _field()),
          const SizedBox(height: AppSpacing.sm),
          _footer(),
        ],
      ),
    );
  }

  Widget _field() {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: AppTypography.bodyCompact,
      cursorColor: AppColors.greenPrimary,
      cursorWidth: 1.5,
      maxLines: LeafCardMetrics.contentLines,
      // O campo trata o Enter como quebra de linha, e é assim que o `⇧⏎`
      // funciona. O Enter puro nunca chega aqui: o `Shortcuts` do painel o
      // consome antes, para guardar a anotação (ver `LeafOverlayIntents`).
      textInputAction: TextInputAction.newline,
      inputFormatters: [
        LengthLimitingTextInputFormatter(LeafNote.maxLength),
      ],
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: 'O que não pode escapar',
        hintStyle:
            AppTypography.bodyCompact.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  Widget _footer() {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remaining = LeafNote.maxLength - controller.text.characters.length;

        return Row(
          children: [
            Text(
              '$slot',
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.greenLight,
              ),
            ),
            const Spacer(),
            if (remaining <= _counterThreshold)
              Text(
                '$remaining',
                style: AppTypography.monoSmall.copyWith(
                  color: remaining <= 0
                      ? AppColors.warning
                      : AppColors.textTertiary,
                ),
              ),
          ],
        );
      },
    );
  }
}

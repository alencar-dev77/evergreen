import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_icon.dart';

/// Campo de busca do design system: lupa + input, borda verde quando focado.
///
/// Em [bare] o campo perde fundo e borda próprios, virando apenas a linha de
/// busca do topo do overlay (onde a separação é feita pela borda do painel).
class EgSearchField extends StatelessWidget {
  const EgSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.hintText = 'Pesquisar...',
    this.bare = false,
    this.autofocus = false,
    this.holdsFocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool bare;
  final bool autofocus;

  /// Um clique em outro lugar do painel não tira o cursor daqui.
  ///
  /// Ligado onde o campo é o dono do teclado da tela inteira — o overlay do
  /// Pin. Ali as setas, o Enter, o `⌘P` e o Esc são atalhos do painel, mas só
  /// chegam até ele porque o campo de busca segura o foco: perdido o foco, o
  /// mapa inteiro emudece. O `TextField` no macOS desiste do foco a cada
  /// clique fora dele, e foi isso que deixou o painel sem teclado depois de um
  /// clique na lista.
  final bool holdsFocus;

  @override
  Widget build(BuildContext context) {
    final field = Row(
      children: [
        const EgIcon(EgIconData.search, size: AppIconSizes.md, strokeWidth: 1.5),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            // Sem `onTapOutside` o campo se desfoca sozinho ao primeiro clique
            // em qualquer outro lugar — ver [holdsFocus].
            onTapOutside: holdsFocus ? (_) {} : null,
            cursorColor: AppColors.greenPrimary,
            cursorWidth: 1.5,
            cursorHeight: 16,
            style: AppTypography.body,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hintText,
              // Placeholder é texto de terceiro nível: precisa ser legível sem
              // competir com o que a pessoa digita.
              hintStyle:
                  AppTypography.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ),
      ],
    );

    if (bare) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: field,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: AppColors.greenPrimary),
      ),
      child: field,
    );
  }
}

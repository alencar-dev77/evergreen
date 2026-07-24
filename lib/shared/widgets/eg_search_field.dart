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
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool bare;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final field = Row(
      children: [
        const EgIcon(EgIconData.search, size: 15, strokeWidth: 1.5),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            cursorColor: AppColors.greenPrimary,
            cursorWidth: 1.5,
            cursorHeight: 16,
            style: AppTypography.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hintText,
              hintStyle: AppTypography.body.copyWith(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: AppColors.greenPrimary),
      ),
      child: field,
    );
  }
}

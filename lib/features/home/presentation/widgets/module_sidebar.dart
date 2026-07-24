import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/evergreen_module.dart';

/// Barra lateral do Hub com todos os módulos do Evergreen.
class ModuleSidebar extends StatelessWidget {
  const ModuleSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final EvergreenModule selected;
  final ValueChanged<EvergreenModule> onSelect;

  static const width = 260.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Superfície levemente translúcida: o brilho verde do fundo atravessa de
      // leve no topo, unificando a sidebar com a área de conteúdo sem custo de
      // blur (é só um sólido com alpha sobre o gradiente da janela).
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        border: const Border(right: AppBorders.subtle),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(),
            const EgSectionLabel(
              'Módulos',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.sm,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xxs,
                ),
                children: [
                  for (final module in EvergreenModule.values)
                    _ModuleTile(
                      module: module,
                      isSelected: module == selected,
                      onTap: () => onSelect(module),
                    ),
                ],
              ),
            ),
            _version(),
          ],
        ),
      ),
    );
  }

  Widget _brand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.huge,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          EgIconBadge(
            size: 28,
            color: AppColors.card,
            borderRadius: AppRadii.badgeAll,
            bordered: true,
            child: const EgIcon(
              EgIconData.evergreen,
              size: 16,
              color: AppColors.greenPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Evergreen',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _version() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Text('v0.1.0', style: AppTypography.captionSmall),
    );
  }
}

/// Item da barra lateral. Módulos ainda não lançados aparecem esmaecidos, com
/// a versão prevista no lugar do subtítulo.
class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.isSelected,
    required this.onTap,
  });

  final EvergreenModule module;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      focusable: true,
      builder: (context, state) => AnimatedContainer(
        duration: AppDurations.instant,
        curve: AppDurations.curve,
        margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _background(state),
          borderRadius: AppRadii.listItemAll,
          boxShadow: state.isFocused ? AppShadows.focusRing : null,
        ),
        child: Opacity(
          opacity: module.isAvailable ? 1 : 0.55,
          child: Row(
            children: [
              EgIconBadge(
                size: 28,
                borderRadius: AppRadii.badgeAll,
                color: isSelected ? AppColors.card : AppColors.hover,
                child: EgIcon(
                  module.icon,
                  size: 15,
                  color: isSelected
                      ? AppColors.greenPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: AppTypography.bodyCompactEmphasis.copyWith(
                        color: isSelected
                            ? AppColors.greenLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      module.isAvailable
                          ? module.tagline
                          : 'Previsto para ${module.plannedFor}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionXS,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Selecionado usa accent em baixa opacidade; hover fica no neutro. Antes os
  /// dois estados eram a mesma cor, e o módulo aberto se perdia assim que o
  /// mouse passava por outro.
  Color _background(EgInteraction state) {
    if (isSelected) return AppColors.selection;
    if (state.isPressed) return AppColors.pressed;
    if (state.isHovered || state.isFocused) return AppColors.hover;
    return AppColors.transparent;
  }
}

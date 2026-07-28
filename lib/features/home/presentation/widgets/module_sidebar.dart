import 'package:flutter/widgets.dart';

import '../../../../core/app_info.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../models/evergreen_module.dart';

/// Barra lateral do Hub: o aplicativo no topo e os módulos abaixo.
class ModuleSidebar extends StatelessWidget {
  const ModuleSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  /// Módulo aberto, ou `null` para a tela do próprio aplicativo.
  final EvergreenModule? selected;

  /// Recebe `null` quando a escolha é a tela do aplicativo.
  final ValueChanged<EvergreenModule?> onSelect;

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
            // Os módulos abrem a lista, colados no topo: são eles que a pessoa
            // vem procurar, e qualquer coisa acima empurra o último módulo para
            // o meio da janela. Sem label de grupo por cima deles pelo mesmo
            // motivo — um cabeçalho para o único grupo da lista só ocupa a linha
            // que o terceiro módulo queria.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxs,
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
            // A marca é a própria entrada do aplicativo: ela já leva o nome e o
            // ícone do Evergreen, e um segundo item escrito "Evergreen" seria o
            // mesmo rótulo duas vezes na mesma lista. No rodapé, e não no topo,
            // porque preferência do aplicativo é onde se vai de vez em quando —
            // o macOS põe esse tipo de entrada embaixo (Ajustes do Sistema,
            // Mail, Notas) justamente por isso.
            _AppTile(
              isSelected: selected == null,
              onTap: () => onSelect(null),
            ),
            _version(),
          ],
        ),
      ),
    );
  }

  Widget _version() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xs,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      child: Text(AppInfo.versionLabel, style: AppTypography.captionSmall),
    );
  }
}

/// A marca, que também é o item das preferências do aplicativo.
class _AppTile extends StatelessWidget {
  const _AppTile({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: EgHoverable(
        onTap: onTap,
        focusable: true,
        builder: (context, state) => AnimatedContainer(
          duration: AppDurations.instant,
          curve: AppDurations.curve,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _background(state),
            borderRadius: AppRadii.listItemAll,
            boxShadow: state.isFocused ? AppShadows.focusRing : null,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evergreen',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: isSelected
                            ? AppColors.greenLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Preferências do aplicativo',
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

  Color _background(EgInteraction state) {
    if (isSelected) return AppColors.selection;
    if (state.isPressed) return AppColors.pressed;
    if (state.isHovered || state.isFocused) return AppColors.hover;
    return AppColors.transparent;
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

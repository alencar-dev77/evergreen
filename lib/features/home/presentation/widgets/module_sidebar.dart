import 'package:flutter/widgets.dart';

import '../../../../core/app_info.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_nav_tile.dart';
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
      // Superfície levemente translúcida (`AppColors.sidebar`): o brilho verde
      // do fundo atravessa de leve no topo, unificando a sidebar com a área de
      // conteúdo sem custo de blur.
      decoration: BoxDecoration(
        color: AppColors.sidebar,
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
                    // Módulo ainda não lançado aparece esmaecido, com a versão
                    // prevista no lugar da tagline.
                    EgNavTile(
                      icon: module.icon,
                      title: module.name,
                      subtitle: module.isAvailable
                          ? module.tagline
                          : 'Previsto para ${module.plannedFor}',
                      isSelected: module == selected,
                      isMuted: !module.isAvailable,
                      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: EgNavTile(
                icon: EgIconData.evergreen,
                title: 'Evergreen',
                subtitle: 'Preferências do aplicativo',
                titleStyle: AppTypography.bodyStrong,
                // A marca não muda de cor com a lista: o verde dela é
                // identidade, não estado.
                iconColor: AppColors.greenPrimary,
                iconBackground: AppColors.card,
                iconSize: AppIconSizes.lg,
                borderedIcon: true,
                isSelected: selected == null,
                onTap: () => onSelect(null),
              ),
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

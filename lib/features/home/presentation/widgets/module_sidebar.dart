import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_info.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_nav_tile.dart';
import '../../models/evergreen_module.dart';
import '../viewmodels/module_settings_view_model.dart';
import '../../../../core/design/eg_tokens.dart';

/// Barra lateral do Hub: o aplicativo no topo e os módulos abaixo.
///
/// Módulo desligado **continua na lista**, apagado e com "desligado" no lugar
/// da tagline. É por aqui que se religa: sumir da lista deixaria o interruptor
/// dentro da tela que sumiu, e a única saída seria mexer no plist.
class ModuleSidebar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(moduleSettingsViewModelProvider);

    return DecoratedBox(
      // Superfície levemente translúcida (`context.eg.colors.sidebarTint`): o brilho verde
      // do fundo atravessa de leve no topo, unificando a sidebar com a área de
      // conteúdo sem custo de blur.
      decoration: BoxDecoration(
        color: context.eg.colors.sidebarTint,
        border: Border(right: context.eg.hairline),
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
                    // Esmaecido em dois casos, e o subtítulo diz qual: o módulo
                    // ainda não lançado (com a versão prevista) e o que a
                    // pessoa desligou.
                    EgNavTile(
                      icon: module.icon,
                      title: module.name,
                      subtitle: _subtitleFor(module, settings.isEnabled(module)),
                      isSelected: module == selected,
                      isMuted:
                          !module.isAvailable || !settings.isEnabled(module),
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
                titleStyle: context.eg.text.bodyStrong,
                // A marca não muda de cor com a lista: o verde dela é
                // identidade, não estado.
                iconColor: context.eg.colors.accent,
                iconBackground: context.eg.colors.surface,
                iconSize: AppIconSizes.lg,
                borderedIcon: true,
                isSelected: selected == null,
                onTap: () => onSelect(null),
              ),
            ),
            _version(context),
          ],
        ),
      ),
    );
  }

  static String _subtitleFor(EvergreenModule module, bool isEnabled) {
    if (!module.isAvailable) return 'Previsto para ${module.plannedFor}';
    if (!isEnabled) return 'Desligado';

    return module.tagline;
  }

  Widget _version(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xs,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      child: Text(AppInfo.versionLabel, style: context.eg.text.caption),
    );
  }
}

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_info.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/system/global_shortcut_slot.dart';
import '../../../../shared/widgets/eg_brand_mark.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_nav_tile.dart';
import '../../../../shared/widgets/eg_pill.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/evergreen_module.dart';
import '../../models/module_settings.dart';
import '../viewmodels/updates_view_model.dart';
import '../viewmodels/local_model_view_model.dart';
import '../viewmodels/module_settings_view_model.dart';

/// Um grupo da barra lateral.
///
/// Sete linhas iguais não são uma lista, são um monte. Os grupos dizem por que
/// os módulos convivem: três guardam o que passa pela sua mão, três medem o
/// tempo, um escuta. Quem procura "onde ficam as anotações" varre três nomes,
/// não sete.
enum _SidebarGroup {
  capture('Captura', [
    EvergreenModule.pin,
    EvergreenModule.leaf,
    EvergreenModule.nest,
  ]),
  time('Tempo', [EvergreenModule.focus, EvergreenModule.awake]),
  voice('Voz', [EvergreenModule.echo]),

  /// O Track não é um módulo como os outros: ele não captura nada, não tem
  /// painel e não tem interruptor — ele **lê** o que os seis escreveram. No
  /// meio de "Tempo" ele parecia mais um cronômetro; no pé, em grupo próprio,
  /// fica claro que ele vem depois porque depende de todos.
  report('Relatório', [EvergreenModule.track]);

  const _SidebarGroup(this.label, this.modules);

  final String label;
  final List<EvergreenModule> modules;
}

/// Barra lateral do Hub: a marca no topo, os módulos agrupados, o aplicativo
/// no pé.
///
/// Módulo desligado **continua na lista**, apagado e com a bolinha apagada. É
/// por aqui que se religa: sumir da lista deixaria o interruptor dentro da tela
/// que sumiu, e a única saída seria mexer no plist.
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

  /// 232, e não os 260 de antes: sem a tagline, a linha não precisa daquela
  /// largura, e os 28 pt vão para a área de conteúdo — onde a grade de duas
  /// colunas os usa.
  static const width = 232.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eg = context.eg;
    final settings = ref.watch(moduleSettingsViewModelProvider);

    return DecoratedBox(
      // Chapada, e não vidro: a barra lateral fica na tela o tempo todo, e um
      // `BackdropFilter` permanente recompõe tudo atrás dela a cada quadro. O
      // véu de branco a 2,6% paga o mesmo papel a custo zero.
      decoration: BoxDecoration(
        color: eg.colors.sidebarTint,
        border: Border(right: eg.hairline),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                children: [
                  for (final group in _SidebarGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: EgSectionLabel(group.label),
                    ),
                    for (final module in group.modules)
                      _tile(context, ref, module, settings),
                  ],
                ],
              ),
            ),
            _footer(
              context,
              settings,
              ref.watch(localModelViewModelProvider),
              ref.watch(
                updatesViewModelProvider.select(
                  (updates) => updates.value?.hasUpdate == true
                      ? updates.value!.version
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A linha da marca. Não é um item: não se clica nela, não se seleciona.
  ///
  /// Ela é a etiqueta da janela — e é sob ela que moram os controles do macOS,
  /// que é o motivo de o topo ficar livre de qualquer coisa clicável.
  Widget _brand(BuildContext context) {
    final eg = context.eg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.giant,
        AppSpacing.xl,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          const EgBrandMark(size: AppIconSizes.xl),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('Evergreen', style: eg.text.bodyStrong)),
          Text(
            AppInfo.versionLabel,
            style: eg.text.monoSmall.copyWith(color: eg.colors.textQuaternary),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    EvergreenModule module,
    ModuleSettings settings,
  ) {
    final eg = context.eg;
    final isEnabled = settings.isEnabled(module);
    final slot = module.shortcutSlot;

    return EgNavTile(
      icon: module.icon,
      title: module.name,
      // O módulo sem atalho não tem tecla para mostrar, e deixar a coluna
      // vazia faria parecer que ela sumiu no meio da lista. Ele diz o que é.
      shortcut: slot == null ? 'só leitura' : settings.bindingFor(slot).compact,
      statusColor: slot == null
          ? null
          : (isEnabled ? eg.colors.accent : eg.colors.textQuaternary),
      isSelected: module == selected,
      isMuted: !module.isAvailable || !isEnabled,
      margin: const EdgeInsets.only(bottom: AppSpacing.xxxs),
      onTap: () => onSelect(module),
    );
  }

  /// O pé: a tela do aplicativo e a promessa da casa.
  ///
  /// Embaixo, e não no topo, porque preferência do aplicativo é onde se vai de
  /// vez em quando — o macOS põe esse tipo de entrada no pé (Ajustes do
  /// Sistema, Mail, Notas) justamente por isso.
  Widget _footer(
    BuildContext context,
    ModuleSettings settings,
    LocalModelStatus localModel,
    String? updateVersion,
  ) {
    final eg = context.eg;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(border: Border(top: eg.hairline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EgNavTile(
            icon: EgIconData.evergreen,
            title: 'Aplicativo',
            shortcut: settings.bindingFor(GlobalShortcutSlot.hub).compact,
            isSelected: selected == null,
            // A versão nova mora na tela do aplicativo: a bolinha fica no
            // botão que leva até ela.
            notice: updateVersion == null
                ? null
                : 'versão $updateVersion disponível',
            onTap: () => onSelect(null),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    // A mesma promessa do rodapé da tela do aplicativo, curta:
                    // o que é seu fica, e não "nada sai" — ver a PRIVACY.md.
                    'seus dados ficam aqui',
                    style: eg.text.monoSmall.copyWith(
                      color: eg.colors.textQuaternary,
                    ),
                  ),
                ),
                if (localModel.server != LmStudioServerState.idle)
                  _LocalModelDot(status: localModel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// O modelo do LM Studio está na memória agora?
///
/// Verde quando está, apagada quando não: é o que responde "ele saiu da
/// memória depois do resumo?" sem abrir o LM Studio. Só existe com o LM Studio
/// escolhido, e o nome de quem está carregado vem no tooltip — a bolinha diz
/// que há um modelo, o tooltip diz qual.
class _LocalModelDot extends StatelessWidget {
  const _LocalModelDot({required this.status});

  final LocalModelStatus status;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final loaded = status.loaded;
    final message = loaded.isEmpty
        ? 'Nenhum modelo na memória do LM Studio'
        : '${loaded.map((model) => model.displayName).join(', ')} na memória '
              'do LM Studio';

    // O mesmo balão do `EgIconButton`, para não haver dois tooltips no app.
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: eg.colors.surface,
        borderRadius: eg.shapes.segmentAll,
        border: eg.borderAll,
        boxShadow: eg.elevations.dropdown,
      ),
      textStyle: eg.text.footnote,
      child: Semantics(
        label: message,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: EgStatusDot(
            color: loaded.isEmpty ? eg.colors.textQuaternary : eg.colors.accent,
            size: 6,
          ),
        ),
      ),
    );
  }
}

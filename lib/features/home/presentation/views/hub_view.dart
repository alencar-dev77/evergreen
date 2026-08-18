import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../awake/presentation/views/awake_settings_view.dart';
import '../../../echo/presentation/views/echo_settings_view.dart';
import '../../../focus/presentation/views/focus_settings_view.dart';
import '../../../leaf/presentation/views/leaf_settings_view.dart';
import '../../../pin/presentation/views/pin_settings_view.dart';
import '../../models/evergreen_module.dart';
import '../widgets/module_placeholder.dart';
import '../widgets/module_sidebar.dart';
import 'app_settings_view.dart';

/// Painel principal do Evergreen.
///
/// Lista os módulos da suíte à esquerda e mostra as configurações do módulo
/// selecionado à direita. É uma janela independente do overlay do Pin: fechar
/// uma não afeta a outra.
class HubView extends StatefulWidget {
  const HubView({super.key});

  @override
  State<HubView> createState() => _HubViewState();
}

class _HubViewState extends State<HubView> {
  /// Módulo aberto, ou `null` para a tela do próprio aplicativo.
  EvergreenModule? _selected = EvergreenModule.pin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: EgBackground(
        child: Row(
          // Estica: a área de detalhe rola, e um `SingleChildScrollView` se
          // encolhe até a altura do conteúdo quando ele cabe na tela. Com o
          // alinhamento padrão do `Row` (center), a tela de um módulo curto —
          // o Awake — nascia centralizada verticalmente, enquanto Pin e Focus,
          // que enchem a janela, começavam no topo. Toda tela do Hub começa no
          // mesmo lugar.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModuleSidebar(
              selected: _selected,
              onSelect: (module) => setState(() => _selected = module),
            ),
            Expanded(child: _detail()),
          ],
        ),
      ),
    );
  }

  Widget _detail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.huge,
        AppSpacing.huge,
        AppSpacing.huge,
        AppSpacing.giant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.xxxl),
          _content(),
        ],
      ),
    );
  }

  /// Cabeçalho de painel, não hero: título no maior estilo do app (17px) com a
  /// tagline logo abaixo, colada nele — os dois são um bloco só.
  Widget _header() {
    final module = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          module?.name ?? 'Evergreen',
          style: AppTypography.screenTitle,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          module?.tagline ?? 'Preferências do aplicativo',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _content() {
    final module = _selected;
    if (module == null) return const AppSettingsView();

    return module.isAvailable
        ? _settingsFor(module)
        : ModulePlaceholder(module: module);
  }

  Widget _settingsFor(EvergreenModule module) => switch (module) {
        EvergreenModule.pin => const PinSettingsView(),
        EvergreenModule.focus => const FocusSettingsView(),
        EvergreenModule.leaf => const LeafSettingsView(),
        EvergreenModule.awake => const AwakeSettingsView(),
        EvergreenModule.echo => const EchoSettingsView(),
      };
}

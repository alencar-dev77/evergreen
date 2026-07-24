import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../pin/presentation/views/pin_settings_view.dart';
import '../../models/evergreen_module.dart';
import '../widgets/module_placeholder.dart';
import '../widgets/module_sidebar.dart';

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
  EvergreenModule _selected = EvergreenModule.pin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: EgBackground(
        child: Row(
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
          if (_selected.isAvailable)
            _settingsFor(_selected)
          else
            ModulePlaceholder(module: _selected),
        ],
      ),
    );
  }

  /// Cabeçalho de painel, não hero: título no maior estilo do app (17px) com a
  /// tagline logo abaixo, colada nele — os dois são um bloco só.
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_selected.name, style: AppTypography.screenTitle),
        const SizedBox(height: AppSpacing.xxs),
        Text(_selected.tagline, style: AppTypography.caption),
      ],
    );
  }

  Widget _settingsFor(EvergreenModule module) => switch (module) {
        EvergreenModule.pin => const PinSettingsView(),
        _ => ModulePlaceholder(module: module),
      };
}

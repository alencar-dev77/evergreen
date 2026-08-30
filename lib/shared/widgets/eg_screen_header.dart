import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_pill.dart';
import 'eg_surface.dart';
import 'eg_toggle.dart';

/// O cabeçalho de uma tela do Hub.
///
/// É o ponto de entrada que não existia: o maior texto do app tinha 17 pt, e
/// toda tela começava com o mesmo peso do que vinha depois dela — nada segurava
/// o olho. Aqui o nome do módulo vem em `display`, e é **um por tela**.
///
/// O interruptor mestre saiu da lista de seções e virou pílula daqui. Ele é
/// igual nos sete módulos e não é um ajuste como os outros: é a chave que
/// decide se os outros valem alguma coisa. Como primeira seção, ele empurrava
/// o assunto da tela para baixo da dobra em todas elas.
class EgScreenHeader extends StatelessWidget {
  const EgScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.isEnabled,
    this.onEnabledChanged,
    this.badge,
    this.shortcut,
    this.onShortcutTap,
    this.tabs,
    this.selectedTab,
    this.onTabSelected,
    this.tabCountOf,
    this.trailing,
  }) : assert(
         badge == null || isEnabled == null,
         'Uma coisa só à direita do título: ou o interruptor, ou a pílula.',
       );

  final String title;

  /// A linha sob o título. `Widget`, e não texto, porque nos mockups ela mistura
  /// pesos — "Histórico da área de transferência. **1.842 itens** guardados" —
  /// e é o número em negrito que a faz informar em vez de repetir a barra
  /// lateral. O estilo base já vem aplicado; quem chama só destaca o que
  /// importa.
  final Widget? subtitle;

  /// O estado do interruptor mestre. `null` num módulo que não liga e desliga
  /// — o Track, que se apaga quando os módulos que o alimentam se apagam.
  final bool? isEnabled;
  final ValueChanged<bool>? onEnabledChanged;

  /// Uma pílula no lugar do interruptor: o "nada é gravado aqui" do Track, o
  /// "Rodando" do Focus.
  final Widget? badge;

  /// As teclas do atalho global, impressas ao lado do interruptor.
  ///
  /// Clicáveis: é o caminho mais curto entre ver o atalho e trocá-lo, e poupa
  /// a tela de ter uma seção "Atalho global" que existe para uma linha só.
  final List<String>? shortcut;
  final VoidCallback? onShortcutTap;

  /// As abas de tela. Só em módulo com mais de um assunto — Pin e Echo. Módulo
  /// simples não tem aba: uma aba sozinha é uma promessa de que há outra.
  final List<String>? tabs;
  final String? selectedTab;
  final ValueChanged<String>? onTabSelected;
  final String? Function(String)? tabCountOf;

  /// O campo de busca de ajuste, à direita da fileira de abas.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final hasTabs = tabs != null && tabs!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.huge - AppSpacing.xxs,
        AppSpacing.xxxl + AppSpacing.xxs,
        AppSpacing.huge - AppSpacing.xxs,
        AppSpacing.xl + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(border: Border(bottom: eg.hairline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Altura fixa, e é o que faz toda tela do Hub começar na mesma
          // linha: a pílula do Track é mais baixa que o interruptor dos outros
          // seis, e sem um piso comum o conteúdo do Track subiria um pixel em
          // relação ao de todos os vizinhos.
          SizedBox(
            height: _controlsHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: eg.text.display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Encolhe antes de estourar: numa janela estreita a pílula do
                // Track e o título disputam a mesma linha, e quem cede é o
                // acessório, não o nome da tela.
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _trailingControls(context),
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DefaultTextStyle(
              style: eg.text.body.copyWith(color: eg.colors.textSecondary),
              child: subtitle!,
            ),
          ],
          if (hasTabs || trailing != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (hasTabs)
                  Expanded(
                    child: EgFilterPills<String>(
                      values: tabs!,
                      selected: selectedTab ?? tabs!.first,
                      labelOf: (tab) => tab,
                      countOf: tabCountOf,
                      onSelected: onTabSelected ?? (_) {},
                      height: _tabHeight,
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// A ordem de quem cede: primeiro o rótulo do interruptor, depois a pílula.
  /// A tecla nunca encolhe — ela já é o menor elemento da linha, e truncada
  /// deixaria de ser uma tecla.
  List<Widget> _trailingControls(BuildContext context) {
    return [
      if (badge != null) Flexible(child: badge!),
      if (isEnabled != null)
        Flexible(
          child: EgMasterSwitch(value: isEnabled!, onChanged: onEnabledChanged),
        ),
      if (shortcut != null) ...[
        const SizedBox(width: AppSpacing.sm),
        _ShortcutButton(keys: shortcut!, onTap: onShortcutTap),
      ],
    ];
  }

  static const _tabHeight = 28.0;

  /// A altura do interruptor mestre — o mais alto dos controles do topo.
  static const _controlsHeight = 32.0;
}

/// O interruptor mestre de um módulo, como pílula.
///
/// Interruptor mais rótulo, e não um interruptor sozinho: no cabeçalho, longe
/// de qualquer linha que o nomeie, um interruptor solto não diz o que liga.
class EgMasterSwitch extends StatelessWidget {
  const EgMasterSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final color = value ? eg.colors.accent : eg.colors.textTertiary;

    return Semantics(
      label: 'Usar este módulo',
      toggled: value,
      child: Container(
        height: _height,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: eg.shapes.chipAll,
          border: Border.all(
            color: color.withValues(alpha: 0.30),
            width: eg.shapes.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EgToggle(value: value, onChanged: onChanged),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value ? 'Ativo' : 'Desligado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: eg.text.footnote.copyWith(
                  color: value ? eg.colors.accentLight : eg.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
        ),
      ),
    );
  }

  static const _height = 32.0;
}

/// O atalho do módulo no cabeçalho: as teclas, clicáveis.
class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({required this.keys, this.onTap});

  final List<String> keys;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgInteractiveSurface(
      onTap: onTap,
      style: eg.surfaces.secondary,
      borderRadius: eg.shapes.controlAll,
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH),
      semanticLabel: 'Atalho ${keys.join(' ')}. Clique para alterar.',
      child: Text(
        keys.join(),
        style: eg.text.keycap.copyWith(color: eg.colors.textSecondary),
      ),
    );
  }

  static const _height = 32.0;
}

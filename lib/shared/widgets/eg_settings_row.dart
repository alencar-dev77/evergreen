import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_toggle.dart';

/// Linha de configuração: label à esquerda, controle à direita.
///
/// Compartilhada por todas as telas de configuração dos módulos, para que Pin,
/// Focus e Shelf tenham exatamente a mesma densidade e alinhamento.
class EgSettingsRow extends StatelessWidget {
  const EgSettingsRow({
    super.key,
    required this.label,
    required this.trailing,
    this.description,
    this.showDivider = true,
  });

  /// Atalho para a linha mais comum: label + toggle.
  EgSettingsRow.toggle({
    super.key,
    required this.label,
    required bool value,
    ValueChanged<bool>? onChanged,
    this.description,
    this.showDivider = true,
  }) : trailing = EgToggle(value: value, onChanged: onChanged);

  final String label;
  final Widget trailing;
  final String? description;
  final bool showDivider;

  /// Largura abaixo da qual o controle desce para baixo do rótulo.
  ///
  /// O controle mais largo do aplicativo — o seletor de cinco durações do Focus
  /// — pede uns 460px, e numa janela estreita ele sozinho já não deixa espaço
  /// para o rótulo: a linha estourava com uma faixa listrada atravessando a
  /// tela. Descer o controle é o que a tela do Echo já fazia à mão com o campo
  /// de instrução do resumo ("um seletor cabe ao lado do rótulo, um texto de
  /// três linhas não"); aqui a regra passa a valer para qualquer linha, sem
  /// ninguém precisar lembrar dela.
  static const _stackBelow = 520.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: showDivider ? AppBorders.bottom : null,
        ),
        // O rótulo é o nome do controle, e os dois só significam alguma coisa
        // juntos: fundidos, o leitor de tela anuncia "Iniciar com o macOS,
        // ativado" numa parada só. Separados, ele lê um texto solto e, depois,
        // um interruptor sem nome — que é o mesmo que não anunciar.
        child: MergeSemantics(
          child: constraints.maxWidth < _stackBelow ? _stacked() : _inline(),
        ),
      ),
    );
  }

  Widget _inline() {
    return Row(
      children: [
        Expanded(child: _label()),
        const SizedBox(width: AppSpacing.xl),
        trailing,
      ],
    );
  }

  Widget _stacked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(),
        const SizedBox(height: AppSpacing.md),
        // Alinhado à esquerda, sob o rótulo que ele responde — e não centrado
        // nem à direita, que seria o controle procurando um lugar em vez de
        // pertencer a um.
        Align(alignment: Alignment.centerLeft, child: trailing),
      ],
    );
  }

  Widget _label() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyCompactEmphasis),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(description!, style: AppTypography.captionSmall),
        ],
      ],
    );
  }
}

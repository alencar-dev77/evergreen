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
  }) : _alwaysStacked = false,
       _stretchTrailing = false;

  /// Atalho para a linha mais comum: label + toggle.
  EgSettingsRow.toggle({
    super.key,
    required this.label,
    required bool value,
    ValueChanged<bool>? onChanged,
    this.description,
    this.showDivider = true,
  }) : trailing = EgToggle(value: value, onChanged: onChanged),
       _alwaysStacked = false,
       _stretchTrailing = false;

  /// A linha cuja resposta é um texto que a pessoa escreve.
  ///
  /// O campo desce para baixo do rótulo e ocupa a largura toda, em vez de ir
  /// para a coluna da direita onde moram os outros controles. Quem decide é o
  /// tamanho da resposta: um seletor cabe ao lado do rótulo, um texto de três
  /// linhas não — espremido em 260px ele mostraria meia frase por vez e faria
  /// escrever numa fresta.
  ///
  /// Era feito à mão no Echo, com um `SizedBox.shrink()` no lugar do controle e
  /// o campo logo abaixo, fora da linha: o rótulo e o campo eram dois widgets
  /// que por acaso estavam perto: perto até alguém mexer no espaçamento.
  const EgSettingsRow.field({
    super.key,
    required this.label,
    required Widget field,
    this.description,
    this.showDivider = true,
  }) : trailing = field,
       _alwaysStacked = true,
       _stretchTrailing = true;

  final String label;
  final Widget trailing;
  final String? description;
  final bool showDivider;

  /// O controle desce para baixo do rótulo mesmo numa janela larga.
  final bool _alwaysStacked;

  /// E, descendo, ocupa a linha inteira — o que vale para um campo de texto e
  /// não vale para um seletor, que tem a largura das opções dele.
  final bool _stretchTrailing;

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
          child: _alwaysStacked || constraints.maxWidth < _stackBelow
              ? _stacked()
              : _inline(),
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
      crossAxisAlignment: _stretchTrailing
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        _label(),
        const SizedBox(height: AppSpacing.md),
        // Alinhado à esquerda, sob o rótulo que ele responde — e não centrado
        // nem à direita, que seria o controle procurando um lugar em vez de
        // pertencer a um.
        if (_stretchTrailing)
          trailing
        else
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

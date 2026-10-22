import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_pill.dart';
import 'eg_surface.dart';

/// Uma pílula que liga e desliga alguma coisa, com contagem à direita.
///
/// **É um interruptor com nome, não um filtro.** Parece o [EgFilterPills], e a
/// diferença é a que importa: ali só uma opção vale por vez e a escolha muda o
/// que se vê; aqui cada pílula responde por si e a escolha muda o que o app
/// faz. Por isso a ligada usa o accent — verde quer dizer ligado — enquanto a
/// escolhida de um filtro usa só elevação.
///
/// A contagem à direita é o que evita a pergunta seguinte: desligar um tipo
/// sem saber quantos itens dele existem é decidir no escuro.
class EgTogglePill extends StatelessWidget {
  const EgTogglePill({
    super.key,
    required this.label,
    required this.isOn,
    required this.onChanged,
    this.count,
  });

  final String label;
  final bool isOn;
  final ValueChanged<bool> onChanged;

  /// Quantos existem hoje. `null` some com o número; zero mostra um travessão,
  /// porque "0" e "nenhum ainda" se leem diferente.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgInteractiveSurface(
      onTap: () => onChanged(!isOn),
      style: _style(eg),
      isSelected: isOn,
      borderRadius: eg.shapes.controlAll,
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH),
      semanticLabel: 'Guardar $label',
      builder: (context, state) => Row(
        children: [
          EgStatusDot(
            color: isOn ? eg.colors.accent : eg.colors.textQuaternary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (isOn ? eg.text.bodyEmphasis : eg.text.body).copyWith(
                color: isOn ? eg.colors.textPrimary : eg.colors.textTertiary,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              count == 0 ? '—' : _compact(count!),
              style: eg.text.monoSmall.copyWith(
                color: isOn
                    ? eg.colors.textSecondary
                    : eg.colors.textQuaternary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Ligada é accent de baixa opacidade com a borda na mesma cor — o mesmo
  /// tratamento da pílula do interruptor mestre, porque é a mesma pergunta.
  EgSurfaceStyle _style(EgTokens eg) => EgSurfaceStyle(
    rest: eg.colors.surfaceTop,
    hover: eg.colors.raised,
    pressed: eg.colors.control,
    selected: eg.colors.accent.withValues(alpha: 0.10),
    foreground: eg.colors.textTertiary,
    selectedForeground: eg.colors.textPrimary,
    border: eg.colors.edge,
    selectedBorder: eg.colors.accent.withValues(alpha: 0.22),
  );

  /// `1.4k` em vez de `1423`: numa pílula de 30 pt o número exato rouba a
  /// largura do nome, e quem está decidindo se guarda links não precisa do
  /// dígito das unidades.
  static String _compact(int value) {
    if (value < 1000) return '$value';

    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}k';
  }

  static const _height = 30.0;
}

/// A grade de [EgTogglePill] em duas colunas.
///
/// Duas, e não uma fila que quebra: em fila, pílulas de larguras diferentes
/// deixam um dente irregular na direita, e a contagem — que é o que se compara
/// entre tipos — para de alinhar de uma linha para a outra.
class EgTogglePillGrid extends StatelessWidget {
  const EgTogglePillGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < (children.length + 1) ~/ 2; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: children[row * 2]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: row * 2 + 1 < children.length
                    ? children[row * 2 + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

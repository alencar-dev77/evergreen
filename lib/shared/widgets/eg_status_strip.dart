import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_pill.dart';
import 'eg_surface.dart';

/// A faixa de estado: o que o Hub mostra de um módulo que está trabalhando.
///
/// **É o que substitui a duplicidade.** A lei do redesenho diz que o painel
/// flutuante é onde se opera e o Hub é onde se configura e se lê; sem uma
/// forma de dizer "há uma sessão rodando", a única saída seria repetir o
/// cronômetro e os botões do painel dentro do Hub — e aí passam a existir dois
/// lugares para a mesma ação, que discordam no dia em que um deles mudar.
///
/// Então a faixa informa e não opera: bolinha, texto e valor em mono. **Não há
/// botão nenhum aqui.** Clicar em qualquer ponto dela abre o painel, que é o
/// único lugar onde se pausa e se encerra.
///
/// A tecla do módulo ficava à direita e saiu: a barra lateral já a diz, a
/// seção "Atalho global" já a troca, e no alto da tela do Leaf ela era a
/// terceira impressão da mesma combinação numa janela só.
class EgStatusStrip extends StatelessWidget {
  const EgStatusStrip({
    super.key,
    required this.label,
    this.detail,
    this.value,
    this.tone = EgPillTone.positive,
    this.onTap,
  });

  /// O que está acontecendo: "Sessão rodando", "Tela acesa", "Desligado".
  final String label;

  /// O complemento em texto corrente — o que está sendo feito, quando termina.
  final String? detail;

  /// O número: o tempo que falta, quantos espaços em uso. Em mono e tabular,
  /// para não dançar de largura enquanto corre.
  final String? value;

  final EgPillTone tone;

  /// Abrir o painel. `null` deixa a faixa como leitura pura — é o caso do
  /// módulo desligado, em que não há painel para abrir.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgInteractiveSurface(
      onTap: onTap,
      style: _style(eg),
      borderRadius: eg.shapes.rowAll,
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH),
      semanticLabel: [
        label,
        if (detail != null) detail,
        if (value != null) value,
      ].join(' · '),
      child: Row(
        children: [
          EgStatusDot(color: tone.colorOf(eg)),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: eg.text.bodyEmphasis),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(value!, style: eg.text.mono.copyWith(color: tone.labelOf(eg))),
          ],
          if (detail != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                detail!,
                style: eg.text.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// A faixa nasce elevada, e não em repouso transparente: ela não é uma linha
  /// de lista que às vezes está selecionada — é sempre a superfície de cima.
  EgSurfaceStyle _style(EgTokens eg) => EgSurfaceStyle(
    rest: eg.colors.raised,
    hover: eg.colors.control,
    pressed: eg.colors.pressed,
    foreground: eg.colors.textPrimary,
    innerHairline: eg.elevations.rowInnerHairline,
    hairlineAlways: true,
  );

  static const _height = 34.0;
}

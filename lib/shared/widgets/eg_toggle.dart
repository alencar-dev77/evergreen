import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_hoverable.dart';
import '../../core/design/eg_tokens.dart';

/// Switch pill do design system — trilho 36x21, bolinha 15px.
///
/// É a única exceção deliberada à regra de "accent em baixa opacidade, nunca
/// preenchimento sólido": switch de macOS é verde chapado, e o usuário lê o
/// estado ligado/desligado por essa convenção antes de ler qualquer outra
/// pista. Registrada em `colors.md`.
///
/// Por isso ele também não usa a `EgSurfaceStyle` compartilhada: a matriz dele
/// tem duas colunas (ligado e desligado) em vez de uma, e cada estado de
/// interação existe nas duas. A tabela completa:
///
/// | Interação | Trilho ligado | Trilho desligado |
/// |---|---|---|
/// | repouso | `greenPrimary` | `border` |
/// | hover · foco | `greenLight` | `hover` |
/// | pressed | `greenDeep` | `pressed` |
/// | disabled | repouso a [AppOpacities.disabled] | repouso a [AppOpacities.disabled] |
///
/// Quem carrega os estados é o **trilho**; a bolinha só diz de que lado está
/// (escura sobre o verde, `textSecondary` sobre o cinza). Fazê-la clarear
/// junto no hover foi tentado e descartado: uma bolinha branca acesa ao passar
/// o mouse grita mais que o próprio estado ligado, e é a redundância de
/// affordance que `anti-patterns.md` proíbe.
///
/// O `pressed` faltava até a componentização do design system: o switch era o
/// único controle do app que não dava sinal nenhum entre o dedo descer e a
/// preferência virar. Nas duas colunas ele é um degrau **na direção contrária**
/// ao hover — escurece o verde, clareia o cinza —, que é como um controle
/// nativo diz "estou sendo apertado" sem antecipar para qual lado vai.
///
/// O foco compartilha a superfície do hover: quem o distingue é o anel
/// ([context.eg.elevations.focusRing]), que só o teclado acende.
class EgToggle extends StatelessWidget {
  const EgToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _trackWidth = 36.0;
  static const _trackHeight = 21.0;
  static const _thumbSize = 15.0;
  static const _thumbInset = 3.0;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return EgHoverable(
      // Interruptor, não botão: o que precisa ser lido é o estado. Quem dá o
      // nome é a linha em volta (`EgSettingsRow`), que tem o rótulo na tela.
      toggled: value,
      enabled: isEnabled,
      focusable: true,
      onTap: isEnabled ? () => onChanged!(!value) : null,
      builder: (context, state) => Opacity(
        opacity: isEnabled ? 1 : AppOpacities.disabled,
        child: AnimatedContainer(
          // Como em qualquer outro controle do app, o pressed entra sem
          // transição e a volta ao repouso é que ganha o easing.
          duration: state.isPressed && isEnabled
              ? Duration.zero
              : AppDurations.instant,
          curve: AppDurations.curve,
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: _trackColor(
              context,
              isEnabled ? state : const EgInteraction(),
            ),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            boxShadow: state.isFocused && isEnabled
                ? context.eg.elevations.focusRing
                : null,
          ),
          child: AnimatedAlign(
            duration: AppDurations.instant,
            curve: AppDurations.curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _thumbInset),
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: value
                      ? context.eg.colors.canvas
                      : context.eg.colors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _trackColor(BuildContext context, EgInteraction state) {
    if (value) {
      if (state.isPressed) return context.eg.colors.accentDeep;
      return state.isHovered || state.isFocused
          ? context.eg.colors.accentLight
          : context.eg.colors.accent;
    }

    if (state.isPressed) return context.eg.colors.pressed;
    return state.isHovered || state.isFocused
        ? context.eg.colors.hover
        : context.eg.colors.line;
  }
}

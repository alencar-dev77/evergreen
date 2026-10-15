import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/nest_transfer_mode.dart';
import '../viewmodels/nest_state.dart';
import 'nest_stack_header.dart';

/// A prateleira do Nest no formato do notch: a pilha, e para onde ela vai.
///
/// É o que sai do recorte — pelo arquivo levado até lá, pelo mouse em cima da
/// ilha, ou pelo `⌘⇧R` com arquivos esperando. A prateleira completa (escolher
/// um a um, tirar, desfazer) continua a um clique, em "Abrir prateleira"; aqui
/// fica só o que se faz de passagem: **mandar tudo para uma pasta, ou arrastar
/// a pilha para fora.** Um notch que só mostrasse a pilha e um botão para a
/// prateleira seria uma sala de espera.
///
/// Preta, da cor do recorte, encostada no topo da tela e com os ombros
/// côncavos da ilha: é o recorte que cresceu, e não um painel que pousou
/// embaixo dele.
class NestNotchPile extends StatelessWidget {
  const NestNotchPile({
    super.key,
    required this.state,
    required this.notch,
    required this.onSend,
    required this.onDragOut,
    required this.onOpenShelf,
  });

  final NestState state;

  /// O tamanho do recorte: a faixa de cima fica vazia, porque ali é o furo.
  final Size notch;

  final ValueChanged<int> onSend;
  final VoidCallback onDragOut;
  final VoidCallback onOpenShelf;

  /// A largura da pilha: cabe o cabeçalho e as quatro pastas numa linha só,
  /// com nomes de tamanho comum. Nomes longos quebram para uma segunda.
  static const width = 480.0;

  /// Quantas pastas cabem na pilha. As outras continuam no `⌘5..⌘9` e na
  /// prateleira completa.
  static const maxDestinations = 4;

  /// O raio dos ombros — o mesmo da ilha (`NotchIslandView.shoulder`).
  static const _shoulder = 6.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return CustomPaint(
      painter: _NotchShapePainter(
        color: eg.colors.notch,
        radius: eg.shapes.radiusPanel,
        shoulder: _shoulder,
      ),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            notch.height + AppSpacing.xs,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: AnimatedSize(
            duration: AppDurations.medium,
            curve: eg.motion.curve,
            alignment: Alignment.topCenter,
            child: state.isEmpty ? _empty(context) : _pile(context),
          ),
        ),
      ),
    );
  }

  /// Vazia: o convite enquanto o arquivo vem chegando, ou o que acabou de
  /// acontecer depois de um envio.
  Widget _empty(BuildContext context) {
    final eg = context.eg;
    final notice = state.notice;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EgIcon(
          EgIconData.tray,
          size: AppIconSizes.lg,
          // Aceso quando o arquivo está por cima: é a única resposta que a
          // pilha dá antes de o botão do mouse subir.
          color: state.isDragOver ? eg.colors.accent : eg.colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            notice ?? 'Solte aqui',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: state.isDragOver && notice == null
                ? eg.text.bodyEmphasis
                : eg.text.body.copyWith(color: eg.colors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _pile(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Puxar a pilha leva tudo, como na prateleira: o gesto é o mesmo
            // com que os arquivos chegaram.
            Expanded(
              child: GestureDetector(
                onPanStart: (_) => onDragOut(),
                child: NestStackHeader(items: state.items, selected: 0),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            EgButton.secondary(
              label: 'Abrir prateleira',
              compact: true,
              onPressed: onOpenShelf,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _destinations(context),
      ],
    );
  }

  Widget _destinations(BuildContext context) {
    final eg = context.eg;

    if (!state.hasDestinations) {
      return Text(
        'Arraste a pilha para onde quiser, ou cadastre pastas nas '
        'preferências do Nest.',
        style: eg.text.caption,
      );
    }

    final shown = state.destinations.length > maxDestinations
        ? maxDestinations
        : state.destinations.length;
    final hidden = state.destinations.length - shown;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EgSectionLabel(
          state.effectiveMode == NestTransferMode.move
              ? 'Mover para'
              : 'Copiar para',
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var index = 0; index < shown; index++)
              EgButton.secondary(
                label: state.destinations[index].label,
                keycap: '⌘${index + 1}',
                compact: true,
                onPressed: state.destinations[index].isMissing
                    ? null
                    : () => onSend(index),
              ),
          ],
        ),
        if (hidden > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            hidden == 1
                ? 'Mais 1 pasta na prateleira.'
                : 'Mais $hidden pastas na prateleira.',
            style: eg.text.footnote.copyWith(color: eg.colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// O recorte crescido: retângulo com os cantos de baixo arredondados, encostado
/// no topo, e os dois ombros côncavos por fora — a borda da tela entrando na
/// pilha por uma curva, como entra no recorte.
class _NotchShapePainter extends CustomPainter {
  const _NotchShapePainter({
    required this.color,
    required this.radius,
    required this.shoulder,
  });

  final Color color;
  final double radius;
  final double shoulder;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final corner = Radius.circular(radius);

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        0,
        0,
        size.width,
        size.height,
        bottomLeft: corner,
        bottomRight: corner,
      ),
      paint,
    );

    // Cada ombro é o quadrado menos o quarto de círculo voltado para fora.
    final left = Path()
      ..moveTo(-shoulder, 0)
      ..lineTo(0, 0)
      ..lineTo(0, shoulder)
      // Côncavo: o círculo tem o centro fora da pilha, em (-shoulder,
      // shoulder), e o arco curva para dentro do canto.
      ..arcToPoint(
        Offset(-shoulder, 0),
        radius: Radius.circular(shoulder),
        clockwise: false,
      )
      ..close();
    final right = Path()
      ..moveTo(size.width + shoulder, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, shoulder)
      ..arcToPoint(
        Offset(size.width + shoulder, 0),
        radius: Radius.circular(shoulder),
      )
      ..close();

    canvas
      ..drawPath(left, paint)
      ..drawPath(right, paint);
  }

  @override
  bool shouldRepaint(_NotchShapePainter old) =>
      old.color != color || old.radius != radius || old.shoulder != shoulder;
}

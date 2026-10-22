import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_icon.dart';
import 'eg_pill.dart';
import 'eg_surface.dart';

/// Item da barra lateral do Hub: glifo, nome, tecla e bolinha de estado.
///
/// **A tagline saiu.** Ela repetia na lista o que o cabeçalho da tela já diz em
/// letra grande, e cobrava por isso 22 pt de altura em cada um dos sete
/// módulos — a lista inteira ocupava a janela sem que a barra lateral dissesse
/// nada além dos nomes. Sem ela a linha cabe em 34, e sobra espaço para o que
/// a lista tem de próprio: os grupos.
///
/// No lugar da tagline entrou a **tecla**, sempre visível. Num app em que tudo
/// se abre por atalho, a barra lateral é o mapa do teclado — e o mapa não pode
/// depender de a pessoa abrir cada tela para descobrir a tecla dela.
///
/// Selecionado é a superfície `raised` com a linha de luz no topo, mais o peso
/// do nome. Não há mais aresta verde à esquerda: o verde da linha virou a
/// bolinha, que quer dizer "ligado" — que é uma informação, e não uma
/// decoração.
class EgNavTile extends StatelessWidget {
  const EgNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.shortcut,
    this.statusColor,
    this.statusValue,
    this.iconColor,
    this.isMuted = false,
    this.margin,
  });

  final EgIconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  /// A tecla que abre o módulo, à direita do nome. `null` no que não tem
  /// atalho — o Track, que só existe aqui dentro.
  final String? shortcut;

  /// A bolinha de estado. `null` some com ela.
  final Color? statusColor;

  /// O que está acontecendo agora, no lugar da bolinha — o `18:04` de uma
  /// sessão em curso. Some a bolinha e entra o número, porque os dois dizem a
  /// mesma coisa e o número diz mais.
  final String? statusValue;

  /// Padrão: verde claro quando selecionado, texto secundário no resto do
  /// tempo. A marca passa o verde cheio, que é identidade e não estado.
  final Color? iconColor;

  /// Esmaece a linha sem desligá-la — o módulo que a pessoa desligou continua
  /// clicável, porque é por aqui que ela o religa.
  final bool isMuted;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final style = eg.surfaces.sidebarItem;

    return EgInteractiveSurface(
      onTap: onTap,
      style: style,
      isSelected: isSelected,
      borderRadius: eg.shapes.rowAll,
      height: _height,
      margin: margin,
      padding: EdgeInsets.symmetric(horizontal: eg.shapes.rowPaddingH - 2),
      semanticLabel: [
        title,
        if (shortcut != null) 'atalho $shortcut',
      ].join(', '),
      builder: (context, state) => Opacity(
        opacity: isMuted ? AppOpacities.unavailable : 1,
        child: Row(
          children: [
            EgIcon(
              icon,
              size: AppIconSizes.lg,
              color:
                  iconColor ??
                  (isSelected
                      ? eg.colors.accentLight
                      : eg.colors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (isSelected ? eg.text.bodyStrong : eg.text.body)
                    .copyWith(
                      color: style.foregroundFor(state, isSelected: isSelected),
                    ),
              ),
            ),
            if (shortcut != null)
              Text(
                shortcut!,
                style: eg.text.keycap.copyWith(color: eg.colors.textQuaternary),
              ),
            if (statusValue != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusValue!,
                style: eg.text.monoSmall.copyWith(color: eg.colors.ember),
              ),
            ] else if (statusColor != null) ...[
              const SizedBox(width: AppSpacing.sm),
              EgStatusDot(color: statusColor!),
            ],
          ],
        ),
      ),
    );
  }

  static const _height = 34.0;
}

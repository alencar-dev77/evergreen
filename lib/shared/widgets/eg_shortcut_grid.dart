import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_icon.dart';
import 'eg_key_cap.dart';

/// Uma entrada do mapa de teclas: o que abre, e com o quê.
@immutable
class EgShortcutEntry {
  const EgShortcutEntry({
    required this.icon,
    required this.label,
    required this.keys,
    this.isMuted = false,
  });

  final EgIconData icon;
  final String label;
  final List<String> keys;

  /// Módulo desligado: continua na lista, apagado. Some daqui seria esconder
  /// que a tecla dele **continua reservada** — e a pessoa iria tentar usá-la
  /// noutro módulo e receber "esse atalho já é de alguém".
  final bool isMuted;
}

/// Todas as teclas do app numa grade de duas colunas.
///
/// A barra lateral mostra a tecla de cada módulo, mas uma por linha, espalhada
/// pela altura da janela: para responder "qual era mesmo o do Nest?" é preciso
/// varrer sete linhas em três grupos. Aqui elas estão juntas, e o bloco inteiro
/// se lê de uma vez — que é o que se quer de um mapa.
///
/// Não é onde se troca a tecla: trocar é na tela do módulo, ao lado do que ela
/// abre. Aqui é só a lista.
class EgShortcutGrid extends StatelessWidget {
  const EgShortcutGrid({super.key, required this.entries});

  final List<EgShortcutEntry> entries;

  @override
  Widget build(BuildContext context) {
    final rows = (entries.length + 1) ~/ 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Entry(entry: entries[row])),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: row + rows < entries.length
                    ? _Entry(entry: entries[row + rows])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lê-se em coluna, e não em serpentina: com sete módulos, a leitura por
/// linhas põe Pin e Awake lado a lado sem que nada os aproxime. Por coluna, a
/// primeira metade da lista fica à esquerda e a segunda à direita, na ordem em
/// que a barra lateral já os apresentou.
class _Entry extends StatelessWidget {
  const _Entry({required this.entry});

  final EgShortcutEntry entry;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return Opacity(
      opacity: entry.isMuted ? AppOpacities.unavailable : 1,
      child: Row(
        children: [
          EgIcon(
            entry.icon,
            size: AppIconSizes.md,
            color: eg.colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: eg.text.body,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Uma tecla só, com a combinação inteira dentro: três caixas
          // separadas custam duas vezes a largura e empurram o nome do módulo
          // para as reticências — e num mapa de teclas o nome é metade da
          // informação.
          Semantics(
            label: 'Atalho ${entry.keys.join(' ')}',
            excludeSemantics: true,
            child: EgKeyCap(entry.keys.join()),
          ),
        ],
      ),
    );
  }
}

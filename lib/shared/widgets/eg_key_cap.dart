import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';

/// Tecla individual renderizada como key-cap (`⌘`, `⇧`, `V`).
///
/// Sem semântica própria: quem anuncia o atalho é o [EgShortcutDisplay] em
/// volta, numa frase só. Lidos um a um, os símbolos viram ruído — o leitor de
/// tela não tem o que fazer com um `⌘` solto.
class EgKeyCap extends StatelessWidget {
  const EgKeyCap(this.label, {super.key, this.onGlass = false});

  final String label;

  /// A tecla mora sobre o vidro de um painel flutuante.
  ///
  /// Ali a escala de neutros não vale: o que passa por trás muda a leitura de
  /// qualquer cinza opaco, e uma tecla pintada de `control` some quando o
  /// painel abre sobre uma janela clara. Sobre vidro ela é branco com alfa.
  final bool onGlass;

  /// Altura interna da tecla — ver a nota no `padding`.
  static const _capPadding = 3.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        // Meio degrau da escala: com [AppSpacing.xxs] a tecla fica alta demais
        // para uma linha de dicas de 11px, e com 2 ela vira um retângulo.
        vertical: _capPadding,
      ),
      decoration: BoxDecoration(
        color: onGlass
            ? context.eg.colors.glassControl
            : context.eg.colors.control,
        borderRadius: context.eg.shapes.segmentAll,
      ),
      child: Text(label, style: context.eg.text.keycap),
    );
  }
}

/// Sequência de key-caps que representa um atalho completo.
class EgShortcutDisplay extends StatelessWidget {
  const EgShortcutDisplay({
    super.key,
    required this.keys,
    this.onGlass = false,
  });

  final List<String> keys;

  /// Ver [EgKeyCap.onGlass].
  final bool onGlass;

  /// O nome falado de cada símbolo de modificadora.
  ///
  /// Os key-caps são desenhados com os símbolos do macOS, que é como o sistema
  /// os escreve em qualquer menu — mas ler `⌘⇧C` em voz alta não dá "Command
  /// Shift C", e sim três caracteres que ninguém reconhece. A tradução é a
  /// mesma que o próprio macOS faz ao anunciar um item de menu.
  static const _spoken = <String, String>{
    '⌘': 'Command',
    '⇧': 'Shift',
    '⌥': 'Option',
    '⌃': 'Control',
    '⏎': 'Enter',
    '⌫': 'Delete',
    '↑': 'seta para cima',
    '↓': 'seta para baixo',
    '←': 'seta para a esquerda',
    '→': 'seta para a direita',
  };

  /// O atalho como se fala: `⌘⇧C` vira "Command Shift C".
  String get spokenLabel =>
      'Atalho ${keys.map((key) => _spoken[key] ?? key).join(' ')}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: spokenLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xxs),
            EgKeyCap(keys[i], onGlass: onGlass),
          ],
        ],
      ),
    );
  }
}

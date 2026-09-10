import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';

/// Campo de texto de uma linha do design system.
///
/// Diferente do [EgSearchField](eg_search_field.dart), que existe para filtrar
/// uma lista enquanto se digita, este é para um texto que a pessoa escreve e
/// confirma — a atividade e o resumo de uma sessão do Focus.
///
/// Em repouso a borda é a sutil de 1px; com o foco ela vira accent. Não há anel
/// de foco por sombra aqui: num campo de texto a própria borda já é o
/// indicador, e um anel por fora dela seria redundância de affordance.
class EgTextField extends StatefulWidget {
  const EgTextField({
    this.bare = false,
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Placeholder. Específico do contexto, nunca genérico (`components.md`).
  final String? hintText;

  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Confirmação pelo Enter. Vem do canal de texto do sistema, e não de um
  /// atalho: um `Shortcuts` acima do campo pode nunca ver essa tecla.
  final ValueChanged<String>? onSubmitted;

  final bool enabled;

  /// Sem moldura até receber o cursor.
  ///
  /// É o campo que mora **dentro de uma lista**, onde o valor é lido muito
  /// mais vezes do que é escrito — o apelido de um destino do Nest. Uma caixa
  /// permanente ali diz "isto é um formulário" para uma lista que é, na maior
  /// parte do tempo, só de leitura; e nove caixas empilhadas transformam a
  /// lista num questionário.
  ///
  /// Focado, ele ganha a mesma moldura de sempre: quem está escrevendo precisa
  /// ver onde termina o campo.
  final bool bare;

  /// Altura mínima em linhas. O campo cresce a partir daí conforme se escreve.
  ///
  /// Um campo de uma linha para um texto de três diz a coisa errada antes de a
  /// pessoa digitar: ele parece pedir uma palavra. Quando a resposta esperada
  /// tem fôlego, a altura precisa anunciar isso.
  final int? minLines;

  /// Teto de linhas antes de o campo rolar por dentro. `null` cresce sem limite.
  ///
  /// Com mais de uma linha, o Enter passa a quebrar a linha em vez de submeter
  /// — é o comportamento nativo de campo de várias linhas, e por isso quem usa
  /// [maxLines] maior que 1 precisa guardar o texto por outro caminho (sair do
  /// campo, tipicamente) em vez de depender do [onSubmitted].
  final int? maxLines;

  @override
  State<EgTextField> createState() => _EgTextFieldState();
}

class _EgTextFieldState extends State<EgTextField> {
  FocusNode? _internalNode;
  bool _isFocused = false;

  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(EgTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;

    oldWidget.focusNode?.removeListener(_syncFocus);
    _internalNode?.removeListener(_syncFocus);
    _node.addListener(_syncFocus);
    // Re-lê o estado do nó novo na hora: quando o Flutter reaproveita este
    // widget para outro campo (atividade → anotação), o `_isFocused` herdado
    // descreveria o nó antigo — e o campo novo nasceria com borda de focado.
    _syncFocus();
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_syncFocus);
    _internalNode?.dispose();
    super.dispose();
  }

  void _syncFocus() {
    if (_node.hasFocus == _isFocused) return;
    setState(() => _isFocused = _node.hasFocus);
  }

  /// Campo de uma linha não guarda quebra de linha — nem colada.
  ///
  /// Digitar não produz `\n` num campo de uma linha, mas **colar produz**: o
  /// Flutter insere o texto da área de transferência como veio, e o campo
  /// passa a conter uma quebra que ele não sabe desenhar. O estrago aparece
  /// depois, em quem serializa: a observação do Focus usa `\n` como separador
  /// de registros, e uma nota colada de dois parágrafos virava uma nota
  /// truncada mais uma linha de lixo descartada em silêncio.
  ///
  /// A regra fica aqui, e não em cada chamador, pela mesma razão que a matriz
  /// de estado do `EgSurfaceStyle` não mora dentro de cada botão: quem sabe
  /// que este campo é de uma linha é este campo. O apelido do Pin, o do
  /// destino do Nest e a atividade do Focus ganham a mesma proteção sem saber
  /// dela.
  static final _singleLine = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(
      RegExp(r'\s*[\r\n]+\s*'),
      replacementString: ' ',
    ),
  ];

  /// `null` no campo de várias linhas: lá a quebra é o conteúdo.
  List<TextInputFormatter>? get _formatters =>
      (widget.maxLines ?? 2) > 1 ? null : _singleLine;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.instant,
      curve: AppDurations.curve,
      padding: widget.bare
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
      decoration: BoxDecoration(
        // **O campo afunda; o cartão levanta.** Ele era `surfaceTop`, quatro
        // pontos *acima* do cartão em que mora — dois retângulos arredondados,
        // quase do mesmo cinza, um dentro do outro, cada um com o seu contorno:
        // era isso o "caixa dentro de caixa" que fazia a tela de preferências
        // parecer um desenho de arame. Escrito é conteúdo que entra na
        // superfície, não uma peça apoiada sobre ela — e o poço dá à tela a
        // segunda direção de profundidade que faltava.
        color: widget.bare && !_isFocused ? null : context.eg.colors.canvasDeep,
        borderRadius: context.eg.shapes.controlAll,
        border: Border.all(
          color: _isFocused
              ? context.eg.colors.accent
              : (widget.bare
                    ? const Color(0x00000000)
                    : context.eg.colors.edge),
        ),
      ),
      child: Opacity(
        opacity: widget.enabled ? 1 : AppOpacities.disabled,
        child: TextField(
          controller: widget.controller,
          focusNode: _node,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          inputFormatters: _formatters,
          cursorColor: context.eg.colors.accent,
          cursorWidth: 1.5,
          // Altura fixa só faz sentido na linha única; em campo de várias
          // linhas ela descolaria do texto conforme ele quebra.
          cursorHeight: (widget.maxLines ?? 2) > 1 ? null : 16,
          style: context.eg.text.body,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: widget.hintText,
            hintStyle: context.eg.text.body.copyWith(
              color: context.eg.colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

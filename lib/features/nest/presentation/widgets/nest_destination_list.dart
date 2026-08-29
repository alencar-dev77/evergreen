import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../../models/nest_destination.dart';

/// As pastas favoritas na tela de preferências: uma linha por pasta, com o nome
/// editável e o caminho embaixo.
///
/// O nome é um campo, e não um rótulo com um botão "renomear": o apelido é a
/// única coisa desta linha que a pessoa escreve, e um campo já é o controle que
/// diz isso. Guarda ao perder o foco, por qualquer caminho — a convenção do
/// apelido do Pin e do cartão do Leaf.
///
/// O caminho fica abaixo, em `text/tertiary`: duas pastas chamadas "Entrada" em
/// lugares diferentes são indistinguíveis sem ele, e é justamente quem cadastra
/// várias que precisa saber qual é qual.
class NestDestinationList extends StatelessWidget {
  const NestDestinationList({
    super.key,
    required this.destinations,
    required this.onRename,
    required this.onRemove,
  });

  final List<NestDestination> destinations;
  final void Function(int index, String alias) onRename;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < destinations.length; index++)
          _DestinationRow(
            // A chave é o caminho: sem ela, remover a primeira pasta faria o
            // campo da segunda herdar o texto que estava sendo escrito na
            // primeira — o `State` do campo é reaproveitado por posição.
            key: ValueKey(destinations[index].path),
            destination: destinations[index],
            number: index + 1,
            onRename: (alias) => onRename(index, alias),
            onRemove: () => onRemove(index),
          ),
      ],
    );
  }
}

class _DestinationRow extends StatefulWidget {
  const _DestinationRow({
    super.key,
    required this.destination,
    required this.number,
    required this.onRename,
    required this.onRemove,
  });

  final NestDestination destination;

  /// A posição na lista, que é o número do atalho no painel (`⌘1..⌘9`).
  final int number;

  final ValueChanged<String> onRename;
  final VoidCallback onRemove;

  @override
  State<_DestinationRow> createState() => _DestinationRowState();
}

class _DestinationRowState extends State<_DestinationRow> {
  late final _controller = TextEditingController(
    text: widget.destination.alias,
  );
  final _focusNode = FocusNode(debugLabel: 'nest-destination-alias');

  /// Coluna do número do atalho — o mesmo `⌘N` que o painel obedece.
  static const _numberColumn = 28.0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_commitOnBlur);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitOnBlur);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commitOnBlur() {
    if (_focusNode.hasFocus) return;

    widget.onRename(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(border: context.eg.borderBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _numberColumn,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '⌘${widget.number}',
                style: context.eg.text.monoSmall.copyWith(
                  color: context.eg.colors.textTertiary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EgTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: widget.destination.label,
                  onSubmitted: widget.onRename,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  widget.destination.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: context.eg.text.captionXS.copyWith(
                    color: context.eg.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: EgIconButton(
              icon: EgIconData.close,
              tooltip: 'Remover ${widget.destination.label} da lista',
              onPressed: widget.onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

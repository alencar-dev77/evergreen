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
    final eg = context.eg;

    // Uma linha, e não um bloco de três: o campo de nome ocupava a largura
    // toda e o caminho ia para uma segunda linha embaixo dele, o que fazia
    // cada destino ter a altura de um cartão. Numa lista que chega a nove
    // pastas, isso é a tela inteira para dizer nove nomes.
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(border: Border(bottom: eg.hairline)),
      child: Row(
        children: [
          SizedBox(
            width: _numberColumn,
            child: Text(
              '⌘${widget.number}',
              style: eg.text.keycap.copyWith(color: eg.colors.textQuaternary),
            ),
          ),
          // O apelido é editável no lugar, sem moldura: até receber o cursor
          // ele se lê como o nome da pasta, que é o que ele é. Uma caixa de
          // campo permanente diria "isto é um formulário" para uma lista que
          // é, na maior parte do tempo, só de leitura.
          SizedBox(
            width: _aliasColumn,
            child: EgTextField(
              controller: _controller,
              focusNode: _focusNode,
              hintText: widget.destination.label,
              bare: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              // A pasta sumiu do disco: o caminho gravado continua na tela —
              // é o que permite reconhecer qual era e recadastrá-la —, com o
              // aviso na frente e em cor de alerta. Ver
              // [NestDestination.isMissing].
              widget.destination.isMissing
                  ? 'não encontrada · ${widget.destination.path}'
                  : widget.destination.path,
              maxLines: 1,
              // No meio, e não no fim: o fim de um caminho é o nome da pasta,
              // que é justamente a parte que identifica o destino.
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: eg.text.footnote.copyWith(
                color: widget.destination.isMissing
                    ? eg.colors.warning
                    : eg.colors.textQuaternary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          EgIconButton(
            icon: EgIconData.close,
            tooltip: 'Remover ${widget.destination.alias}',
            size: 24,
            iconSize: AppIconSizes.sm,
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }

  /// A altura de uma linha de destino.
  static const _rowHeight = 40.0;

  /// A largura do apelido. Fixa para os nomes alinharem entre si — em largura
  /// livre, cada linha começaria o caminho num lugar diferente.
  static const _aliasColumn = 180.0;
}

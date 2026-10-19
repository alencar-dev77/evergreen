import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../../models/meeting.dart';
import '../viewmodels/echo_rename_request.dart';

/// O nome da reunião no cabeçalho da leitura — e o lugar de trocá-lo.
///
/// **Renomeia-se no lugar**, como um arquivo no Finder: clicar no nome (ou
/// `⌘R`, o mesmo do apelido do Pin) o transforma num campo do mesmo tamanho,
/// com o texto todo selecionado. Um botão de lápis ao lado seria um segundo
/// elemento para dizer a mesma coisa, e um diálogo pediria atenção para um
/// nome.
///
/// As regras de campo da casa: `Enter` e sair do campo, por qualquer caminho,
/// guardam; `Esc` desfaz antes de sair, e por isso nunca colide com o guardar
/// do foco perdido. Apagar tudo devolve o nome de data e hora com que a reunião
/// nasceu — é o que o campo mostra, apagado, enquanto está vazio.
class EchoMeetingTitle extends ConsumerStatefulWidget {
  const EchoMeetingTitle({
    super.key,
    required this.meeting,
    required this.onRename,
  });

  final Meeting meeting;
  final ValueChanged<String> onRename;

  @override
  ConsumerState<EchoMeetingTitle> createState() => _EchoMeetingTitleState();
}

class _EchoMeetingTitleState extends ConsumerState<EchoMeetingTitle> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'echo-meeting-title');

  var _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_commitOnBlur);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitOnBlur);
    // A reunião trocada ou a leitura fechada com o campo aberto, sem ter
    // passado pelo foco perdido: o que foi escrito não pode ir embora junto.
    // Numa microtarefa, porque mexer na lista durante a desmontagem é mexer
    // num provider no meio de um build.
    if (_editing) {
      final title = _controller.text;
      final rename = widget.onRename;
      scheduleMicrotask(() => rename(title));
    }
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _edit() {
    // `⌘R` com o campo já aberto não recomeça a edição: apagaria o que está
    // sendo escrito.
    if (_editing) return;

    _controller
      ..text = widget.meeting.title
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.meeting.title.length,
      );
    setState(() => _editing = true);
    // Pedido explícito, e não `autofocus`: o autofocus só vale quando o
    // escopo não tem ninguém focado, e no Hub quase sempre tem.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _focusNode.requestFocus();
    });
  }

  void _commitOnBlur() {
    if (_focusNode.hasFocus || !_editing) return;

    widget.onRename(_controller.text);
    setState(() => _editing = false);
  }

  /// O `Esc`: desfaz **e depois** sai, de modo que o guardar do foco perdido
  /// grave o nome que já estava — o que o `rename` reconhece e não grava.
  void _cancel() {
    _controller.text = widget.meeting.title;
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(echoRenameRequestProvider, (_, _) => _edit());

    final eg = context.eg;

    // Puxado para a esquerda pelo respiro da caixa: o texto continua alinhado
    // com a linha de baixo, e é a caixa — do hover e do campo — que avança
    // sobre a margem, como o nome de um arquivo no Finder.
    return Transform.translate(
      offset: const Offset(-AppSpacing.sm, 0),
      child: _editing ? _field(eg) : _label(eg),
    );
  }

  Widget _label(EgTokens eg) => EgInteractiveSurface(
    onTap: _edit,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    borderRadius: eg.shapes.controlAll,
    semanticLabel: '${widget.meeting.title}, renomear',
    child: Text(
      widget.meeting.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: eg.text.panelTitle,
    ),
  );

  Widget _field(EgTokens eg) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
    child: EgTextField(
      controller: _controller,
      focusNode: _focusNode,
      bare: true,
      style: eg.text.panelTitle,
      hintText: Meeting.defaultTitle(widget.meeting.startedAt),
      onSubmitted: (_) => _focusNode.unfocus(),
    ),
  );
}

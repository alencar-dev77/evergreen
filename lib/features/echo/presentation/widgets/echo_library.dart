import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../viewmodels/echo_library_view_model.dart';
import 'echo_meeting_list.dart';

/// As reuniões gravadas, na área de conteúdo do Hub.
///
/// A lista ocupa a largura inteira e a leitura acontece na região dedicada que
/// a janela abre ao lado (`HubDetailRegion`). Foram três desenhos até aqui:
/// resumo e transcrição empilhados sob a lista (empurravam tudo para fora da
/// tela), depois lista e leitura dividindo a área de conteúdo (a leitura ficava
/// espremida), e por fim este — a lista larga, a leitura numa região que a
/// janela cresce para caber.
class EchoLibrary extends StatelessWidget {
  const EchoLibrary({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onToggleKept,
    this.now,
  });

  final EchoLibraryState state;

  /// Escolhe a reunião e abre a região de leitura — as duas coisas são o mesmo
  /// gesto, porque uma reunião selecionada e fechada não serve para nada.
  final void Function(int id) onOpen;

  final void Function(int id) onToggleKept;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const EgEmptyState(
        icon: EgIconData.microphone,
        title: 'Nenhuma reunião gravada',
        message:
            'Aperte ⌘⇧E antes da próxima reunião. A transcrição aparece aqui '
            'quando ela terminar.',
      );
    }

    return EchoMeetingList(
      meetings: state.meetings,
      selectedId: state.selectedId,
      onSelect: onOpen,
      onToggleKept: onToggleKept,
      now: now,
    );
  }
}

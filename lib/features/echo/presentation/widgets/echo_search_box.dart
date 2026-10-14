import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/eg_search_field.dart';
import '../../models/meeting_search.dart';
import '../viewmodels/echo_library_view_model.dart';
import '../viewmodels/echo_search_focus.dart';

/// A busca das reuniões, no topo da aba delas.
///
/// O teclado de uma busca acoplada a uma lista, como o Spotlight: com o cursor
/// aqui, `↑↓` andam pelos resultados, `Enter` abre o apontado e `Esc` apaga o
/// que foi digitado. Esc com o campo vazio não é dele — sobe para o Hub, que
/// tira o cursor do campo, e o Esc seguinte faz o de sempre.
///
/// O texto mora no estado da biblioteca, não aqui: trocar de aba e voltar
/// encontra a busca onde ela ficou.
class EchoSearchBox extends ConsumerStatefulWidget {
  const EchoSearchBox({super.key, required this.onOpened});

  /// A busca abriu uma reunião — quem monta a tela abre a região de leitura.
  final VoidCallback onOpened;

  @override
  ConsumerState<EchoSearchBox> createState() => _EchoSearchBoxState();
}

class _EchoSearchBoxState extends ConsumerState<EchoSearchBox> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode(debugLabel: 'echo-busca');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(echoLibraryViewModelProvider).query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Abrir é o fim da busca, e o teclado vai junto para a leitura.
  ///
  /// O cursor sai do campo: com ele lá, o espaço seguinte seria mais um
  /// espaço na busca — e não o áudio tocando do trecho que acabou de abrir.
  /// Fora do campo, as teclas são as da região (espaço, setas, S), o Esc
  /// fecha a leitura e o `⌘F` volta aqui com o texto selecionado. A busca e
  /// as marcas ficam de pé. É também o que um clique numa linha já fazia.
  void _open() {
    if (ref.read(echoLibraryViewModelProvider.notifier).openEntry()) {
      _focusNode.unfocus();
      widget.onOpened();
    }
  }

  void _clear() {
    _controller.clear();
    ref.read(echoLibraryViewModelProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(echoSearchFocusProvider, (_, _) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });

    // A linha que as setas apontam não está onde o leitor de tela está — ele
    // fica no campo. Sem o anúncio, `↑↓` mudariam a seleção em silêncio.
    ref.listen<int?>(
      echoLibraryViewModelProvider.select((state) => state.activeEntry),
      (previous, next) {
        if (next == null || previous == next || !_focusNode.hasFocus) return;

        final entries = ref.read(echoLibraryViewModelProvider).entries;
        if (next >= entries.length) return;

        final entry = entries[next];
        final hit = entry.hit;
        SemanticsService.sendAnnouncement(
          View.of(context),
          hit == null
              ? 'Reunião ${entry.result.meeting.title}'
              : [
                  hit.kind == MeetingHitKind.summary
                      ? 'Resumo'
                      : (hit.speaker ?? ''),
                  ?hit.timestamp,
                  hit.snippet,
                ].join(', '),
          Directionality.of(context),
        );
      },
    );

    final viewModel = ref.read(echoLibraryViewModelProvider.notifier);
    // Pelo que está escrito, e não pelo que a busca entende: uma letra solta
    // ainda não busca nada, mas o Esc continua sendo o jeito de apagá-la.
    final hasQuery = ref.watch(
      echoLibraryViewModelProvider.select((state) => state.query.isNotEmpty),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            viewModel.moveActive(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            viewModel.moveActive(-1),
        const SingleActivator(LogicalKeyboardKey.enter): _open,
        if (hasQuery) const SingleActivator(LogicalKeyboardKey.escape): _clear,
      },
      child: EgSearchField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: viewModel.search,
        hintText: 'Buscar em todas as reuniões',
        shortcut: const ['⌘', 'F'],
      ),
    );
  }
}

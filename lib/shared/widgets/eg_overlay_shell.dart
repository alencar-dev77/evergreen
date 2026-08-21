import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design/app_metrics.dart';

/// A casca dos painéis flutuantes do Evergreen — Pin, Focus, Leaf, Awake e
/// Echo.
///
/// Todos dividem a janela 0 (ver `OverlayWindow`) e, até a componentização do
/// design system, dividiam também setenta linhas de infraestrutura copiadas
/// entre si: registrar-se como `WindowListener`, animar a entrada, decidir o
/// que é um blur de verdade e tratar o vazio ao redor do painel como barreira.
/// Cinco cópias de um comportamento que precisa ser idêntico nos cinco painéis
/// são cinco chances de ele deixar de ser — e o Echo, o módulo mais novo,
/// nasceu com a cópia porque copiar era o caminho mais curto.
///
/// O que a casca garante, e por quê:
///
/// - **Fade curto na chegada, saída sem animação.** Voltar ao trabalho é mais
///   urgente que assistir o painel sair, então esconder é instantâneo. O
///   controlador nasce em 1 para que a primeira construção — e os testes, que
///   não têm janela — já mostrem o painel pronto; quem rebobina é o
///   `onWindowFocus`, uma vez por abertura.
/// - **Perder o foco fecha, mas só quando é de verdade.** Ativar a janela faz o
///   macOS oscilar o key status por um instante, e um `windowDidResignKey`
///   isolado não significa que a pessoa saiu — a casca espera
///   [_blurGracePeriod] e confirma que o foco não voltou antes de fechar. Sem
///   essa checagem o painel pisca e some logo depois de abrir.
/// - **Clicar fora fecha.** A janela é maior que o painel para caber a sombra;
///   o resto dela é transparente mas ainda captura cliques, então essa área é
///   tratada como barreira, e o painel a intercepta para que clicar dentro não
///   feche.
/// - **O painel é centralizado na janela.** Quem se posiciona na tela é a
///   janela; centralizar aqui é o que faz painéis de alturas diferentes
///   nascerem no mesmo ponto da tela.
/// - **O teclado não sai do painel.** No macOS um `TextField` larga o foco a
///   cada clique fora dele, e o foco largado cai no escopo da rota — que fica
///   *acima* do `Shortcuts` do módulo. Dali nenhuma tecla volta a descer: o
///   mapa inteiro emudece, Esc incluído, e o painel fica só de mouse. A casca
///   põe um `FocusScope` em volta do painel para que esse foco largado caia
///   **dentro** do módulo, e não fora dele. É a mesma falha que o Pin corrigiu
///   sozinho no campo de busca (`EgSearchField.holdsFocus`) e que reapareceu no
///   Leaf e no Focus, que também têm campo de texto — por isso agora ela é
///   resolvida uma vez, aqui.
class EgOverlayShell extends StatefulWidget {
  const EgOverlayShell({
    super.key,
    required this.child,
    required this.onClose,
    this.onShow,
    this.focusNode,
  });

  /// O painel.
  final Widget child;

  /// Fechar: clique fora, foco perdido para outro aplicativo ou fechamento da
  /// janela. Cada módulo decide o que "fechar" significa para ele — o Leaf
  /// guarda o que estava sendo escrito, o Pin devolve o foco ao aplicativo
  /// anterior —, mas nenhum deles decide *quando*.
  final VoidCallback onClose;

  /// Chamado quando a janela ganha o foco, isto é, a cada abertura do painel.
  /// É onde os módulos limpam campos e recolocam o cursor.
  final VoidCallback? onShow;

  /// Nó que segura o foco do painel quando não há campo de texto na tela — sem
  /// um nó focado, o `Shortcuts` do módulo não receberia tecla nenhuma. O Pin
  /// não passa nenhum: lá quem tem o foco é sempre o campo de busca.
  final FocusNode? focusNode;

  /// Margem para o macOS terminar a troca de foco antes de confirmarmos um
  /// blur. Curta o bastante para o fechamento continuar parecendo instantâneo.
  static const _blurGracePeriod = Duration(milliseconds: 150);

  @override
  State<EgOverlayShell> createState() => _EgOverlayShellState();
}

class _EgOverlayShellState extends State<EgOverlayShell>
    with WindowListener, SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: AppDurations.entrance,
    value: 1,
  );

  late final _entranceOpacity =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _entranceOpacity.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    _entrance.forward(from: 0);
    widget.onShow?.call();
  }

  @override
  void onWindowBlur() => unawaited(_handleBlur());

  @override
  void onWindowClose() => widget.onClose();

  Future<void> _handleBlur() async {
    await Future<void>.delayed(EgOverlayShell._blurGracePeriod);
    if (!mounted) return;
    if (await windowManager.isFocused()) return;

    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final focusNode = widget.focusNode;

    Widget panel = FadeTransition(
      opacity: _entranceOpacity,
      child: widget.child,
    );

    if (focusNode != null) {
      panel = Focus(focusNode: focusNode, child: panel);
    }

    // O escopo é o chão do teclado deste painel — ver a classe.
    panel = FocusScope(child: panel);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: panel,
          ),
        ),
      ),
    );
  }
}

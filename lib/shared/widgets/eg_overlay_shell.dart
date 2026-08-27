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
/// - **Fechar por foco perdido é opcional** ([dismissOnBlur]). O padrão é
///   fechar, porque o painel é de passagem; o Echo é a exceção, e só enquanto
///   grava ou transcreve — ver a propriedade.
/// - **Arrastar é opcional** ([draggable]), e sai do fundo do próprio painel.
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
/// - **E quando ele sai assim mesmo, volta.** O escopo é o chão, mas um chão
///   vazio não recebe tecla nenhuma: se o único nó focável do painel some da
///   árvore com o foco na mão — o campo de apelido do Pin quando o preview
///   fecha, um campo de texto que o módulo desmonta —, o `primaryFocus` do
///   Flutter fica sem dono e **nenhum** `Shortcuts` é consultado. O painel
///   continua na tela, o cursor continua piscando em lugar nenhum, e cada
///   tecla vira o bipe de "não posso" do macOS: setas, Tab, `⌘P`, Esc. A casca
///   escuta o `FocusManager` e, sempre que o foco escapa do painel visível,
///   devolve — ao nó do módulo, quando ele tem um, ou ao nó próprio dela.
///   Nenhum painel do Evergreen fica sem teclado enquanto estiver aberto.
class EgOverlayShell extends StatefulWidget {
  const EgOverlayShell({
    super.key,
    required this.child,
    required this.onClose,
    this.onShow,
    this.focusNode,
    this.draggable = false,
    this.dismissOnBlur = true,
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

  /// Deixa arrastar a janela pelo fundo do painel.
  ///
  /// Quem arrasta é o macOS (`startDragging`), não o Flutter: entregue o gesto,
  /// o sistema conduz a janela até soltar o botão. Por isso o arrasto sai do
  /// fundo e não de uma alça — não há elemento novo no desenho, e botão e
  /// linha de permissão continuam recebendo clique normalmente (um toque curto
  /// vence o arrasto na arena de gestos; segurar e puxar vence o toque).
  ///
  /// A posição não sobrevive ao fechamento, e isso é de propósito:
  /// `OverlayWindow.show` recentraliza a cada abertura, na tela onde o cursor
  /// está. Arrastar resolve *esta* reunião, e o painel seguinte nasce onde
  /// todos os outros nascem — que é o que mantém o Pin e o Focus previsíveis
  /// mesmo dividindo a janela com o Echo.
  final bool draggable;

  /// Fechar quando o foco vai para outro aplicativo.
  ///
  /// Verdadeiro para todo mundo: o painel é de passagem, e quem clica na
  /// reunião quer a reunião, não o painel por cima dela.
  ///
  /// O Echo é a exceção, e só enquanto grava ou transcreve — ali o painel
  /// deixa de ser de passagem e vira algo que se acompanha *durante* a
  /// reunião. Fechá-lo ao clicar na reunião esconderia justamente o texto que
  /// está nascendo, e reabrir custa um atalho e a volta ao centro da tela. Esc
  /// e o botão continuam fechando: o que sai é o fechamento que a pessoa não
  /// pediu.
  final bool dismissOnBlur;

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

  /// O escopo do painel. Explícito, e não o implícito do `FocusScope`, porque
  /// a rede precisa perguntar a ele se o foco ainda está aqui dentro.
  final _scope = FocusScopeNode(debugLabel: 'overlay-panel');

  /// O nó de último recurso: recebe o teclado quando o painel fica sem nenhum
  /// outro nó focado — ver a classe.
  ///
  /// `skipTraversal` porque ele não é um destino, é um chão: quem navega com
  /// Tab dentro de um painel está indo para um controle, nunca para o fundo.
  final _fallback = FocusNode(
    debugLabel: 'overlay-panel-fallback',
    skipTraversal: true,
  );

  /// Uma recuperação de foco por quadro, no máximo.
  bool _isRecoveringFocus = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    FocusManager.instance.addListener(_onFocusChanged);

    // Também na montagem, e não só quando o foco muda: um painel pode nascer
    // sem que nada peça o teclado. É o que acontece ao trocar de painel com a
    // janela já na tela — não há `didBecomeKey`, então não há `onWindowFocus`
    // nem `onShow`, e o módulo novo apareceria mudo.
    _recoverFocus();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    windowManager.removeListener(this);
    _fallback.dispose();
    _scope.dispose();
    _entranceOpacity.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// Devolve o teclado ao painel quando ele escapa — ver a classe.
  ///
  /// Nunca agora, sempre depois, e o "depois" é bem específico: o fim do quadro
  /// **e** o esvaziamento da fila de microtarefas. O `autofocus` de um campo do
  /// módulo é aplicado numa microtarefa agendada durante a construção, e a rede
  /// precisa correr atrás dela — do contrário ela chegaria primeiro e o Pin
  /// abriria sem cursor na busca, trocando um painel mudo por um painel em que
  /// não se digita. Sair na frente aqui é pior do que chegar um quadro depois.
  ///
  /// Adiar também junta numa só as várias notificações que uma troca de tela
  /// dispara.
  void _onFocusChanged() => _recoverFocus();

  void _recoverFocus() {
    if (!mounted || _isRecoveringFocus) return;
    if (_scope.hasFocus) return;

    _isRecoveringFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        _isRecoveringFocus = false;
        if (!mounted || _scope.hasFocus) return;

        // O nó do módulo quando ele tem um: o painel sabe melhor que a casca
        // quem deve receber o teclado. Sem nó do módulo, o chão serve.
        (widget.focusNode ?? _fallback).requestFocus();
      });
    });
  }

  @override
  void onWindowFocus() {
    _entrance.forward(from: 0);
    widget.onShow?.call();
    // Depois do módulo: se ele recolocou o cursor num campo, não há o que
    // recuperar; se não recolocou, a casca não deixa a janela sem teclado.
    _recoverFocus();
  }

  @override
  void onWindowBlur() => unawaited(_handleBlur());

  @override
  void onWindowClose() => widget.onClose();

  Future<void> _handleBlur() async {
    if (!widget.dismissOnBlur) return;

    await Future<void>.delayed(EgOverlayShell._blurGracePeriod);
    if (!mounted) return;

    // De novo depois da espera: a fase do módulo pode ter virado no meio dela.
    // O caso real é o Echo — apertar Parar e clicar na reunião no mesmo
    // instante deixaria o fechamento a caminho enquanto a transcrição começa.
    if (!widget.dismissOnBlur) return;
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

    // O `Focus` existe sempre, com o nó do módulo ou com o da casca: é ele que
    // dá à rede um lugar para onde devolver o teclado. Sem ele, um painel sem
    // campo de texto — ou com o campo recém-desmontado — não teria nó nenhum
    // dentro do escopo, e o escopo vazio não recebe tecla.
    panel = Focus(
      focusNode: focusNode ?? _fallback,
      skipTraversal: focusNode == null,
      child: panel,
    );

    // O escopo é o chão do teclado deste painel — ver a classe.
    panel = FocusScope(node: _scope, child: panel);

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
            onPanStart: widget.draggable
                ? (_) => unawaited(windowManager.startDragging())
                : null,
            child: panel,
          ),
        ),
      ),
    );
  }
}

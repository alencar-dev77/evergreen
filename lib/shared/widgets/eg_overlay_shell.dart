import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import '../../core/window/overlay_window.dart';

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
/// - **Todo painel se arrasta** pelo próprio fundo ([draggable]). Só a pilha
///   do Nest no notch abre mão: ela é o recorte, e não tem para onde ir.
/// - **O painel é centralizado na janela.** Quem se posiciona na tela é a
///   janela; centralizar aqui é o que faz painéis de alturas diferentes
///   nascerem no mesmo ponto da tela.
/// - **Menos quando ele sai do notch** (`OverlayWindow.notchAnchor`, hoje só a
///   prateleira do Nest): aí ele encosta logo abaixo do recorte, e a entrada
///   não é o fade — é uma pílula preta que nasce do recorte, cresce até o
///   tamanho do painel e se dissolve nele. É o que diz de onde a prateleira
///   veio; um fade no topo da tela pareceria um painel que errou de lugar.
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
    this.draggable = true,
    this.dismissOnBlur = true,
    this.notchAttached = false,
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
  /// linha de permissão continuam recebendo clique normalmente: o arrasto só
  /// começa onde o clique deixa de ser clique ([_WindowDragRecognizer]).
  ///
  /// Ligado por padrão: o painel nasce no centro da tela, e o centro às vezes
  /// é justamente onde está o que se quer ver — a reunião atrás do Echo, o
  /// texto de onde se copia atrás do Pin, o arquivo atrás do Nest. Um painel
  /// preso obrigava a fechar para olhar. Desligado, só na pilha do notch.
  ///
  /// A posição não sobrevive ao fechamento, e isso é de propósito:
  /// `OverlayWindow.show` recentraliza a cada abertura, na tela onde o cursor
  /// está. Arrastar resolve *esta* vez, e o painel seguinte nasce onde todos
  /// nascem. Com o painel aberto, porém, ela é respeitada: o aviso que traz de
  /// volta um painel que já está na tela não o tira de onde foi posto.
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

  /// Saindo do notch, o painel encosta **no topo da tela**, sem o respiro de
  /// baixo da barra de menus: é ele que desenha a faixa do recorte, e assim
  /// continua o recorte em vez de pousar embaixo dele. Hoje, a pilha do Nest.
  final bool notchAttached;

  /// Margem para o macOS terminar a troca de foco antes de confirmarmos um
  /// blur. Curta o bastante para o fechamento continuar parecendo instantâneo.
  static const _blurGracePeriod = Duration(milliseconds: 150);

  @override
  State<EgOverlayShell> createState() => _EgOverlayShellState();
}

class _EgOverlayShellState extends State<EgOverlayShell>
    with WindowListener, TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: AppDurations.entrance,
    value: 1,
  );

  late final _entranceOpacity = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOut,
  );

  /// A entrada pelo notch. Nasce em 1 pelo mesmo motivo do [_entrance].
  late final _notchReveal = AnimationController(
    vsync: this,
    duration: AppDurations.notchReveal,
    value: 1,
  );

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

    // A entrada pelo notch começa quando a âncora **aparece**, e não no foco
    // da janela: com outro painel já na tela, a prateleira chamada pelo notch
    // nasce sem `onWindowFocus`, e o foco não diz se o painel veio do notch.
    //
    // E também quando o painel já monta com a âncora posta — a janela
    // escondida pode só desenhar depois de a âncora chegar. Não há âncora
    // velha para enganar esta conta: `OverlayWindow.hide` a apaga.
    _hadNotch = OverlayWindow.instance.notchAnchor.value != null;
    if (_hadNotch) _notchReveal.forward(from: 0);
    OverlayWindow.instance.notchAnchor.addListener(_onNotchAnchor);
  }

  bool _hadNotch = false;

  void _onNotchAnchor() {
    final hasNotch = OverlayWindow.instance.notchAnchor.value != null;
    if (hasNotch && !_hadNotch) _notchReveal.forward(from: 0);
    _hadNotch = hasNotch;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    OverlayWindow.instance.notchAnchor.removeListener(_onNotchAnchor);
    windowManager.removeListener(this);
    _fallback.dispose();
    _scope.dispose();
    _entranceOpacity.dispose();
    _entrance.dispose();
    _notchReveal.dispose();
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
    // Saindo do notch, quem faz a entrada é a pílula — ver [_onNotchAnchor].
    if (OverlayWindow.instance.notchAnchor.value == null) {
      _entrance.forward(from: 0);
    }
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

    panel = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onTap = () {},
            ),
        if (widget.draggable)
          _WindowDragRecognizer:
              GestureRecognizerFactoryWithHandlers<_WindowDragRecognizer>(
                () => _WindowDragRecognizer(debugOwner: this),
                (recognizer) =>
                    recognizer.onStart = (_) =>
                        unawaited(windowManager.startDragging()),
              ),
      },
      child: panel,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: ValueListenableBuilder<Size?>(
        valueListenable: OverlayWindow.instance.notchAnchor,
        child: panel,
        builder: (context, notch, panel) {
          if (notch == null) {
            return Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: panel,
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                widget.notchAttached ? 0 : notch.height + _NotchReveal.gap,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: _NotchReveal(
                animation: _notchReveal,
                notch: notch,
                attached: widget.notchAttached,
                child: panel!,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A prateleira saindo do notch.
///
/// Uma pílula preta, da cor do recorte, nasce com a largura dele e encostada
/// no topo da tela, cresce até o tamanho do painel e se dissolve nele enquanto
/// o painel aparece por baixo. O painel não se mexe: quem se move é a pílula,
/// então nada de layout é refeito durante a entrada e a prateleira já recebe
/// arquivo no primeiro quadro.
///
/// Sem animação para quem pediu para reduzir movimento.
class _NotchReveal extends StatelessWidget {
  const _NotchReveal({
    required this.animation,
    required this.notch,
    required this.child,
    this.attached = false,
  });

  /// O respiro entre a barra de menus e o topo do painel.
  static const gap = AppSpacing.sm;

  final Animation<double> animation;
  final Size notch;
  final Widget child;

  /// O painel encosta no topo da tela e já desenha a faixa do recorte — ver
  /// `EgOverlayShell.notchAttached`.
  final bool attached;

  @override
  Widget build(BuildContext context) {
    if (AppDurations.reduced(context)) return child;

    final eg = context.eg;

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        if (animation.value >= 1) return child!;

        final t = AppDurations.curve.transform(animation.value);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: const Interval(0.35, 1).transform(t),
              child: child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NotchPillPainter(
                    t: t,
                    notch: notch,
                    attached: attached,
                    color: eg.colors.notch,
                    radius: eg.shapes.radiusPanel,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A pílula de [_NotchReveal], desenhada em volta do painel e para cima dele —
/// até o topo da tela, que é onde o recorte está.
class _NotchPillPainter extends CustomPainter {
  const _NotchPillPainter({
    required this.t,
    required this.notch,
    required this.attached,
    required this.color,
    required this.radius,
  });

  final double t;
  final Size notch;

  /// O painel começa no topo da tela, e não abaixo da barra de menus.
  final bool attached;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Cheia até a metade, e daí se apaga enquanto o painel acende: a pílula
    // vira a prateleira em vez de sumir na frente dela.
    final opacity = t < 0.5 ? 1.0 : 1 - (t - 0.5) / 0.5;
    if (opacity <= 0) return;

    final width = lerpDouble(notch.width, size.width, t);
    final top = attached ? 0.0 : -(_NotchReveal.gap + notch.height);
    final bottom = lerpDouble(
      attached ? notch.height : -_NotchReveal.gap,
      size.height,
      t,
    );
    final corner = Radius.circular(lerpDouble(notch.height / 3, radius, t));

    final pill = RRect.fromLTRBAndCorners(
      (size.width - width) / 2,
      top,
      (size.width + width) / 2,
      bottom,
      bottomLeft: corner,
      bottomRight: corner,
    );

    canvas.drawRRect(pill, Paint()..color = color.withValues(alpha: opacity));
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_NotchPillPainter old) =>
      old.t != t ||
      old.notch != notch ||
      old.attached != attached ||
      old.color != color ||
      old.radius != radius;
}

/// O arrasto da janela, que só começa **onde o clique termina**.
///
/// O `PanGestureRecognizer` de fábrica aceita o mouse com 2 px de movimento,
/// e o clique tolera 18 (`kTouchSlop`). Entre um e outro, a mão que treme um
/// pouco ao clicar numa linha do Pin ou num botão do Focus perdia o clique
/// para o arrasto: a janela andava e nada acontecia. Com a mesma distância dos
/// dois lados, quem sai da tolerância do clique é, por definição, um arrasto.
///
/// E nunca menos que o de fábrica: um arrasto de dentro do painel — puxar a
/// lista do Nest para fora — precisa continuar chegando antes deste, senão
/// levar os arquivos embora viraria mover a janela.
class _WindowDragRecognizer extends PanGestureRecognizer {
  _WindowDragRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      math.max(
        computePanSlop(pointerDeviceKind, gestureSettings),
        gestureSettings?.touchSlop ?? kTouchSlop,
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../system/previous_app_focus_channel.dart';

/// Controla a janela nativa que hospeda os painéis flutuantes do Evergreen.
///
/// Transforma a janela 0 num painel flutuante: sem chrome, fundo transparente,
/// sempre acima dos outros apps e presente em todos os Spaces. A janela nunca é
/// destruída — apenas escondida —, o que faz `⌘⇧C` e `⌘⇧X` abrirem
/// instantaneamente. Pin e Focus compartilham esta janela; quem escolhe o
/// painel é o `overlayPanelProvider`, no lado Dart.
class OverlayWindow {
  OverlayWindow._();

  static final instance = OverlayWindow._();

  /// Largura total da janela. Maior que o painel (420) para acomodar a sombra
  /// de 60px de blur sem que ela seja cortada pela borda da janela.
  static const _windowSize = Size(560, 640);

  /// Fração da altura da tela onde o topo da janela é posicionado. Um pouco
  /// acima do centro, como o Spotlight.
  static const _verticalAnchor = 0.18;

  /// Teto da espera pelo quadro em branco. Se o engine não desenhar nesse
  /// prazo, escondemos assim mesmo: um flash é melhor que uma janela presa.
  static const _blankFrameTimeout = Duration(milliseconds: 80);

  /// Apaga o painel sem desmontá-lo — ver [hide].
  ///
  /// Vive aqui, e não num provider, porque quem precisa dele é o ciclo de
  /// esconder/exibir a janela; o `OverlayHost` só o escuta.
  final isPanelHidden = ValueNotifier<bool>(false);

  /// Ferrolho contra o fechamento que o próprio fechamento provoca — ver [hide].
  bool _isHiding = false;

  /// Visibilidade real, perguntada ao sistema.
  ///
  /// Guardar isso num bool local dessincroniza: o overlay também se fecha por
  /// Esc, por clique fora e por perda de foco, caminhos que não passam por
  /// aqui.
  Future<bool> isVisible() => windowManager.isVisible();

  /// Prepara a janela. Deve rodar antes do primeiro `runApp`.
  Future<void> configure() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: _windowSize,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);
      await windowManager.setResizable(false);
      await windowManager.setMovable(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setVisibleOnAllWorkspaces(
        true,
        visibleOnFullScreen: true,
      );
      // Fechar o overlay deve escondê-lo, nunca encerrar o Evergreen.
      await windowManager.setPreventClose(true);
      await windowManager.hide();
    });
  }

  /// Exibe o overlay, reposicionando-o na tela onde o cursor está.
  ///
  /// Reposicionar a cada abertura é o que mantém o painel sempre no monitor que
  /// o usuário está usando, em vez de onde ele foi aberto da última vez.
  Future<void> show() async {
    // Precisa vir antes do `windowManager.show()`: é o instante em que o app
    // anterior ainda é o frontmost do sistema, antes do `NSApp.activate` que
    // o `window_manager` dispara em seguida roubar o foco dele.
    await PreviousAppFocusChannel.capture();

    await _moveToActiveDisplay();

    // O painel volta a ser desenhado só agora: o quadro gravado na janela
    // escondida é o branco deixado por `hide`, e é ele que aparece no instante
    // em que o macOS reexibe a janela — invisível, porque a janela é
    // transparente. Ver [hide].
    isPanelHidden.value = false;

    // Só `show()`, nunca seguido de `focus()`: o `show()` do window_manager já
    // agenda `makeKeyAndOrderFront` + `NSApp.activate(ignoringOtherApps: true)`
    // num bloco assíncrono. Um `focus()` aqui dispara uma segunda ativação
    // (com `ignoringOtherApps: false`) que corre contra a primeira; a janela
    // perde e retoma o key status, e o `windowDidResignKey` no meio do caminho
    // fecha o overlay logo depois de abri-lo.
    await windowManager.show();
  }

  /// Esconde o overlay e devolve o foco ao app capturado em `show()`.
  ///
  /// Cobre todos os caminhos de fechamento — seleção de item, Esc, clique fora —
  /// já que todos passam por aqui. Com [paste] ligado (só no caminho de seleção,
  /// com o auto-colar ativo), além de devolver o foco também cola o item no app
  /// anterior; se a permissão de Acessibilidade faltar, cai no restore comum.
  ///
  /// Antes de esconder, apaga o painel e espera um quadro. Esconder uma janela
  /// não descarta o que estava desenhado nela: o macOS guarda a última
  /// superfície e a mostra de novo no instante em que a janela reaparece,
  /// **antes** de o Flutter desenhar o painel novo. Era isso que fazia o Pin
  /// piscar por um quadro ao abrir o Focus pelo atalho. Deixar um quadro em
  /// branco gravado resolve na raiz: a janela é transparente, então o que
  /// reaparece não se vê.
  ///
  /// Reentrante em silêncio: esconder a janela dispara o `windowDidResignKey`,
  /// e o painel responde a ele fechando de novo. Sem o ferrolho, esse segundo
  /// fechamento cairia no meio do auto-colar — que espera o app anterior voltar
  /// ao foco — e devolveria o foco por cima dele.
  Future<void> hide({bool paste = false}) async {
    if (_isHiding) return;
    _isHiding = true;

    try {
      await _blankPanel();
      await windowManager.hide();

      if (paste) {
        try {
          await PreviousAppFocusChannel.restoreAndPaste();
          return;
        } on PlatformException {
          // Sem permissão de Acessibilidade, sem app anterior ou sem conseguir
          // devolver o foco a ele: o item já está na área de transferência, então
          // basta devolver o foco como de costume.
        }
      }

      await PreviousAppFocusChannel.restore();
    } finally {
      _isHiding = false;
    }
  }

  /// Apaga o painel e espera o quadro em branco chegar à tela.
  ///
  /// `Opacity(0)` no `OverlayHost`, e não desmontar o painel: o widget continua
  /// vivo com os controladores, o foco e os listeners de janela dele — o painel
  /// não pode se reconstruir do zero toda vez que alguém aperta Esc.
  ///
  /// A espera tem prazo: o `endOfFrame` só resolve se o engine desenhar, e uma
  /// janela que já perdeu a tela por outro caminho poderia não desenhar nunca.
  Future<void> _blankPanel() async {
    if (isPanelHidden.value) return;

    isPanelHidden.value = true;
    await Future.any([
      WidgetsBinding.instance.endOfFrame,
      Future<void>.delayed(_blankFrameTimeout),
    ]);
  }

  Future<void> _moveToActiveDisplay() async {
    final display = await _activeDisplay();
    final visible = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;

    final x = visible.dx + (size.width - _windowSize.width) / 2;
    final y = visible.dy + size.height * _verticalAnchor;

    await windowManager.setPosition(Offset(x, y));
  }

  /// A tela que contém o cursor, com a primária como reserva.
  Future<Display> _activeDisplay() async {
    final cursor = await screenRetriever.getCursorScreenPoint();
    final displays = await screenRetriever.getAllDisplays();

    for (final display in displays) {
      final origin = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;
      final bounds = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);

      if (bounds.contains(cursor)) return display;
    }

    return screenRetriever.getPrimaryDisplay();
  }
}

import Cocoa

/// A janela invisível sobre o recorte da tela.
///
/// **Não desenha um pixel e não tem engine Flutter.** É um retângulo do tamanho
/// exato do recorte, registrado como destino de arraste e mais nada: solte um
/// arquivo ali e ele chega ao Dart pelo `NestChannel`, que manda o painel
/// aparecer. Isso é o que mantém de pé a regra da casa de que só a janela 0
/// desenha — o custo aqui é uma `NSWindow` vazia residente, não uma segunda
/// superfície viva.
///
/// Por que o recorte, e não um atalho: a prateleira precisa ser invocada com o
/// botão do mouse já pressionado, no meio de um arraste. Chacoalhar o mouse
/// exigiria monitorar eventos globais (mais uma permissão), e apertar um atalho
/// segurando o botão é desconfortável. O recorte está sempre lá, no caminho de
/// quem já está arrastando, e não custa permissão nenhuma.
///
/// Não existe API de recorte no macOS. O que existe é a medida da área segura
/// (`safeAreaInsets`, macOS 12+) e as duas faixas úteis ao lado dele
/// (`auxiliaryTopLeftArea`/`auxiliaryTopRightArea`); o que sobra entre elas é o
/// recorte. Abaixo do macOS 12, ou num Mac sem recorte, a janela simplesmente
/// não nasce — e a linha some da tela de preferências em vez de ficar apagada.
class NestNotchWindow: NSPanel {
  private static var shared: NestNotchWindow?

  /// A preferência de quem usa. Nasce ligada; sem recorte não muda nada.
  private static var isEnabled = true

  static func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    reposition()
  }

  /// Cria, move ou destrói a janela conforme a tela do momento.
  ///
  /// Chamada também a cada mudança de configuração de tela: fechar a tampa e
  /// trabalhar num monitor externo tira o recorte de baixo da janela, e uma
  /// janela ancorada num `NSScreen` que não existe mais fica num canto qualquer
  /// recebendo arquivos que ninguém quis soltar ali.
  static func reposition() {
    guard isEnabled, let screen = screenWithNotch(), let frame = notchFrame(of: screen) else {
      shared?.orderOut(nil)
      shared = nil
      return
    }

    if let window = shared {
      window.setFrame(frame, display: false)
      window.orderFrontRegardless()
      return
    }

    let window = NestNotchWindow(frame: frame)
    window.orderFrontRegardless()
    shared = window
  }

  /// A tela que tem recorte, se alguma tiver.
  static func screenWithNotch() -> NSScreen? {
    guard #available(macOS 12.0, *) else { return nil }

    return NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
  }

  /// O retângulo do recorte, em coordenadas de tela.
  private static func notchFrame(of screen: NSScreen) -> NSRect? {
    guard #available(macOS 12.0, *) else { return nil }

    let height = screen.safeAreaInsets.top
    guard height > 0 else { return nil }

    let left = screen.auxiliaryTopLeftArea?.width ?? 0
    let right = screen.auxiliaryTopRightArea?.width ?? 0
    let width = screen.frame.width - left - right
    guard width > 0 else { return nil }

    return NSRect(
      x: screen.frame.minX + left,
      y: screen.frame.maxY - height,
      width: width,
      height: height
    )
  }

  private init(frame: NSRect) {
    super.init(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = false
    isFloatingPanel = true
    hidesOnDeactivate = false

    // Acima da barra de menus: o recorte fica dentro dela, e no nível dela a
    // janela ficaria por baixo justamente na faixa que precisa receber o
    // arquivo.
    level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

    // `.stationary` para a janela não ser arrastada junto na animação de troca
    // de Space: ela é parte da tela, não do Space.
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

    // Uma view, e não a janela: `NSWindow` não implementa
    // `NSDraggingDestination` — quem receberia seria o delegate dela. Aqui a
    // view basta, porque esta janela não tem mais nada dentro nem cliques a
    // disputar. Ver `NestDrop`.
    contentView = NestDropView(frame: NSRect(origin: .zero, size: frame.size))
  }

  /// Nunca recebe o teclado: não há nada aqui para digitar, e virar key faria o
  /// recorte roubar o cursor de quem estava escrevendo em outro aplicativo.
  /// Receber arquivo não depende disso — destino de arraste e foco de teclado
  /// são coisas separadas no AppKit.
  override var canBecomeKey: Bool { false }
}

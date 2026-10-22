import Cocoa

/// Oferece levar o Evergreen para Aplicativos quando ele abre de fora dela.
///
/// Quem baixa o `.dmg` pode abrir o app de dentro da imagem de disco, ou
/// arrastá-lo só até os Downloads. Dali o macOS o executa de uma cópia
/// temporária (App Translocation), e o que ele guarda pelo caminho do app — o
/// item de "iniciar com o macOS", que o `LaunchAtLoginChannel` registra com o
/// caminho do bundle — fica preso a um lugar que some quando a imagem é
/// ejetada.
///
/// Nativo, e não um diálogo do Flutter, porque precisa vir antes de o item de
/// início ser adotado, e o Dart não chega a tempo disso. O engine já está de
/// pé quando ele aparece — a janela 0 sai do nib, que carrega antes do
/// `applicationWillFinishLaunching` —, e o Hub da apresentação de boas-vindas
/// pode abrir atrás dele. Não faz mal: o alerta é modal, ninguém avança a
/// apresentação enquanto ele está na tela, e aceitar encerra este processo
/// antes de ela ser marcada como vista — a cópia instalada a mostra de novo.
///
/// Fica quieto em Debug e em qualquer build aberta de `Build/Products/`: o
/// `flutter run --profile` e o `--release` rodam de lá, e aceitar mandaria a
/// build de trabalho para Aplicativos no lugar da instalada.
enum AppLocationGuard {
  private static let declinedKey = "evergreen.moveToApplications.declined"

  /// Pergunta e, se a resposta for sim, copia, reabre a cópia e encerra este
  /// processo — sem voltar a quem chamou.
  static func offerMoveIfNeeded() {
    #if DEBUG
      return
    #else
      let bundle = Bundle.main.bundleURL.resolvingSymlinksInPath()
      guard !isInstalled(bundle),
            !bundle.path.contains("/Build/Products/"),
            !UserDefaults.standard.bool(forKey: declinedKey)
      else { return }

      NSApp.activate(ignoringOtherApps: true)

      let alert = NSAlert()
      alert.messageText = "Mover o Evergreen para Aplicativos?"
      alert.informativeText =
        "Ele está abrindo de fora da pasta Aplicativos, de dentro da imagem de "
        + "disco ou dos Downloads. Dali, o macOS não guarda o “Iniciar com o "
        + "macOS” no lugar certo."
      alert.addButton(withTitle: "Mover para Aplicativos")
      alert.addButton(withTitle: "Agora não")
      alert.showsSuppressionButton = true
      alert.suppressionButton?.title = "Não perguntar de novo"

      let response = alert.runModal()
      if alert.suppressionButton?.state == .on {
        UserDefaults.standard.set(true, forKey: declinedKey)
      }
      guard response == .alertFirstButtonReturn else { return }

      move(bundle)
    #endif
  }

  /// Só `/Applications`, em qualquer profundidade — a mesma régua do
  /// `LaunchAtLoginChannel`, que só adota o item de início ali. Aceitar
  /// `~/Applications` aqui deixaria quem instalou lá sem a oferta e sem o item.
  private static func isInstalled(_ bundle: URL) -> Bool {
    bundle.path.hasPrefix("/Applications/")
  }

  private static func move(_ source: URL) {
    let fileManager = FileManager.default
    let applications = URL(fileURLWithPath: "/Applications")
    let destination = applications.appendingPathComponent(source.lastPathComponent)
    // No mesmo volume do destino, para a troca no fim ser um renomear, e com
    // ponto na frente para o Finder não mostrar a cópia pela metade.
    let staging = applications.appendingPathComponent(".\(source.lastPathComponent).moving")

    // Uma cópia instalada aberta seguraria o bundle trocado; e duas instâncias
    // na barra de menus disputariam os atalhos globais.
    let others = Bundle.main.bundleIdentifier.map {
      NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        .filter { $0.processIdentifier != getpid() }
    } ?? []
    others.forEach { $0.terminate() }

    // A instalação antiga só sai depois de a cópia nova estar inteira: uma
    // cópia que falha no meio (disco cheio, sem permissão) não pode deixar a
    // pessoa sem app nenhum.
    do {
      try? fileManager.removeItem(at: staging)
      try fileManager.copyItem(at: source, to: staging)
      // A cópia herda a quarentena do download, e uma cópia em quarentena que
      // não foi movida pelo Finder é executada de novo de um lugar
      // temporário — seria pedir para mover outra vez.
      run("/usr/bin/xattr", ["-d", "-r", "com.apple.quarantine", staging.path])

      if fileManager.fileExists(atPath: destination.path) {
        _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
      } else {
        try fileManager.moveItem(at: staging, to: destination)
      }
    } catch {
      try? fileManager.removeItem(at: staging)
      let alert = NSAlert()
      alert.messageText = "Não deu para mover o Evergreen."
      alert.informativeText =
        "Arraste o app para a pasta Aplicativos pelo Finder e abra de lá."
      alert.runModal()
      return
    }

    // Fora da imagem de disco e da cópia temporária, mover é mover: o original
    // vai para o Lixo. Dentro delas não há o que apagar — a imagem é só de
    // leitura, e o caminho temporário não é o que a pessoa vê no Finder (não
    // há API pública que devolva o de verdade).
    let path = source.path
    if !path.hasPrefix("/Volumes/") && !path.contains("/AppTranslocation/") {
      try? fileManager.trashItem(at: source, resultingItemURL: nil)
    }

    // Reabre só depois que este processo e as instâncias encerradas acima
    // saírem, senão duas cópias ficariam de pé ao mesmo tempo, com os mesmos
    // atalhos.
    let pids = ([getpid()] + others.map(\.processIdentifier)).map(String.init)
    let relaunch = Process()
    relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
    relaunch.arguments = [
      "-c",
      "for p in \(pids.joined(separator: " ")); do "
        + "while kill -0 $p 2>/dev/null; do sleep 0.2; done; done; "
        + "/usr/bin/open \"$0\"",
      destination.path,
    ]
    try? relaunch.run()
    exit(0)
  }

  private static func run(_ executable: String, _ arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return }
    process.waitUntilExit()
  }
}

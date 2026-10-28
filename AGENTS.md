# Project context

Evergreen é uma suíte pessoal de produtividade para macOS, feita como agente de
barra de menus (`LSUIElement`) — sem janela ao iniciar, sem ícone no Dock. Tudo
roda localmente, nada é enviado para a internet. São sete módulos: Pin
(gerenciador de área de transferência, `⌘⇧C`), Focus (cronômetro de foco com
registro de atividade, `⌘⇧F`), Leaf (parede de até nove anotações curtas,
`⌘⇧D`), Awake (mantém a tela acesa por um prazo, `⌘⇧X`), Echo (grava,
transcreve e resume reuniões, `⌘⇧E`), Nest (prateleira que junta arquivos de
várias pastas e manda todos para uma só, `⌘⇧R`, ou chacoalhando o arquivo no
meio do arraste, ou parando com ele no notch) e
Track (reconstrói o dia a partir do que os outros gravaram — só tela do Hub,
sem atalho global e sem painel).

Domain: produtividade pessoal / utilitário de sistema para macOS.

**Código aberto, sob a GPL-3.0** ([LICENSE](LICENSE)), num repositório público:
nada que seja de uma pessoa — caminho de máquina, e-mail, credencial, nome de
outro projeto — entra no repositório, nem em comentário. Contribuição de fora
chega por fork e PR para a `validation`; por isso o `version-bump.yml` usa
`pull_request_target` (num fork, o `pull_request` só lê e o bump não subiria),
e é seguro só enquanto ele fizer checkout da `validation` pós-merge, nunca do
head da PR. A armadilha do `pull_request_target`: ele roda o **arquivo do
workflow que está na `main`**, não o da `validation` — mudança no
`version-bump.yml` só vale depois da promoção. Por isso o que dá para pôr no
`bump_version` (que sai do checkout da `validation`) mora nele: o título da PR
para o CHANGELOG ele mesmo lê do evento.

**A [PRIVACY.md](PRIVACY.md) é uma promessa, e muda antes do código.** Ela diz
o que cada módulo guarda, onde, por quanto tempo, e o que sai do app (o
download do modelo de vozes, o modelo de transcrição que o macOS baixa a
pedido do Echo, o `127.0.0.1` do LM Studio e a procura diária por versão nova
do Sparkle). Módulo que passe a guardar outra coisa, prazo que mude, permissão
nova ou qualquer conexão nova entra nela na mesma PR. **E a mudança na política
nunca é silenciosa**: quem mexe nela — gente ou agente — avisa, na conversa e
na descrição da PR, o que foi **acrescentado** ou **alterado** e por quê, e
atualiza a data de "Última atualização" no topo dela. É o que deixa quem mantém
decidir se a promessa nova é uma que se quer fazer, em vez de descobri-la
depois no repositório. Termos de uso não
existem de propósito: a GPL-3.0 já é o acordo, com o "sem garantia" dela. As
licenças de quem o Evergreen usa aparecem dentro do app (Aplicativo → Sobre →
Licenças, `LicenseCatalog`); as de pacote Dart entram sozinhas, e as de pacote
Swift (FluidAudio, HotKey, Sparkle) moram em `assets/licenses/` — pacote Swift novo
traz a dele para lá. Os PDFs da licença e da política saem do
`./scripts/documentos`, pelo LibreOffice, e não são commitados.

**O escopo fechou na V1: o Evergreen são os sete módulos acima.** Daqui em
diante entra correção, ajuste do que existe e o que o sistema exigir — não
módulo novo. A única ideia que ainda pode entrar é **bloquear o teclado para
limpar** ([bloquear-teclado-para-limpar.md](docs/Ideis%20projeto/bloquear-teclado-para-limpar.md)),
pequena e perto do Awake. As propostas de módulo que existiam — Snap, captura
de tela ([snap-captura-de-tela.md](docs/Ideis%20projeto/snap-captura-de-tela.md)),
Frame, imagem local ([frame-imagem-local.md](docs/Ideis%20projeto/frame-imagem-local.md)),
e esconder ícones da barra de menus
([hide-icones-barra-menu.md](docs/Ideis%20projeto/hide-icones-barra-menu.md)) —
estão **descartadas**: os documentos ficam pelo raciocínio, não como fila. O
mesmo vale para o que o README chama de limites (o Pin sem arquivos e sem rich
text, os fixados sem arrastar). A visão de origem (filosofia, referências, a
lista de módulos sonhados) está em
[docs/Ideis projeto/ideia.md](docs/Ideis%20projeto/ideia.md), e é histórico.

# Stack

- **Flutter** 3.47 (Dart 3.13; a linguagem do projeto segue em `^3.11.5`, no
  `environment`) — app desktop nativo, sem backend. **O
  Flutter do CI (`ci.yml`) é o mesmo da máquina que builda**: o `pubspec.lock`
  é resolvido nela, e um CI mais velho falha no `flutter pub get` da promoção
  sem dizer qual PR subiu o piso.
- **O piso é macOS 14, e foi o FluidAudio que o pediu.** O Xcode não linka um
  pacote cujo piso é maior que o do alvo, e o pacote que separa as vozes do
  Echo declara 14. Antes era 12, e esse quem escolheu foi a ferramenta: o
  `macos_deployment_target_migration` do Flutter reescreve tudo abaixo de
  `12.0` no primeiro build. O 14 fica de pé porque está acima do que ela
  reescreve. Trocar o piso é no `project.pbxproj`, nas três configurações —
  e, se algum dia um `Package.swift` nosso declarar piso (o do
  `hotkey_manager_macos` vendorizado declara 10.15), ele não pode passar do
  alvo. O custo é pequeno: o macOS 14 é de 2023, e o Echo já exigia o 26.
- **Só Apple Silicon — o binário não tem a fatia Intel (x86_64).** A fatia
  Intel saía no binário universal sem ninguém nunca a ter rodado; o que o app
  faz com IA local (o resumo do Echo e o parágrafo do Track, pelo Apple
  Intelligence) não existe em Mac Intel; e o macOS 26 é o último com Intel. O
  piso real é, portanto, **macOS 14 em Apple Silicon**. Vale em dois lugares:
  `enable-macos-arm64-only` no `flutter: config:` do `pubspec.yaml` — a forma
  oficial da ferramenta, que vai virar o padrão dela, e que pelo `flutter
  config` da máquina não viajaria com o repositório — e `EXCLUDED_ARCHS =
  x86_64` no `macos/Runner/Configs/Release.xcconfig`, para quem builda pelo
  Xcode direto. Conferir com `lipo -archs` no `Evergreen` do build de release:
  só `arm64`.
- **A build é só Swift Package Manager — não há CocoaPods, nem `Podfile`.** O
  último plugin que o segurava era o `hotkey_manager_macos`, cuja 0.2.0 — a
  última publicada — só traz `.podspec`; o suporte a SPM tem de vir num
  `Package.swift` **dentro do plugin**, e o Flutter prometia transformar o aviso
  de cada build em erro, o que pararia todo atalho global. Por isso ele está
  **vendorizado** em `packages/hotkey_manager_macos/`, puxado pelo
  `dependency_overrides` do `pubspec.yaml`: o Swift é o do autor (mais um
  `import Cocoa`, que no CocoaPods chegava pelo módulo e no SPM tem de estar no
  arquivo), e o `Package.swift` é nosso, com o `HotKey` travado em versão
  exata. Plugin novo que venha só com `.podspec` traz o CocoaPods de volta para
  o projeto inteiro — vendorize do mesmo jeito em vez de aceitar. O SPM fica
  ligado pelo `pubspec.yaml` (`flutter: config:`), não pelo `flutter config` de
  cada máquina. Detalhes:
  [packages/hotkey_manager_macos/README.md](packages/hotkey_manager_macos/README.md).
  Fora dos plugins, há **um pacote SPM nosso**: o FluidAudio, referenciado
  direto no `project.pbxproj` do `Runner` (`XCRemoteSwiftPackageReference`,
  versão exata), ao lado do `FlutterGeneratedPluginSwiftPackage`. Pacote novo
  entra do mesmo jeito, em seis lugares: a `XCRemoteSwiftPackageReference`, o
  `XCSwiftPackageProductDependency`, o `PBXBuildFile`, a fase `Frameworks`, o
  `packageProductDependencies` do alvo `Runner` e o `packageReferences` do
  projeto. A versão travada vai no `Package.resolved` do `Runner.xcworkspace`,
  que é o que o `flutter build` lê.
  O dia de desfazer a cópia é o dia em que o pub.dev publicar um
  `hotkey_manager_macos` com `Package.swift` (o `desktop_multi_window` saiu da
  mesma lista assim, na 0.3.1): apague a pasta e o override. Vale reconferir de
  tempos em tempos com `flutter pub outdated`. **O CocoaPods volta sozinho**, e
  sem erro: um `flutter pub get` que o Flutter rode sem achar o Xcode (o
  automático do editor já fez isso uma vez) recria `macos/Podfile`, os
  `#include?` de Pods nos xcconfig e a integração no `project.pbxproj`, e o
  build seguinte roda `pod install` e passa. Quem pega é
  `test/tools/no_cocoapods_test.dart`; o conserto é apagar `Podfile`,
  `Podfile.lock` e `Pods/` e restaurar os arquivos do Xcode pelo git.
- **Duas dependências diretas ficam atrás da última versão, e não por
  descuido.** O `screen_retriever` (0.2.x) é o que o `window_manager` 0.5.2 — o
  último — exige; o `package_info_plus` (9.x) é o teto que o `launch_at_startup`
  0.5.1 — o último — permite, porque o `win32_registry` dele pede o `win32` 5
  (só de Windows) e o `package_info_plus` 10 exige o 6. Os dois sobem quando
  quem os segura subir.
- **Riverpod** (`flutter_riverpod`) — gerenciamento de estado, padrão MVVM.
- **SQLite direto** (`sqlite3` via native assets) — não usa Isar (descartado:
  sem manutenção ativa, codegen quebra no Dart 3.11); acesso isolado atrás de
  `ClipboardRepository`. Ver [docs/Ideis projeto/](docs/Ideis%20projeto/) para
  decisões de arquitetura descartadas.
- **`desktop_multi_window`** — o Hub roda em um engine Flutter próprio;
  sub-janelas nascem sem plugins, por isso o Runner nativo precisa registrar
  callback de criação (ver Convenções). A janela flutuante (janela 0) é
  compartilhada por Pin, Focus e Awake — ver
  [docs/Ideis projeto/focus-janela-compartilhada.md](docs/Ideis%20projeto/focus-janela-compartilhada.md).
- **`window_manager`, `tray_manager`, `hotkey_manager`, `screen_retriever`** —
  janela flutuante, ícone da barra de menus, atalho global.
- **O `tray_manager` é usado pela API nativa, nunca pelo `legacy.dart`.** A
  partir da 0.7 ele é uma casca do `nativeapi` (C++ compilado do fonte por
  build hook, como o `sqlite3`, e chamado por FFI — não é plugin, não aparece
  no `GeneratedPluginRegistrant` nem no SPM). A API da 0.5 sobrevive no
  `legacy.dart` como ponte `@Deprecated`, com remoção anunciada. Duas regras do
  `MenuBarService`, as duas de quebra silenciosa: **o `Menu` do ícone é um
  objeto só, entregue uma vez e nunca trocado** — o `setContextMenu` do
  `nativeapi` tira do menu antigo o listener que devolve o clique ao ícone, e
  trocar com o menu aberto (o minuto do Awake vira com ele na tela) deixa o
  ícone preso a um menu morto até reiniciar; rótulo novo renomeia o item, lista
  nova esvazia e repovoa o mesmo menu. E o `TrayIcon` fica num campo, porque o
  wrapper que o coletor de lixo leva solta o objeto nativo e o ícone some da
  barra. O clique esquerdo abre o menu pelo gatilho nativo, que só funciona
  porque o ícone tem um listener (o do clique direito). Diferenças da 0.5 que
  ficaram: o menu abre no soltar do botão, não no apertar, e um clique logo
  depois de fechar pode virar duplo e não abrir. O que o menu mostra mora em
  `MenuBarContent`, que é puro e testado; o serviço só o traduz para objetos
  nativos.
- **`launch_at_startup`** — "iniciar com o macOS", via canal nativo próprio
  (`SMAppService`), não o pacote nativo sugerido pela lib.
- **`IOPMAssertionCreateWithName`** (nativo, canal `sleep_assertion`) — a trava
  do Awake, em dois modos: `PreventUserIdleDisplaySleep` (a tela) e
  `PreventUserIdleSystemSleep` (só o sistema, com a tela livre para apagar). Era
  `wakelock_plus`, que registra sempre a de tela e não expõe escolha — e manter
  a tela acesa a noite inteira para uma compilação terminar gasta a tela para
  resolver um problema que não é dela. Com o Swift necessário para um dos modos,
  dois mecanismos vivos para "não deixar dormir" seria pior que escrever os dois
  no mesmo lugar. Ver
  [docs/Ideis projeto/awake-trava-nativa.md](docs/Ideis%20projeto/awake-trava-nativa.md).
- **`ScreenCaptureKit` + `Speech` + `FoundationModels`** (nativo, macOS 26) — o
  Echo. Captura de áudio em duas faixas, transcrição e resumo local, sem
  equivalente em Flutter puro; o porquê de cada um está em
  [docs/Ideis projeto/echo-transcricao.md](docs/Ideis%20projeto/echo-transcricao.md).
  Exige macOS 26 e é o único módulo com piso de sistema próprio — o canal
  responde `unsupported_os` abaixo disso, e o resto do app segue no 14.0.
  **As vozes do outro lado são separadas pelo FluidAudio** (`EchoDiarizer`,
  pyannote + WeSpeaker + VBx em CoreML), só na faixa do computador e depois da
  reunião. Quem casa as vozes com as palavras é o `VoiceSeparation`, em Dart.
  A faixa diz o lado, e isso é certeza; a voz (`MeetingSegment.voice`, que vira
  "Pessoa 1", "Pessoa 2") é palpite, e por isso mora num campo à parte. É
  enfeite: falhou, a reunião sai com o outro lado em "Reunião", sem aviso. O
  modelo é baixado do Hugging Face uma vez (as outras saídas — o modelo de
  transcrição, que quem baixa é o macOS a pedido do Echo, e a procura diária
  por versão nova do Sparkle — estão na [PRIVACY.md](PRIVACY.md); o
  `127.0.0.1` do LM Studio não sai da máquina). Ao vivo não separa. Ver
  [docs/Ideis projeto/echo-separacao-de-vozes.md](docs/Ideis%20projeto/echo-separacao-de-vozes.md).
  **O microfone é aberto cru, nunca com `setVoiceProcessingEnabled`.** O
  processamento de voz não fica dentro do Echo: enquanto ele está ligado, o
  microfone interno entrega as cápsulas cruas a **todos** os apps (a sua voz
  chegava "longe" na reunião) e o som dos outros abaixa. Já entrou e saiu duas
  vezes. O que ele dava ao Echo é refeito só na faixa dele: escolher uma
  cápsula em vez de somar, e ganho quando a entrada vem em vários canais
  (`EchoMicGain`). E o `AVAudioEngine` **para sozinho** quando o microfone muda
  de formato no meio da reunião (o app da chamada ligando o processamento dele
  basta); o `EchoRecorder` o religa num motor novo, só se a gravação ainda for a
  mesma (`micGeneration`), e o buraco do religamento vira silêncio na faixa —
  senão a sua voz se adianta em relação à reunião. **As duas faixas contam do
  mesmo zero** e as duas preenchem buraco pelo relógio de cada bloco; a captura
  do computador é religada quando a saída de som muda ou a `SCStream` cai, e um
  vigia (`EchoRecorder.watch`) religa a faixa que passar segundos sem bloco —
  foi assim que uma troca para o fone deixou meia hora muda. **Microfone
  Bluetooth não é aberto quando há um embutido** (`EchoAudioDevices`): abrir a
  entrada do AirPods força o fone para o perfil de chamada para o Mac inteiro, e
  o som da reunião engasga. **O eco da caixa sai no som, depois da reunião**: o
  `EchoCanceller` limpa a faixa do microfone no `stop`, usando a do computador
  como referência — atraso numa reta (relógios de aparelhos diferentes
  derivam), e cada quadro de 16 ms ou desce ao fundo da sala ou passa intacto.
  Nunca toca no microfone ao vivo; o `CrossTalkFilter` ficou de rede. Ver
  [docs/Ideis projeto/echo-transcricao.md](docs/Ideis%20projeto/echo-transcricao.md).
  Durante a gravação o canal **sobe** dois avisos para a janela flutuante: o
  texto ao vivo (só com a preferência ligada) e o `onLevels`, que é o espectro
  de cada faixa dez vezes por segundo: uma FFT (`Accelerate`/`vDSP`) sobre os
  últimos 32 ms, agregada em dez bandas por oitava entre 110 Hz e 6 kHz. É o
  que o painel desenha como equalizador, e é medida, nunca animação — um pico
  só por faixa daria dez barras da mesma altura. **Pausar não para a captura**: os blocos continuam
  chegando e são descartados, então o trecho pausado não entra no arquivo nem
  na duração (o `stop` desconta o tempo pausado). Parar e recomeçar a
  `SCStream` criaria um segundo arquivo por faixa e faria a transcrição
  remontar duas gravações como se fossem uma.
  **O áudio da reunião fica 14 dias**, numa cópia AAC mono de uma faixa só na
  pasta `Reuniões` do aplicativo (`EchoAudioStore`), ou até a reunião sair pelo
  teto — o que vier primeiro; a estrela guarda os dois. Fora do banco e, por
  isso, **fora do backup**. Quem tira do disco é uma varredura só
  (`EchoAudioJanitor`): arquivo que nenhuma linha quer é lixo, então apagar a
  reunião por qualquer caminho não precisa lembrar do áudio. O player é
  `AVAudioPlayer` num canal próprio (`EchoPlayerChannel.swift`), um por engine:
  fechar o Hub para o áudio. A transcrição guarda o relógio de cada palavra
  (`MeetingWord`): tudo o que já foi dito fica aceso, cumulativo, até a palavra
  que toca. Ver
  [docs/Ideis projeto/echo-audio-da-reuniao.md](docs/Ideis%20projeto/echo-audio-da-reuniao.md).
- **`QLThumbnailGenerator` + `NSOpenPanel` + destino de arraste** (nativo,
  canal `nest`) — o Nest. Quem recebe o arraste do Finder é o **delegate da
  janela**, nunca a janela nem uma view invisível: `NSWindow` não implementa
  `NSDraggingDestination`, e o AppKit acha uma view pelo mesmo `hitTest` do
  mouse — as duas alternativas falham em silêncio, com o arquivo caindo e nada
  acontecendo. A miniatura é o mecanismo das prévias do Finder, e arrastar a
  prateleira **para fora** é uma `NSDraggingSession` da view do Flutter —
  nenhum dos três tem equivalente em Flutter puro. A saída tem dois caminhos:
  as pastas favoritas (`⌘1..⌘9`, com desfazer, porque quem copia somos nós) e
  o arraste para qualquer lugar (sem desfazer: copiando, quem copia é o
  destino; movendo, o arraste é uma promessa de arquivo que nós cumprimos,
  porque o destino lê o `⌥` sozinho e um `.move` declarado nascia proibido).
  O `NestDrop` recusa o arraste cuja origem é a própria prateleira — sem essa
  recusa o arquivo atravessaria o painel e cairia na janela atrás dele. A
  outra porta é **chacoalhar o arquivo** (`NestDragMonitor`), e a regra dela
  é *perguntar, nunca escutar*: durante uma sessão de arraste o AppKit não
  entrega movimento de mouse a monitor nenhum, então quem responde é
  `NSEvent.mouseLocation` e `NSEvent.pressedMouseButtons`, que são
  propriedades e não custam permissão. O único evento apanhado é o botão
  descendo, que acontece antes do arraste. Só dispara com arquivo na mão
  (`NSPasteboard(name: .drag)`, tipo **e** `changeCount`), e é a única porta
  em que o painel vai até o cursor em vez do contrário
  (`OverlayWindow.positionForCursor`). A terceira porta é **levar o arquivo
  ao notch** (na borda de cima dispara na hora, porque o Mission Control abre
  ali — salvo com outro monitor encostado acima; na faixa logo abaixo, com
  150 ms de cursor parado): o mesmo relógio do chacoalhar pergunta se o cursor
  está no recorte, e quem recebe o arquivo continua sendo a janela 0, posta
  com o topo no topo da tela (`OverlayWindowChannel.positionAtNotch`). O
  recorte já tinha sido tentado com **uma janela própria recebendo o
  arraste**, e saiu porque ela nunca recebeu nada — esta porta não tem janela
  própria. Ver
  [docs/Ideis projeto/nest-prateleira-de-arquivos.md](docs/Ideis%20projeto/nest-prateleira-de-arquivos.md)
  e [docs/Ideis projeto/notch.md](docs/Ideis%20projeto/notch.md). **Com notch,
  a pilha mora nele**: saindo do recorte o painel do Nest é a pilha
  (`NestNotchPile`), e não a prateleira — quem decide o formato é a âncora do
  notch —, e fechar o Nest com arquivos nunca o faz sumir: esconder a janela
  já traz a bandeja e a contagem para a ilha. O `⌘⇧R` com arquivos mostra a
  pilha pelo notch; vazio, a prateleira de sempre.
- **`NSPanel` nativa sem engine** (`NotchIsland.swift`, canal `notch_island`)
  — a ilha do notch: o Echo gravando e o Focus contando aparecem em volta do
  recorte, e abrem com o mouse em cima para pausar e parar. **É a única
  exceção à regra da janela 0**, e é exceção porque não tem Flutter dentro: a
  regra protege engine e superfície viva, e a janela 0 não serve por ser
  compartilhada (abrir o Pin a tiraria do notch no meio da reunião). O Dart
  manda cada `NotchActivity` pronta — texto, relógio formatado, botões — e as
  cores dos tokens; o Swift só desenha — com as medidas dele mesmo, que são
  do recorte e da barra de menus, e não da escala do app (a única exceção à
  regra dos literais). Além dos botões, a ilha devolve uma coisa só: qual
  módulo ela está mostrando (`onShown`), para o relógio dele sair do título
  da barra de menus (`MenuBarContent.inNotch`) — só com uma tela, porque a
  barra aparece em todas e a ilha só numa. **Sem recorte, nada disto existe**:
  nem a ilha, nem a porta do Nest, nem as linhas de preferência. Ver
  [docs/Ideis projeto/notch.md](docs/Ideis%20projeto/notch.md).
- **A distribuição é um `.dmg` assinado com um Developer ID e notarizado** —
  `./scripts/release`, que acha o certificado e a credencial no chaveiro de
  quem publica; nada disso mora no repositório. O runtime
  endurecido é obrigatório para notarizar, e ele **nega o que não está
  declarado sem dar erro**: o microfone do Echo só funciona por causa do
  `com.apple.security.device.audio-input` no `Release.entitlements`. Recurso
  nativo novo que dependa de exceção do runtime (JIT, biblioteca de outro
  time, Apple Events) precisa entrar ali, e quem pega é instalar com o
  `run_build_copy`, que assina com o mesmo runtime. Na primeira abertura fora
  de Aplicativos (de dentro do `.dmg`, dos Downloads), o `AppLocationGuard`
  oferece mover o app, e a apresentação de boas-vindas pendente abre o Hub
  mesmo com "Abrir minimizado" — sem isso quem instalava não via nada. Ver
  [docs/Ideis projeto/instalador-dmg.md](docs/Ideis%20projeto/instalador-dmg.md).
- **O Sparkle atualiza o app** (SPM direto no `Runner`, como o FluidAudio;
  `UpdaterChannel.swift`). Três regras. **Quem o Sparkle compara é o build**
  (`sparkle:version` contra o `CFBundleVersion`), não o semver — por isso o
  build só cresce, uma vez por publicação, e o `require-build-bump.yml` é o
  que garante que uma versão nova seja vista como nova. **O feed é o
  `appcast.xml` anexado ao release** (`releases/latest/download/appcast.xml`),
  que o `./scripts/release` gera e assina com a chave EdDSA do chaveiro de
  quem publica; a pública mora no `Info.plist` (`SUPublicEDKey`). Perder a
  chave privada é não conseguir mais atualizar quem já instalou — ela tem
  cópia de segurança fora da máquina. E **a preferência é do Sparkle**
  (`automaticallyChecksForUpdates`), não do `AppSettings`: uma cópia nossa
  seria uma segunda fonte para a pergunta que decide se algo sai do app. O
  atualizador é um por processo, nasce com a janela 0 e não existe em build de
  desenvolvimento (`#if DEBUG`). **A interface é nossa** (`UpdateDriver`, um
  `SPUUserDriver` próprio): a versão nova vira item no menu da barra, tecla
  com bolinha no botão "Aplicativo" e o cartão `HubUpdate` por cima do Hub
  (pergunta de sim ou não, então fecha ao clicar fora), nunca a janela do
  Sparkle, que tiraria o foco de quem está trabalhando. Os executáveis de dentro do `Sparkle.framework`
  (XPC, `Autoupdate`, `Updater.app`) são assinados um a um no `release`. Ver
  [docs/Ideis projeto/atualizacao-sparkle.md](docs/Ideis%20projeto/atualizacao-sparkle.md).
- **`shared_preferences`, `path_provider`, `intl`, `package_info_plus`** —
  persistência simples, paths do sistema, formatação de data/hora e a versão
  que o rodapé da sidebar do Hub mostra (`lib/core/app_info.dart`).

# Project conventions

- MVVM com Riverpod. Regra de ouro: **nenhuma lógica de negócio em widget** —
  fica em ViewModels (`Notifier`).
- Estrutura por feature em `lib/features/<modulo>/{data,models,presentation}`;
  `presentation` se divide em `viewmodels/`, `views/`, `widgets/`.
- **Todo módulo se liga e se desliga, e o atalho global de cada um é
  regravável.** As duas preferências moram no mesmo lugar
  (`ModuleSettingsRepository`, chaves `module.<id>.enabled` e
  `shortcut.<slot>`) e só o que **difere do padrão** é gravado: módulo ligado
  não tem chave e atalho intocado também não — é o que faz um módulo novo
  nascer ligado, e o que faz uma versão que troque a tecla de fábrica alcançar
  quem nunca gravou nada sem atropelar quem gravou. A chave usa
  `EvergreenModule.id`, nunca o `name`, que **neste enum é o nome de
  exibição**. Desligar tem quatro efeitos, e os quatro juntos: some do menu da
  barra, o atalho não é registrado, a tela do módulo fica apagada (`ModuleGate`,
  montado pelo Hub em `_content` — a tela do módulo não sabe disso) e o que
  rodava para (o Pin deixa de capturar a área de transferência, o Awake solta a
  trava, o Nest desliga o chacoalhar). O que estava em curso é encerrado
  **guardando** — sessão do Focus para o histórico, reunião do Echo transcrita.
  Nada é apagado, e o módulo desligado **continua na barra lateral**: sumir
  deixaria o interruptor de religar dentro da tela que sumiu. O atalho do Hub
  nunca é desregistrado, porque é a porta para religar o resto. Ver `ux.md` na
  skill de design.
- **Combinação de atalho tem uma fonte de verdade só**: o
  `GlobalShortcutSlot`, que guarda o padrão, e a preferência por cima dele.
  Havia três — o `HotKey`, a lista de key-caps da tela e um texto solto no item
  do menu da barra —, e foi por isso que o Nest ficou meses com `⌘⇧S` escrito
  num lugar e outra tecla registrada no sistema. Quem valida é
  `ShortcutRules`, que é puro: piso de duas modificadoras com `⌘` ou `⌃`, a
  lista curta do que o macOS toma de todo mundo, e conflito conferido contra os
  sete slots — inclusive os de módulos desligados, cuja tecla continua
  reservada. **E ela é impressa em dois lugares na tela de um módulo, não em
  quatro**: a barra lateral, que é o mapa do teclado, e a seção "Atalho
  global", que é onde se troca. Estava também ao lado do interruptor mestre e
  na faixa de estado — na tela do Leaf a mesma combinação aparecia quatro vezes
  de uma vez, e as duas cópias que saíram eram as que não faziam nada com ela.
  Fora da tela do módulo continuam valendo o menu da barra (que ensina o atalho
  no item que ele dispara) e o mapa de "Todos os atalhos num lugar", na tela do
  aplicativo. Gravar **suspende os atalhos do sistema** enquanto a tela escuta,
  senão apertar `⌘⇧C` para gravar abre o painel do Pin por cima das
  preferências.
- **Preferência decidida no Hub e aplicada na janela 0 atravessa o
  `ModuleSettingsHost`** — canal unidirecional, registrado uma vez só na janela
  0, mesmo arranjo (e mesmas razões) do `EchoSummaryHost`. Escrever no disco não
  avisa ninguém: sem a ponte, desligar o Echo só valeria no lançamento
  seguinte. Quem chama é o `ModuleSettingsNotifier`, que é **interface** e vem
  por provider — no relógio falso do teste de widget a resposta do canal nunca
  chega, e a tela que grava um atalho travaria esperando para sempre (a mesma
  armadilha do `NestFileService`).
- **Bandeira de build mora em `lib/shared/feature_flags.dart`**, e é `const`:
  quem mexe é quem builda, não quem usa. Bandeira serve para **desligar algo
  pronto**, nunca para esconder algo pela metade — o código atrás dela continua
  compilando, nos testes e nos goldens, senão o dia em que ela voltar a `true`
  entrega uma ruína. Teste de bandeira passa **nos dois estados** (`skip:
  !FeatureFlags.x` no que só existe de um lado); teste que só passa ligada
  obriga a mexer na suíte para desligar a funcionalidade, e aí ninguém desliga.
  Hoje existem duas, as duas em `true`: `intro` (a abertura animada do Hub) e
  `onboarding` (a apresentação de boas-vindas). Cada uma decide num ponto só —
  `HubIntroViewModel.build` e `OnboardingViewModel.build` —, e nenhuma grava o
  "já vi" quando desligada: religar apresenta quem nunca foi apresentado, em vez
  de ter consumido a vez dele calado. Houve uma terceira, `themes`, e ela saiu
  junto com o tema `apple`: uma bandeira existe para desligar algo pronto, e o
  que ela desligava deixou de existir.
- **O app é dark-only e tem uma pele só, a "Estufa" — e widget nenhum guarda um
  valor visual.** Tudo vem do tema pelo contexto (`context.eg.colors.accent`,
  `context.eg.text.body`, `context.eg.shapes.radiusCard`); os literais existem
  só em `lib/core/design/themes/evergreen_tokens.dart`. Todo campo dos tokens é
  `required`, então é o compilador que cobra o papel que falta. Houve um segundo
  tema, o `apple`, e ele saiu: a escolha de aparência estava desligada por
  bandeira desde que nasceu, e o segundo arquivo dobrava o custo de cada papel
  novo. Se voltar, volta como um `EgPalette` completo — nunca como `if`s
  espalhados. A especificação da Estufa (a regra da não-duplicidade: o painel
  opera, o Hub configura e lê) é
  [docs/redesign-estufa.md](docs/redesign-estufa.md); o andamento da execução
  ficou em [docs/redesign-estufa-progresso.md](docs/redesign-estufa-progresso.md),
  e o "antes", que **não** descreve o app de hoje, em
  [docs/brief-redesign-visual-v2.md](docs/brief-redesign-visual-v2.md).
- **O canto é contínuo acima de 14** (`EgSquircle.shape`): o macOS não arredonda
  com arco de círculo, e era daí que vinha o "tudo muito quadrado". Superfície
  interativa desenha com `ShapeDecoration`, não `BoxDecoration`. Abaixo do
  limiar o arco fica, por ser mais barato.
- **A janela do Hub é fixa em 980×680 e não redimensiona.** É a largura em que
  o cartão de preferência foi desenhado, e uma janela que encolhe é uma tela
  que ninguém desenhou. Tirar `.resizable` não impede a região de leitura de
  crescer a janela pelo `setFrame`.
- Espaçamento, tamanho de ícone e **durações** seguem estáticos em
  `app_metrics.dart`, e isso é decisão: o ritmo é do produto, não da pele — um
  app que fica mais lento ao trocar de aparência estaria mentindo sobre o que a
  troca faz. Do movimento, só a curva é do tema.
- **"Reduzir movimento" do macOS é decidido num ponto só no Dart**:
  `AppDurations.movement(context, duração)`, que devolve zero com a preferência
  ligada, e `AppDurations.reduced(context)` para quem precisa pular uma cena
  inteira (a abertura do Hub, a pílula do notch). Widget nenhum lê
  `MediaQuery.disableAnimationsOf` por conta própria. Só **deslocamento** —
  posição, tamanho, rolagem — vira instantâneo; troca de cor e de opacidade
  segue com a duração dela, porque é o que o `accessibility.md` da skill de
  design manda pôr no lugar do movimento. O equalizador do Echo também segue:
  é medida, não enfeite. Duas armadilhas: `ScrollController.animateTo` com
  `Duration.zero` dispara asserção — com movimento reduzido é `jumpTo`
  (`Scrollable.ensureVisible` aceita zero) —; e o quadro de espera do
  `OverlayWindow.hide` não é animação e nunca encurta. O que o AppKit anima
  pergunta do lado nativo (`accessibilityDisplayShouldReduceMotion`): a janela
  do Hub crescendo para a região de leitura (`HubWindowChannel.setDetailWidth`)
  e a ilha do notch.
- `copyWith` em estilo de texto vale só para cor; peso e tamanho são degraus da
  escala, e degrau que falta entra na `EgTypeScale` com nome.
- Componentes compartilhados usam prefixo `Eg` em `lib/shared/widgets/`.
  Ícones são paths customizados (`EgIcon`), não Material Icons.
- **A marca do Evergreen é um desenho só**, o canivete de
  `lib/shared/widgets/eg_brand_mark.dart`. A abertura do Hub, o ícone do
  aplicativo, o da barra de menus e o glifo da barra lateral saem todos dele —
  os `.png` são **gerados** por
  `flutter test --run-skipped -t assets test/tools/brand_assets_test.dart`, e
  não existe `.svg` ao lado. Havia um, e foi por causa dele que o pinheiro
  continuou no ícone do aplicativo e na barra de menus depois de a marca do Hub
  já ser o canivete: dois desenhos, e só um trocado.
- **Tela de preferência tem ordem fixa de tópicos**: o que aconteceu (a lista do
  módulo) → o que ele faz (interruptores no topo de cada tópico, depois
  seletores, campos de texto por último) → limites e ações destrutivas → atalho
  global → permissões. A pilha é a `EgSettingsPage` — **uma coluna, sempre**, com
  o `banner` acima dela; foram duas, e o assunto seguinte ficava ao lado do
  atual em vez de abaixo, o que trocava a leitura de cima a baixo por um
  vaivém. O cartão é o `EgSettingsCard`, que dá o respiro e desenha os
  divisores — a linha não decide sozinha se tem divisor embaixo. O interruptor
  mestre **não** é a primeira seção: ele vive no `EgScreenHeader`, como pílula
  ao lado do título — e é a **única** coisa à direita do título, porque a tecla
  do módulo saiu de lá (ver a regra do atalho). Módulo com mais de um assunto ganha abas no
  mesmo cabeçalho (Pin, Focus, Echo, Nest); módulo de um assunto só não ganha,
  porque uma aba sozinha é a promessa de que existe outra. Campo de texto usa
  `EgSettingsRow.field`, nunca um rótulo com um campo solto embaixo. O detalhe
  de cada regra está em `components.md` da skill de design.
- Estado de elemento interativo (hover, pressed, foco, selecionado, desabilitado)
  vem da matriz `EgSurfaceStyle` (`eg_surface.dart`), via `EgInteractiveSurface`
  ou `EgSurface` — nunca de uma cadeia de `if`s dentro do widget. **Selecionado
  é elevação e peso, nunca cor**: a superfície `raised` mais a linha de luz de
  1px no topo (`innerHairline`) e o texto em `bodyStrong`, a mesma em linha de
  lista, item de sidebar e cartão do Leaf. Era accent a 14% mais uma aresta
  verde de 3px, e trocar a cor pela luz é o que devolveu ao verde os dois
  papéis que sobraram para ele: **ligado, ou ação primária**. Um componente
  com combinação própria compõe uma `EgSurfaceStyle` a partir dos tokens; a
  ordem de precedência é a mesma para todo mundo. A folha visual de todos os
  estados é o golden `test/goldens/design_state_matrix.png`.
- **Quem se anuncia ao leitor de tela é o `EgHoverable`**, não cada componente
  — mesmo raciocínio da matriz `EgSurfaceStyle`: ele é o único que sabe que algo
  é clicável, focável e ativável por Enter. Ele dá papel de botão, estado de
  habilitado e funde o conteúdo numa etiqueta só; `semanticLabel` **substitui**
  o que os filhos diriam (para a linha do Pin, que precisa de uma frase), e
  `selected`/`toggled` põem na árvore o que hoje só a cor mostra. Duas regras:
  `selected` é `true` ou nada, nunca `false` (um "não selecionado" em todo botão
  é ruído), e `mergeDescendants: false` é obrigatório quando há outro clicável
  dentro — a linha do Echo tem a estrela, e fundir engoliria ela junto. `EgIcon`
  é decorativo por padrão: quem nomeia é o pai, senão o leitor diz "ícone de
  fixar, fixar". O que prende isso é `test/shared/semantics_test.dart` — rótulo
  que some não quebra pixel nenhum e não falha nenhum outro teste.
- Painel flutuante novo usa `EgOverlayShell`: ela é quem registra o
  `WindowListener`, anima a entrada, decide o que é um blur de verdade, trata o
  vazio ao redor como barreira e **garante que o painel aberto tenha teclado**.
  O módulo só diz o que "fechar" significa para ele. Sobre o teclado: um painel
  pode nascer sem ninguém pedir foco (trocar de painel com a janela já visível
  não dispara `didBecomeKey`, logo não há `onWindowFocus` nem `onShow`), e sem
  nó focado nenhum `Shortcuts` é consultado — o painel fica na tela e cada tecla
  vira o bipe do macOS. A casca escuta o `FocusManager` e devolve o foco ao nó
  do módulo, ou ao dela quando o módulo não tem um. A recuperação é sempre
  adiada até depois das microtarefas do quadro: o `autofocus` de um campo do
  módulo é aplicado numa delas, e chegar antes dele abriria o Pin sem cursor na
  busca. Dois comportamentos são opt-in e hoje só o Echo pede os dois:
  `draggable` (arrasta a janela pelo fundo do painel, via `startDragging`) e
  `dismissOnBlur: false` (perder o foco não fecha). O segundo é **por fase**,
  não por módulo — o Echo só o desliga gravando ou transcrevendo, e a casca
  reconfere a bandeira depois da margem de tolerância porque a fase pode virar
  no meio dela. Painel que não pede nada continua com o comportamento de antes.
- A janela 0 é movível (`setMovable(true)`) só para o `startDragging` do painel
  ser aceito pelo macOS; nada liga o arrasto pelo fundo da *janela*, então os
  painéis que não pedem `draggable` seguem parados onde nascem.
- **Toda tela com atalho de teclado precisa de um `FocusScope` logo abaixo do
  `Shortcuts`/`CallbackShortcuts` dela.** No macOS um `TextField` larga o foco a
  cada clique fora dele, e o foco largado sobe até o escopo da rota — que fica
  *acima* do mapa de atalhos. Dali nenhuma tecla volta a descer: a tela inteira
  emudece e vira só de mouse; o Esc que não fecha é o sintoma que se nota
  primeiro. O escopo é o chão que faz esse foco cair dentro da tela. Já está
  posto na `EgOverlayShell` (os cinco painéis) e no `hub_view.dart`; tela nova
  fora desses dois caminhos põe o seu.
- Campo de texto guarda ao perder o foco, por qualquer caminho — clique fora,
  troca de item, fechamento do painel. Vale para o apelido do Pin, o cartão do
  Leaf, o nome da reunião do Echo (`EchoMeetingTitle`) e os campos das telas
  de preferência. O Esc é a única saída que
  descarta, e ele desfaz a edição **antes** de o campo sair da árvore, então
  nunca colide com o commit do foco perdido. A contrapartida disso no Leaf é o
  `⌘Z`: como esvaziar o campo apaga a anotação, e sair do campo confirma
  sozinho, a parede guarda o último cartão arrancado até o painel fechar — ação
  destrutiva sem pergunta precisa de desfazer, nunca de um diálogo.
- Acesso a dados sempre atrás de repositório (ex.: `ClipboardRepository`) —
  nunca acoplar UI/ViewModel diretamente ao SQLite.
- A busca do Pin mora inteira em `PinSearch` — casar e pontuar são a mesma
  conta, e ela é do domínio, nunca do widget. Duas regras que não se negociam
  por conveniência: **os fixados nunca são reordenados pela busca** (são a
  camada `⌥`, e `⌥2` precisa apontar para o mesmo item enquanto se digita), e a
  **subsequência não é solta sobre o conteúdo inteiro** — só sobre o apelido e a
  linha exibida. Solta, ela devolve o histórico inteiro para qualquer coisa
  digitada; o casamento literal é que continua alcançando o conteúdo todo.
- **A busca do Echo é de todas as reuniões, e mora em `MeetingSearch`** —
  domínio, como o `PinSearch`, testada sem tela. Quatro regras: ignora acento
  e maiúscula (`TextFold`, que dobra **sem mudar o comprimento**, para a
  posição achada no texto dobrado grifar o original); casa pelo **começo** da
  palavra ("orcam" acha "orçamento", "custo" não acha "acusto"); **todas** as
  palavras precisam estar na reunião, em qualquer lugar dela; e o índice
  dobra o texto uma vez por lista de reuniões, nunca a cada tecla. Abrir um
  resultado é um `EchoJump` — a face, a fala e o ponto do áudio — que a
  leitura e o player obedecem **uma vez por pedido**, e que `select` esquece.
  `⌘F` leva até ela de qualquer aba do Echo. Ver
  [docs/Ideis projeto/echo-busca.md](docs/Ideis%20projeto/echo-busca.md).
- **A captura da área de transferência é nativa, e o evento é o
  `changeCount`, não o conteúdo.** O `PasteboardWatcherChannel`
  (`MainFlutterWindow.swift`) pergunta a cada 200 ms se o
  `NSPasteboard.general.changeCount` mudou — o macOS não notifica, nem em
  Swift. Comparar conteúdo, como o polling em Dart fazia, tornava invisível
  recopiar a mesma coisa, e o item não subia. Duas armadilhas: o canal existe
  nos dois engines, mas o Swift guarda o de **quem chamou `start`** (sempre a
  janela 0) — senão o aviso de cópia sairia pelo Hub, onde ninguém escuta; e,
  quando o Pin escreve texto, o `acknowledge` **confere o conteúdo** antes de
  engolir o evento, porque o `changeCount` pode ser de outro app que copiou no
  meio (a escrita de imagem marca o `changeCount` sozinha, no `writeImage`). A
  interface Dart é o `ClipboardWatcher`. Detalhes:
  [docs/Ideis projeto/captura-de-clipboard-nativa.md](docs/Ideis%20projeto/captura-de-clipboard-nativa.md).
- **O Pin guarda imagem — e a imagem não mora no banco.** É um arquivo na
  pasta `Pin/Imagens` do aplicativo (`PinImageStore`), com o nome tirado do
  hash do conteúdo; a linha guarda só o que se sabe dela, em JSON na coluna
  `image` (`PinImage`). A coluna única `content` vira a chave
  `imagem:<hash>.<ext>`, e é ela que faz a mesma imagem copiada de novo subir
  em vez de duplicar — por isso **a busca lê `searchableContent`**, nunca o
  `content` de uma imagem. Fica fora do backup, como o áudio do Echo, e sai
  pela mesma regra: **arquivo que nenhuma linha quer é lixo**
  (`PinImageJanitor`). Quem decide se a cópia é imagem ou texto é o nativo
  (`PinImageCapture`), e **texto ganha de imagem** — copiar um parágrafo do
  Pages traz uma imagem dele junto, e quem copiou queria o parágrafo. Colar
  devolve a imagem em si (`writeImage`), nunca o caminho. A reclassificação
  do histórico pula as imagens: o classificador lê texto, e a chave não é. Ver
  [docs/Ideis projeto/pin-imagens.md](docs/Ideis%20projeto/pin-imagens.md).
- **O Pin escreve num lugar só: o gerador de CPF e CNPJ.** Ele é uma linha no
  topo da lista dentro do filtro daquele documento, e paga três exceções às
  regras daqui — as pílulas de CPF e CNPJ estão sempre na fila (senão o gerador
  nasce escondido de quem nunca copiou um), clicar nela copia em vez de abrir o
  preview (a linha não tem um "dentro"), e `selectedIndex == -1` passou a
  significar duas coisas. **É uma linha só para os dois documentos**, e uma
  conta só: o módulo 11 vive em `TaxId` (`lib/features/pin/models/tax_id.dart`),
  onde CPF e CNPJ compartilham o mesmo `_checkDigit` e discordam apenas nos
  pesos (`TaxIdKind.weightAt`) — o segundo documento não ganhou um segundo
  arquivo, pelo mesmo motivo que a conta saiu do classificador. Ver
  [docs/Ideis projeto/pin-gerador-de-cpf.md](docs/Ideis%20projeto/pin-gerador-de-cpf.md).
- Tipo de item do Pin (texto, link, e-mail, telefone, CPF, CNPJ, comando) é decidido
  na captura e gravado na linha. Mexeu no `ClipboardItemClassifier`, suba o
  `version` dele: é o que faz `reclassifyOutdated` reprocessar o histórico já
  guardado uma vez, na abertura seguinte. Sem isso, um tipo novo nasce vazio
  para quem já usa o app.
- Backup e restauração (`lib/core/storage/backup_service.dart`) **descobrem as
  tabelas pelo `sqlite_master`** — a tabela de um módulo novo entra nos dois
  sozinha, sem ninguém vir aqui. A única que fica de fora é `schema_migrations`,
  que é do banco que está rodando. O snapshot é `VACUUM INTO`, nunca cópia do
  arquivo: o banco roda em WAL com duas conexões abertas, e o arquivo no disco
  não tem o que ainda está no log. Ver
  [docs/Ideis projeto/backup-do-banco.md](docs/Ideis%20projeto/backup-do-banco.md).
- **O Evergreen guarda os dados dele para si, e não os traduz para ninguém.** O
  backup é um `.db` que só ele lê, e é o suficiente: a pergunta que ele responde
  é "e se este arquivo se perder?". Houve uma exportação em JSON ao lado, para
  outro programa abrir, e ela saiu — ninguém abriu o arquivo em programa nenhum,
  e ela cobrava o preço de um segundo formato a manter, com o histórico do Pin
  inteiro em texto puro numa pasta a mais. Um módulo novo não precisa pensar
  nela. A pasta `Backups/` fica dentro da pasta do aplicativo, onde o macOS não
  pede permissão, e o botão "Mostrar no Finder" é a interface — diálogo de
  "salvar como" exigiria um pacote novo.
- **O que a pessoa pede para levar embora é outra coisa, e tem uma saída só: o
  `ExportService`.** A regra acima é sobre o aplicativo traduzir o banco dele
  por conta própria; exportar é **um documento por vez, pedido no botão, do
  texto que está na tela** — o resumo e a transcrição de uma reunião, hoje
  (`MeetingDocument`). Nada disso é lido de volta. A pasta é `Exportações/`, ao
  lado de `Backups/` e pela mesma razão (`~/Documents` pede permissão no meio do
  clique), e por isso escrever **termina mostrando o arquivo no Finder**: a
  pasta é funda demais para alguém achá-la sozinho. O serviço é interface, como
  o `NestFileService`, pelo motivo de sempre — no relógio falso do teste de
  widget a resposta de uma escrita em disco nunca chega. Ver
  [docs/Ideis projeto/echo-copiar-e-exportar.md](docs/Ideis%20projeto/echo-copiar-e-exportar.md).
- **Desinstalar é um canal nativo só** (`UninstallChannel`): item de início,
  permissões (`tccutil`, antes de o app sair do lugar), as pastas com o
  identificador em `~/Library`, as preferências e o app para o Lixo, terminando
  em `exit(0)` sem voltar ao Dart. Lugar novo no disco que não seja uma pasta
  com o identificador em `~/Library` precisa entrar na lista dele (o modelo do
  FluidAudio já entrou), senão sobra no disco de quem desinstalou. Ver
  [docs/Ideis projeto/desinstalar.md](docs/Ideis%20projeto/desinstalar.md).
- **Erro vai para o registro local, e o registro não leva nada de quem usa.**
  `AppLog` (`lib/core/diagnostics/app_log.dart`) escreve em `Diagnóstico/`, na
  pasta do aplicativo (três arquivos de 1 MB, só a janela 0 roda a rotação —
  os dois engines escrevem no mesmo arquivo, e o Hub para no dobro do teto; a
  mesma linha repetida é contada, não reescrita). Quem alimenta: os dois caminhos
  de erro não tratado (`ErrorCapture`, encadeado depois do
  `KeyboardStateGuard`, cujo assert continua fora) e o `_invoke` de cada canal
  nativo do Echo, do Nest e da trava do Awake (`AppLog.channelError`), nos
  dois engines — canal novo que falhe em silêncio ganha a mesma linha. **Quem garante a regra é o
  `AppLog.describe`, nunca quem chama**, e a armadilha é o `toString` dos
  erros: o `SqliteException` imprime os parâmetros da instrução (numa escrita
  do Pin, o texto copiado), o `FileSystemException` imprime o caminho (no Nest,
  o nome do arquivo), o `PlatformException` traz mensagem e detalhes do nativo,
  o `FormatException` traz o texto que não leu. Cada um é tratado por tipo;
  erro novo que carregue dado no `toString` entra lá, e o resto passa pelo
  `redact` (aspas, link, e-mail, caminho, número longo). Do canal vai o método
  e o código, nunca a mensagem. `AppLog.info` recebe só texto do próprio app.
  O que prende isso é `test/core/diagnostics/app_log_test.dart`, com um item do
  Pin passando por um SQLite de verdade. O "Copiar diagnóstico" da tela do
  aplicativo (`DiagnosticsService`, interface pelo motivo do `NestFileService`)
  junta versão, sistema, módulos, permissões e o fim do registro, e abre no
  Finder a pasta dele e a `~/Library/Logs/DiagnosticReports` do macOS.
- Migrações de schema: só **adicionar** entrada com chave nova em `_migrations`
  em `lib/core/storage/app_database.dart`; nunca editar nem reaproveitar uma
  chave já publicada (a tabela `schema_migrations` rastreia quais rodaram). A
  chave vale mais que a posição porque duas branches escrevem "a próxima
  migração" ao mesmo tempo — por número elas colidem e uma some em silêncio.
- Ao adicionar pacote com código nativo macOS, verificar se ele precisa
  aparecer também no callback de sub-janela em
  `macos/Runner/MainFlutterWindow.swift` (senão quebra em janelas secundárias).
- Novo módulo: registrar em `EvergreenModule` — com `shortcutSlot` e `panel`,
  se tiver painel —, criar `lib/features/<modulo>/` na estrutura padrão e ligar
  a tela de configurações em `_settingsFor` (`hub_view.dart`). O interruptor
  mestre e o item do menu da barra vêm de graça; a seção "Atalho global" é
  `GlobalShortcutSection(slot: ...)`, nunca escrita à mão. Um módulo que apareça
  em `_startModule`/`_stopModule` do bootstrap precisa dizer o que para quando
  ele é desligado.
- **Módulo que só lê o que os outros gravaram** (hoje, o Track) não cria tabela,
  não escreve linha e não faz migração: ele é um repositório de leitura sobre as
  tabelas alheias. Consequência prática: cada módulo novo o alimenta de graça, e
  a única obrigação é a do lado dele — **nunca ler o conteúdo de um item do
  Pin**. A consulta do Track pede `copied_at` e `type`, e mais nada, porque o
  Pin registra tudo o que passa pela área de transferência, senha inclusive.
  O mesmo vale para o que segue ao modelo local: só o agregado. Por que o
  Track mede "tempo registrado" (foco **mais** reunião) e o que mais a
  construção decidiu: [docs/Ideis projeto/track-diario-do-dia.md](docs/Ideis%20projeto/track-diario-do-dia.md).
- Do outro lado dessa regra: **módulo que quer aparecer no Track precisa gravar
  alguma coisa.** O Awake era o único que não aparecia — não por decisão, mas
  porque não tinha tabela. Agora grava uma linha por trava solta (`quando`,
  `quanto`, `o quê`), e só isso: o painel continua respondendo "está ligado?", e
  o histórico é do Track. A trava que ainda está de pé não vira linha, porque
  ainda não tem duração. **E a linha dura o que o Track lê**: o Awake e o Nest
  guardam as mesmas `FocusSessionRepository.keptWeeks` semanas do Focus,
  limpando na própria escrita. Módulo que grave só para o Track faz igual —
  linha que ninguém lê não fica no disco, e a [PRIVACY.md](PRIVACY.md) promete
  o prazo.
- O parágrafo que o modelo local escreve sobre um dia é **cache, não dado**: ele
  vive no plist (`TrackSummaryCache`), com assinatura do dia, e não no banco.
  Não entra no backup porque se refaz sozinho — e é o que
  mantém o Track sem tabela própria mesmo guardando alguma coisa.
- Módulo que usa o modelo local trata a resposta dele como **enfeite**: abaixo
  do macOS 26, sem Apple Intelligence ou com o servidor do LM Studio desligado o
  modelo responde `unsupported_os`, e a tela precisa ficar inteira sem o texto —
  sem aviso, sem espaço reservado, sem bloquear o que já está desenhado. **Não
  há volta silenciosa para o Apple Intelligence**: quem escolheu o LM Studio
  espera o LM Studio.
- **O modelo local é escolhível, e tem uma porta só: o `LocalModelGate`, na
  janela 0** (`lib/core/local_model/`). O padrão é o Apple Intelligence
  (`AppleLocalModel`, o canal do Echo de sempre); a alternativa é um modelo do
  LM Studio (`LmStudioLocalModel`), em HTTP de Dart puro preso a
  `127.0.0.1:1234` — **sem campo de endereço**, porque um endereço errado
  mandaria uma reunião para fora da máquina — e pela API **nativa**
  (`/api/v1/models`, `load`, `unload`, `chat`), que é a que deixa escolher o
  contexto (32k) e descarregar quando se quer. Três regras do portão: **um por
  aplicativo** (o Track pede do Hub pelo `LocalModelHost`, no arranjo do
  `EchoSummaryHost`, senão o Track descarregaria o modelo no meio do resumo do
  Echo); **um pedido por vez**, carregando uma vez para a fila e descarregando
  20 s depois de ela esvaziar (`idleGrace` — sem a folga, passear pelos dias do
  Track carregaria 3 GB a cada clique; num resumo em blocos, nunca entre um
  bloco e outro); e **só
  descarrega o que ele mesmo carregou** — o modelo que a pessoa abriu à mão no
  LM Studio continua aberto, e o bloco segue o contexto daquela instância. O
  `load` nativo não tem prazo de inatividade, então o Evergreen anota o que
  carregou (`app.local_model_loaded_instance`) e a abertura seguinte
  descarrega o que uma queda deixou (`sweep`). Quem chama — o
  `LocalEchoSummaryRunner` e o `TrackSummarizer` — não sabe qual modelo
  responde; o tamanho do bloco vem de `contextTokens` da sessão aberta. O
  servidor nunca é ligado sozinho: o "Ligar" da tela do aplicativo é o único
  ponto em que o Evergreen abre o processo de outro programa (`lms server
  start`); o arranjo recomendado é o servidor subir com o login, que é leve e
  não carrega modelo. Com o LM Studio escolhido, o "Resumir" do Echo não
  depende do Apple Intelligence, e LM Studio antigo (sem `/api/v1`) ou com
  token de API aparece como recusa, não como "desligado". Com o LM Studio
  escolhido, o Hub pergunta ao servidor de cinco em
  cinco segundos quem está na memória, e a bolinha do rodapé da barra lateral
  acende verde enquanto houver um modelo carregado. Ver
  [docs/Ideis projeto/modelo-local-escolhivel.md](docs/Ideis%20projeto/modelo-local-escolhivel.md).
- **Todo texto escrito por um modelo diz quem o escreveu.** O resumo do Echo
  grava o **nome de exibição** na hora (`summary_model`, nunca o id — o modelo
  pode sair do disco depois), e a leitura e a exportação mostram "Resumido
  por …"; o parágrafo do Track guarda o modelo no cache, e a escolha entra na
  assinatura do dia, então trocar de modelo refaz o parágrafo. Texto novo de
  modelo que apareça em outro módulo grava quem o escreveu do mesmo jeito.
- **Conteúdo longo para ler abre na região do Hub — nunca em janela nova nem em
  diálogo modal.** É o padrão do aplicativo, e vale para módulo existente ou
  novo: o módulo abre a região (`hubDetailProvider.open`), guarda no próprio
  estado *qual* item está aberto, desenha um `HubDetailRegion` e liga esse
  widget em `_region` (`hub_view.dart`); a lista que abriu marca a linha como
  selecionada. Hoje: `EchoReader` (a reunião) e `FocusReader` (a sessão do
  histórico) — o Focus era um diálogo modal até a v0.4, e o modal escurecia o
  histórico atrás, prendia o teclado e obrigava a fechar para olhar a linha
  vizinha. A tela do aplicativo também abre a dela (`LicensesReader`), mas
  por outro provider, o `appDetailProvider`: ela não é um módulo, e a região
  de um módulo é identificada pelo módulo. Modal continua sendo a forma certa de **uma pergunta de sim ou não**
  (`EgConfirmDialog`), e só disso.
- Quem faz a janela crescer para caber a região é o
  `HubWindowChannel.setDetailWidth` — dividir a largura que já existe foi
  tentado e deixa a leitura espremida. A janela cresce **em torno do próprio
  centro** e volta pelo mesmo caminho: o lado nativo guarda o que a tela não
  deixou crescer e o passo lateral que ele deu para não vazar da borda, e paga
  os dois no fechamento. Sem esse acerto, abrir e fechar deixava a janela mais
  estreita e fora do centro a cada volta.
- Preferência que não é de módulo nenhum (iniciar com o macOS, atalho do Hub,
  o nome de quem usa, a aparência) vai para `AppSettings` e para a tela do aplicativo
  (`app_settings_view.dart`), nunca para a tela de um módulo — foi assim que
  "iniciar com o macOS" acabou morando dentro do Pin até a v0.2.
- **O nome de quem usa é preferência de aplicativo, e existe para o modelo
  local.** Sem ele o resumo da reunião diz "a pessoa" e o parágrafo do Track diz
  o mesmo — texto sobre você escrito por quem não sabe seu nome. Quem quiser
  usá-lo faz duas coisas, nunca uma: põe o nome **no texto** que vai ao modelo
  (no Echo é o rótulo de quem falou, `Speaker.labelFor`) e **na instrução**,
  dizendo que aquele nome é de quem pediu — o rótulo sozinho faz o modelo achar
  que é mais um participante. **E a instrução cerca o nome, nunca o solta**: ele
  só leva o que está nas falas marcadas com ele, e não é apresentado quando a
  pessoa não falou — o único nome de um texto vira o dono de todas as falas, e
  um vídeo assistido em silêncio saiu resumido como "Lucas afirma…". O resto é
  escrito sobre o assunto, não sobre quem disse (`LocalEchoSummaryRunner.rulesFor`).
  Vazio é o estado normal e nada pode depender dele.
  Módulo que roda no engine da janela 0 relê o disco antes
  (`AppSettingsRepository.reload`): o nome é escrito no Hub, que é outro engine.
- A pergunta do nome aparece **uma vez por instalação**, quando a abertura
  animada termina: o Hub cai na tela do aplicativo, com a pergunta no topo e o
  cursor dentro. Amarrada ao fim da cena, e não à abertura da janela, porque a
  cena já roda uma vez por build — pergunta que reabre a cada Hub vira cobrança.
  Depois disso o campo continua lá, como primeira linha de "Geral".
- Módulo com painel flutuante: **não crie uma janela nova** — acrescente um
  valor a `OverlayPanel`, desenhe o painel em `OverlayHost` e registre o atalho
  global no `EvergreenBootstrap`. Só a janela 0 pode ser borderless/sempre no
  topo (motivo em
  [sugestoes-futuras-migracao-nativa.md](docs/Ideis%20projeto/sugestoes-futuras-migracao-nativa.md))
  — a ilha do notch é a exceção única, por não ter engine, e não é precedente
  para painel nenhum.
- A janela 0 é um `NSPanel` **não-ativante**: ela recebe o teclado sem tirar da
  frente o app em que a pessoa estava. Quem a exibe é o `OverlayWindowChannel`,
  nunca `windowManager.show()` — o `show()` do pacote chama
  `NSApp.activate(ignoringOtherApps: true)`, e é essa chamada, não o estilo da
  janela, que faz o app anterior piscar. Pelo mesmo motivo o nível e o
  `collectionBehavior` moram no `MainFlutterWindow`: `setAlwaysOnTop` os
  rebaixaria para `.floating`, abaixo de um app em tela cheia.
- O preço do painel que não ativa o app: a janela 0 só presencia as
  modificadoras que sobem e descem **enquanto ela é a key window**, e o atalho
  global acontece antes disso. Como `SingleActivator` decide pelo estado
  acumulado (`HardwareKeyboard.logicalKeysPressed`), e não pelas modificadoras
  do evento que chegou, todo atalho com `⌘` ou `⌥` falharia calado no painel
  recém-aberto — só o Esc, que não exige modificadora, continuaria de pé. Por
  isso o `OverlayWindowChannel` posta um `flagsChanged` sintético a cada
  `didBecomeKey` (`resyncModifiers`): é ele que realinha o registro do Flutter
  com o teclado físico. Não há como fazer isso do lado Dart —
  `HardwareKeyboard.syncKeyboardState` só acrescenta teclas e `clearState` é de
  teste, e leva os handlers do teclado junto.
- Sub-janela (hoje só o Hub) nasce escondida e **se exibe sozinha** depois do
  primeiro quadro, em `main.dart` — quem pediu a janela roda em outro engine e
  não tem como saber quando este subiu. Exibi-la de fora mostrava uma janela em
  branco que já levava o foco do teclado junto, e parecia app travado.
- Geometria de sub-janela é nativa (`HubWindowChannel`, em
  `MainFlutterWindow.swift`): ela abre centralizada na tela onde está o cursor,
  como o painel flutuante. `NSWindow.center()` centraliza na tela em que a
  janela já está — e uma sub-janela nasce na origem do sistema de coordenadas,
  o que com dois monitores jogava o Hub para o monitor errado.
- Esconder a janela flutuante **não** descarta o que estava desenhado nela: o
  macOS reexibe a última superfície antes de o Flutter desenhar o painel novo.
  Por isso `OverlayWindow.hide` apaga o painel (`Opacity(0)` no `OverlayHost`) e
  espera um quadro antes de esconder — sem isso, abrir o Focus logo depois de
  fechar o Pin mostra o Pin por um quadro.
- Serviços que precisam sobreviver com todas as janelas fechadas (captura de
  clipboard, cronômetro do Focus, trava do Awake) vivem no engine da janela 0 e
  são ligados no `EvergreenBootstrap`.
- **Trabalho demorado pedido de dentro do Hub também mora na janela 0.** Fechar
  o Hub destrói a sub-janela e o engine dela, e com ele tudo o que estava
  pendente — não há aviso, não há erro, o trabalho simplesmente não termina. Foi
  o que acontecia com o resumo do Echo: pedir "Resumir" e sair da janela
  cancelava o resumo no meio, e a reunião reaparecia sem ele. O arranjo é
  `EchoSummaryRunner`: quem faz é o `LocalEchoSummaryRunner` da janela 0, quem
  pede é o `WindowEchoSummaryRunner` do Hub, e o `echoSummaryRunnerProvider`
  escolhe um ou outro pelo `windowKindProvider` — o chamador não sabe a
  diferença. O Hub pergunta o andamento de meio em meio segundo enquanto há
  trabalho (`EchoSummaryStatus`), o que também é o que faz uma janela reaberta
  reencontrar um resumo em curso. Canal unidirecional, registrado uma única vez
  na janela 0: nos dois sentidos, um Hub reaberto rápido demais poderia
  encontrar o registro do engine morto ainda ocupado.
- Arquivo Swift novo em `macos/Runner/` **não entra sozinho na build**: o
  `project.pbxproj` é da era anterior aos grupos sincronizados, então cada
  arquivo precisa de quatro entradas (`PBXBuildFile`, `PBXFileReference`, filho
  do grupo `Runner` e a fase `Sources`). Sem as quatro, ele compila no editor e
  some no build.
- **Módulo que mexe em arquivo põe a conversa com o disco atrás de uma
  interface** (`NestFileService`), não de uma classe concreta. Não é cerimônia:
  teste de widget roda no relógio falso do binding, e nele a resposta de uma
  leitura de disco **nunca chega** — o teste do painel trava esperando o tamanho
  do primeiro arquivo, sem erro e sem mensagem. A tela é verificada contra uma
  imitação em memória; o disco de verdade é assunto do teste da implementação,
  que roda fora do binding. A mesma armadilha alcança o golden de conferência, e
  lá a saída é `tester.runAsync`.
- Preferir sempre a solução em Flutter puro a código nativo (Swift/AppKit);
  quando uma alternativa nativa for descartada, documentar em `docs/`.

# Language / Idioma

UI e microcopy em português (pt-BR).

# Commands

- `flutter run -d macos` — rodar em desenvolvimento
- `flutter analyze` — checar lint
- `flutter test` — rodar testes (unidade e widget)
- `flutter test --run-skipped -t preview --update-goldens` — regerar goldens
  de conferência visual (fora da suíte padrão, dependem de fontes do sistema)
- `flutter test --run-skipped -t assets test/tools/brand_assets_test.dart` —
  reexportar o ícone do aplicativo e o da barra de menus a partir da marca em
  Dart. Fora da suíte padrão porque **escreve** no repositório.
- Os scripts de instalar, versionar e publicar moram em `scripts/`, e o
  [scripts/README.md](scripts/README.md) explica cada comando.
- `./scripts/run_build_copy` — build release e instala em `/Applications`, reassinando
  com identidade estável. A assinatura ad-hoc do projeto muda de hash a cada
  build, e com ela o macOS descarta a permissão de Acessibilidade — que é o que
  sustenta o auto-colar do Pin.
- `./scripts/release` — o `.dmg` para distribuir: build release, assinatura Developer
  ID com runtime endurecido, notarização do `.app` e do `.dmg` e upload no
  GitHub Release da tag `v<semver>+<build>`. **Publica só da `main`**, igual
  à do GitHub, limpa e com o código da tag: a `validation` é integração, e um
  `.dmg` dela seria código que a suíte não conferiu como conjunto. O
  `release-so-da-main.yml` faz a mesma conferência no GitHub e devolve a
  rascunho o release criado pela página com uma tag que não é da `main`.
  `--sem-publicar` para no `.dmg`; `--sem-notarizar` só assina e monta, para
  conferir a janela. Pede o certificado e a credencial do `notarytool` no
  chaveiro — o passo a passo está em
  [docs/Ideis projeto/instalador-dmg.md](docs/Ideis%20projeto/instalador-dmg.md).
- `./scripts/downloads` — quantas vezes cada versão foi baixada (link direto,
  página/atualização e procuras do appcast), lido da API do GitHub. É a única
  contagem que existe: o app não conta nada.
- `./scripts/documentos` — os PDFs da `LICENSE` e da `PRIVACY.md`, pelo
  LibreOffice, em `build/documentos`. O `release` o chama e anexa os PDFs.
- `./scripts/bump_version` — a regra do bump, num lugar só: o `version-bump.yml` o
  chama com o nível da label, o `preparar-release.yml` com `--build`, e à mão
  ele é a rede para quando o Actions está fora do ar. Roda na `validation`,
  **depois** do merge.

# Branches

O caminho: **a feature entra na `validation`,
a `validation` é promovida para a `main`.** Cada PR passa por um portão só, e
os dois portões perguntam coisas diferentes.

- **Feature → `validation`.** É onde a label `bump:patch|minor|major` é exigida
  (`require-bump-label.yml`) e, no merge, onde o **semver** sobe e a tag é
  criada (`version-bump.yml`). O build (`+N`) fica intacto. A suíte **não**
  roda aqui.
- **Preparar release.** Antes de promover, o botão "Preparar release" na aba
  Actions (`preparar-release.yml`, ou `./scripts/bump_version --build --push`) soma +1
  no **build**, na `validation`, com tag `v<semver>+<build>`. É uma vez por
  publicação, não por PR — o build responde "qual `.dmg` é este", e contaria
  merges se subisse a cada um. Até a 0.33.0 todo build era `+1`, porque o
  `cider bump <nível>` o zerava; os dois workflows agora chamam o mesmo
  `bump_version`.
- **`validation` → `main`.** É a PR de promoção, e é ela que roda `flutter
  analyze` e `flutter test` (`ci.yml`) — a integração é onde se confere o
  conjunto, e um runner de macOS custa dez vezes um de Linux por minuto — e
  que exige o build maior que o da `main` (`require-build-bump.yml`). Não
  pede label: ela carrega um número que já foi decidido, e bumpar dos dois
  lados daria dois números para o mesmo código. Promovida, o `./scripts/release`
  publica o `.dmg` na tag.

**O título da PR é a linha do changelog, e quem lê é quem usa o app.** No
merge na `validation`, o `bump_version` escreve o título no
[CHANGELOG.md](CHANGELOG.md), e o `./scripts/release` publica essas linhas como
notas do GitHub Release. Por isso o título é simples e objetivo: em português,
dizendo o que mudou para quem usa e não como foi feito, numa linha, sem
prefixo de commit (`feat:` e `fix(echo):` ficam nos commits) e sem nome de
classe, arquivo ou branch. "Exportar a reunião em PDF", não "feat(echo):
ExportService ganha PdfWriter". Mudança que quem usa não vê (CI, refatoração,
teste) também ganha uma linha — e ela diz isso: "Ajustes internos no
instalador".

A consequência a saber: **entre a feature e a promoção, o que segura a barra é
rodar `flutter analyze` e `flutter test` na máquina** antes de abrir a PR. O CI
só vai falar na promoção, e lá ele fala sobre o conjunto — não sobre qual PR
quebrou.

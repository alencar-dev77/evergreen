# Atualização automática com o Sparkle

Até a v1.0 o Evergreen não tinha como se atualizar: quem instalava ficava na
versão que baixou. Desde a #92, o [Sparkle](https://sparkle-project.org) — o
padrão dos apps de Mac distribuídos fora da App Store — procura versão nova uma
vez por dia e, se houver, pergunta se pode instalar.

## Como funciona

1. **O app** lê `releases/latest/download/appcast.xml` (o `SUFeedURL` do
   `Info.plist`). O "latest" do GitHub só aponta para release publicado, e um
   release que não é da `main` volta a rascunho (`release-so-da-main.yml`) —
   então o feed nunca anuncia código que não passou pela promoção.
2. **O appcast** tem um item só, o da versão publicada: número, notas (as do
   `CHANGELOG.md`, em HTML), versão mínima do macOS e o link do `.dmg`, com a
   assinatura EdDSA dele. Quem gera é o `./scripts/release`, e ele vai anexado
   ao próprio release.
3. **O Sparkle compara o build**, não o semver: o `sparkle:version` do appcast
   contra o `CFBundleVersion` do app instalado. É por isso que o build só
   cresce, uma vez por publicação — o `require-build-bump.yml` é quem garante.
4. **Antes de instalar**, o Sparkle confere a assinatura EdDSA do `.dmg` contra
   a `SUPublicEDKey` do app instalado, e a assinatura de código do app novo
   contra a do instalado. As permissões (Acessibilidade, Microfone, Gravação de
   Tela) continuam valendo porque o app novo tem a mesma identidade.

## A chave das atualizações

A chave EdDSA é o que prova que um `.dmg` saiu de quem publica o Evergreen.

- **A pública** está no `Info.plist` (`SUPublicEDKey`), e vai em todo app.
- **A privada** mora no chaveiro de quem publica, na conta `evergreen`
  (`generate_keys --account evergreen`). Nunca no repositório, nunca num
  secret do Actions: quem publica é o `./scripts/release`, na máquina.

**Perder a chave privada é não conseguir mais atualizar quem já instalou** — o
app recusaria toda versão assinada com outra. Por isso ela tem uma cópia fora
da máquina (num gerenciador de senhas, por exemplo):

```bash
# As ferramentas chegam com o pacote do Sparkle, depois de um build.
BIN=build/macos/SourcePackages/artifacts/sparkle/Sparkle/bin

$BIN/generate_keys --account evergreen -p          # mostra a pública
$BIN/generate_keys --account evergreen -x chave.txt # exporta a privada
$BIN/generate_keys --account evergreen -f chave.txt # importa noutra máquina
```

Apague o `chave.txt` depois de guardá-lo. Publicar de outra máquina é importar a
mesma chave lá; gerar uma nova trocaria a `SUPublicEDKey`, e os apps já
instalados não aceitariam a atualização.

## Decisões

- **SPM direto no `Runner`, não o `auto_updater` do pub.dev.** O pacote só traz
  `.podspec`, e aceitá-lo traria o CocoaPods de volta para o projeto inteiro
  (ver o `hotkey_manager_macos` no AGENTS.md).
- **A preferência é do Sparkle** (`automaticallyChecksForUpdates`, nos
  `UserDefaults` do app), e a tela do aplicativo a lê e escreve pelo canal. Uma
  cópia no `AppSettings` seria uma segunda fonte para a pergunta que decide se
  algo sai do app.
- **Ligada de fábrica, sem a pergunta do Sparkle** (`SUEnableAutomaticChecks`).
  A pergunta apareceria na segunda abertura, numa janela solta de um app de
  barra de menus; em troca, a política de privacidade diz o que a procura faz,
  e a tela tem o interruptor. A procura não leva perfil do sistema
  (`SUEnableSystemProfiling`), e instalar sempre pergunta
  (`SUAutomaticallyUpdate` desligado).
- **Um atualizador por processo**, que nasce com a janela 0: a procura agendada
  roda mesmo sem o Hub aberto. O canal existe nos dois engines, e os dois falam
  com a mesma instância.
- **Build de desenvolvimento não se atualiza** (`#if DEBUG`): o atualizador nem
  começa, e a tela diz isso em vez de sumir com a seção.
- **A interface é do Evergreen, não do Sparkle** (`UpdateDriver`, um
  `SPUUserDriver` próprio em `UpdaterChannel.swift`). A janela padrão dele, num
  app de barra de menus, traria o app para a frente no meio do que a pessoa
  estivesse fazendo. Aqui a versão nova acende três coisas, e nenhuma
  interrompe: um item "● Atualizar para a …" no topo do menu da barra (não no
  título ao lado do ícone, onde o `●` é do Awake), uma tecla com bolinha no
  botão "Aplicativo" da barra lateral, e a linha "Versão … disponível" na tela
  do aplicativo. Qualquer uma leva ao cartão de novidades (`HubUpdate`), por
  cima do Hub escurecido — é uma pergunta de sim ou não, a regra do
  `EgConfirmDialog` —, com o gradiente da apresentação de boas-vindas, as notas
  do `CHANGELOG.md` e o "Atualizar e reiniciar". Dali não há mais pergunta: o driver responde sim ao
  "instalo?" do Sparkle, o app fecha, instala e abre o Hub sozinho
  (`app.open_hub_after_update`) — e o Hub de uma build nova abre com a
  abertura animada. "Agora não", Esc ou um clique fora fecham o cartão, e a versão continua
  anunciada; baixando ou instalando, ele não fecha.
- **E uma notificação do sistema, uma vez por versão** (`UpdateNotifier`). As
  três luzes só são vistas por quem vai até elas, e um app de barra de menus
  passa o dia escondido. A notificação não instala nem traz o app para a
  frente: o clique (ou o "Ver novidades") leva ao mesmo cartão. A versão
  avisada fica no plist (`app.update_notified_version`), porque o "Agora não"
  deixa a versão anunciada e o Sparkle a acha de novo a cada procura diária —
  avisar toda vez seria spam. Só uma versão mais nova avisa de novo. Quem
  clicou em "Procurar" não é avisado: a resposta já está na tela. O aviso sai
  do Centro de Notificações quando o app vai instalar; e, clicado depois de o
  app reaberto esquecer a versão, só abre o Hub — sem pedir o cartão, que
  abriria sozinho quando a versão voltasse.
- **Quem é avisado é a janela 0** (`onState`), o engine que nunca morre e que
  cuida do menu. O Hub relê o estado: de meio em meio segundo enquanto algo
  anda, de meio em meio minuto no resto.

## O que ainda depende do certificado

Instalar uma atualização exige o app assinado com Developer ID e notarizado
(#127). Até lá, o código está todo pronto, mas a primeira prova de ponta a ponta
— uma versão instalada achar a seguinte e se atualizar sem perder as
permissões — só acontece depois de duas publicações.

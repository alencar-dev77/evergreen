# Instalador: `.dmg` assinado e notarizado

> Status: **código pronto, falta a credencial** (#127). Issue #97. O `./scripts/release`
> roda inteiro no dia em que o certificado Developer ID e a credencial da
> notarização estiverem no chaveiro (ver "O que é feito à mão").

O único jeito de instalar o Evergreen era o `./scripts/run_build_copy`, que builda e
copia para `/Applications` na própria máquina. Agora há um arquivo para mandar
para outra pessoa: `build/release/Evergreen-<versão>.dmg`, gerado pelo
`./scripts/release` e publicado no GitHub Release da tag.

## Por que `.dmg` de arrastar, e não `.pkg`

É o padrão de app de barra de menus (Maccy, Rectangle, Raycast). Um `.pkg` com
assistente seria exagero: o app não instala nada fora do próprio bundle — o
"iniciar com o macOS" é `SMAppService`, feito pelo app, e as pastas em
`~/Library` nascem no primeiro uso.

## Assinatura: de quem e como

- **Developer ID Application da conta do Luiz Fernando Bargas** (time
  `W3TC63GH63`, conta individual paga). Conta individual serve: o Developer ID
  é emitido pelo Account Holder, que numa conta individual é o próprio dono. O
  que muda em relação a uma conta de empresa é só o nome que o macOS mostra
  como desenvolvedor — "Luiz Fernando Bargas", e não uma razão social.
- O certificado "Apple Development" que já estava no chaveiro **não serve**
  para distribuir: o Gatekeeper o recusa em qualquer Mac (`spctl` responde
  `rejected`), e a notarização também.
- **Runtime endurecido** (`--options runtime` nas assinaturas do `release` e
  do `run_build_copy`). A notarização o exige. **Não** fica no projeto Xcode
  (`ENABLE_HARDENED_RUNTIME`): o `flutter build` assina ad-hoc, e ad-hoc com
  runtime não abre — o dyld recusa os frameworks por "Team IDs diferentes",
  porque ad-hoc não tem time. Foi testado. O runtime só entra junto de um
  certificado de verdade, e o `run_build_copy` sem certificado segue sem ele.
  A única exceção que ele cobrou foi o microfone
  (`com.apple.security.device.audio-input`, no `Release.entitlements`): sem
  ela, o Echo grava o lado da reunião e a sua voz sai muda, sem erro.
  Gravação de Tela, Acessibilidade (o auto-colar do Pin, que é `CGEvent`) e o
  arraste do Nest são permissões do sistema, não do runtime. O release não usa
  JIT, e por isso não há `allow-jit` no Release — só no `DebugProfile`.
- **De dentro para fora, sem `--deep`**: os frameworks (`FlutterMacOS`, `App`,
  e os native assets `sqlite3`, `cnativeapi`, `objective_c`) primeiro, o app
  por último com os entitlements. Com o runtime endurecido o macOS só carrega
  biblioteca assinada pelo mesmo time, então todos levam a mesma identidade.
- **Os dois notarizados**: o `.app` (grampeado antes de entrar no `.dmg`) e o
  `.dmg`. Notarizar só a imagem já cobriria o app, mas o ticket ficaria só
  nela — e o app arrastado para Aplicativos precisaria da internet na
  primeira abertura para o Gatekeeper conferir.

## A janela do `.dmg`

Fundo escuro na Estufa, o Evergreen à esquerda, o atalho de Aplicativos à
direita e uma seta verde entre os dois. O fundo é **gerado** pelo mesmo
`brand_assets_test.dart` que gera os ícones (`macos/packaging/`), e não
desenhado à parte: é a regra da marca num desenho só. Sem frase no fundo,
porque o teste desenha com a fonte de teste.

As posições dos ícones moram em dois lugares que precisam concordar: no
`release` (as variáveis do topo) e no teste (`appAt`, `applicationsAt`).

Quem arruma a janela é o Finder, por AppleScript: a posição de cada ícone
vive no `.DS_Store` do disco, e só o Finder o escreve. Por isso o primeiro
`./scripts/release` faz o macOS perguntar se o terminal pode controlar o Finder.
Feito com `hdiutil` puro, sem o `create-dmg` que a issue sugeria — é o mesmo
AppleScript por baixo, e uma dependência de `brew` a menos para quem builda.

O nome dos ícones é a armadilha: com imagem de fundo, o Finder o escreve
**sempre em preto** — no modo escuro também, e nem a "cor de fundo" das
opções da pasta muda isso (foi testado). Preto sobre o canvas some, então o
fundo traz uma plaquinha em `textSecondary` atrás de cada nome, na altura em
que o Finder o põe com ícone de 128 e texto de 13. O atalho se chama
"Aplicativos", e não "Applications", e o `.app` do nome fica escondido.

## A primeira abertura

Duas coisas que o `.dmg` trouxe e o `run_build_copy` nunca tinha mostrado:

- **O app não mostrava nada.** Ele é `LSUIElement`, e o padrão do "Abrir
  minimizado" é ligado: quem instalava abria e não via janela nenhuma. Agora a
  apresentação de boas-vindas pendente abre o Hub mesmo minimizado
  (`EvergreenBootstrap._openHubIfRequested`), na mesma régua dela — uma vez
  por build.
- **Rodar de dentro do `.dmg` ou dos Downloads.** O macOS executa o app de uma
  cópia temporária (App Translocation), e o item de "iniciar com o macOS" fica
  preso a esse caminho. O `AppLocationGuard` (nativo, antes do Flutter subir)
  pergunta se pode mover para Aplicativos; aceitando, encerra as outras
  instâncias, copia para um temporário e só troca pela instalação antiga
  depois de a cópia terminar, tira a quarentena (senão ela seria translocada
  de novo), manda o original para o Lixo quando ele não está numa imagem de
  disco nem translocado, e reabre a cópia instalada quando todas as antigas
  já saíram. "Não perguntar de novo" é respeitado. Fica quieto em Debug e
  em qualquer build aberta de `Build/Products/` (o `flutter run --profile` e
  `--release`). "Instalado" é `/Applications`, a mesma régua do
  `LaunchAtLoginChannel`, que só adota o item de início ali.

  Limite: aberto dos Downloads, o app é translocado, e não há API pública
  que devolva o caminho de onde ele veio. A cópia vai para Aplicativos, mas
  o original fica nos Downloads.

Nativo, e não um `EgConfirmDialog`, porque precisa acontecer antes de o item
de início ser adotado (`applicationWillFinishLaunching`), e o Dart não chega a
tempo disso. O engine, sim, já está de pé — a janela 0 sai do nib —, e o Hub
da apresentação pode abrir atrás do alerta; como ele é modal, ninguém a avança
nem a marca como vista antes da resposta.

## Permissões

Com a assinatura estável, Acessibilidade e Microfone sobrevivem às
atualizações. A Gravação de Tela é reconferida a cada binário novo (ver o
cabeçalho do `run_build_copy`). Trocar o certificado de quem já usa —
"Apple Development" para "Developer ID" — derruba as permissões **uma vez**.

## O que é feito à mão

Uma vez, na conta do Bargas (developer.apple.com):

1. **Certificates → +** → "Developer ID Application" (o perfil G2). Gera-se o
   CSR no Acesso às Chaves da máquina que vai assinar ("Solicitar um
   certificado de uma autoridade"), sobe-se o CSR, baixa-se o `.cer` e
   abre-se — ele cai no chaveiro junto da chave privada. Para assinar em
   outra máquina, exporta-se o par como `.p12`.
2. **Senha de app** para a notarização, em account.apple.com → Iniciar Sessão
   e Segurança → Senhas de app.
3. Na máquina que assina:

   ```bash
   xcrun notarytool store-credentials evergreen-notary \
     --apple-id <apple-id do Bargas> --team-id W3TC63GH63 \
     --password <senha de app>
   ```

A cada versão: "Preparar release" na aba Actions (soma +1 no build na
`validation` e cria a tag `v<semver>+<build>`), PR de promoção para a `main`
(o `require-build-bump.yml` cobra o build novo), e da `main` promovida — o
script confere que o código é o da tag:

```bash
git checkout main && git pull && git fetch --tags
./scripts/release
```

## Fora daqui, por enquanto

- **Job no Actions.** Disparar o `./scripts/release` pela tag pede o `.p12`, a senha
  dele e a credencial da notarização como segredos do repositório, e um
  runner de macOS — que custa dez vezes um de Linux. O comando local vem
  primeiro; o job é o mesmo script quando valer a pena.
- **Atualização automática** (Sparkle). Quem tem o app hoje baixa o `.dmg`
  novo e arrasta por cima.

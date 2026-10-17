# Evergreen

Suíte pessoal de produtividade para macOS. Tudo local, nada vai para a internet.

Sete módulos em um app só: **Pin** (área de transferência), **Focus**
(cronômetro), **Leaf** (anotações), **Awake** (tela acesa), **Echo** (reuniões),
**Nest** (prateleira de arquivos) e **Track** (o dia reconstruído).

---

## Rodando

```bash
flutter pub get
flutter run -d macos
```

O Evergreen é um **agente de barra de menus** (`LSUIElement`): ao iniciar, **não
abre janela nenhuma e não aparece no Dock**. Procure o canivete na barra
superior do macOS.

### Instalando de verdade

```bash
./run_build_copy
```

Builda em release, reassina com uma identidade estável e copia para
`/Applications`. A reassinatura importa: o projeto builda com assinatura ad-hoc,
cujo hash muda a cada build — e a cada mudança o macOS descarta as permissões
guardadas para o app, entre elas a Acessibilidade que sustenta o auto-colar do
Pin. O cabeçalho do script explica a ordem em que ele escolhe o certificado.

---

## Os módulos

| Módulo | O que faz | Atalho global |
|---|---|---|
| **Pin** | Histórico da área de transferência (texto e imagem), com busca, apelidos e itens fixados | `⌘⇧C` |
| **Focus** | Ciclos de foco e pausa, com o registro do que foi feito em cada sessão | `⌘⇧F` |
| **Leaf** | Parede de até nove anotações curtas, todas à vista de uma vez | `⌘⇧D` |
| **Awake** | Impede o Mac de dormir pelo prazo escolhido — a tela, ou só o sistema | `⌘⇧X` |
| **Echo** | Grava a reunião, separa as vozes, transcreve e resume — tudo local | `⌘⇧E` |
| **Nest** | Junta arquivos de várias pastas numa prateleira e manda todos para a mesma | `⌘⇧R` |
| **Track** | Responde "o que eu fiz hoje" a partir do que os outros gravaram | — (só no Hub) |
| **Hub** | Painel principal: lista os módulos e concentra as configurações | `⌘⇧,` |

O Hub também abre pelo menu da barra → **Configurações**. Sair do app é pelo
mesmo menu → **Encerrar Evergreen**.

Os atalhos acima são o **padrão**, não uma imposição: a tela de cada módulo tem
"Alterar", que grava a combinação que você apertar, e "Restaurar padrão", que
desfaz. E cada módulo tem um interruptor no topo da tela dele — desligado, ele
sai do menu da barra, o atalho para de valer e o que ele fazia em segundo plano
para. Nada é apagado: religar devolve tudo como estava.

O **Echo exige macOS 26** (é de lá que vêm `SpeechAnalyzer` e o modelo de resumo
local). Abaixo disso o módulo se recusa a gravar e o resto do app segue normal.

Uma reunião aberta no Hub tem duas faces — resumo e transcrição — e cada uma
tem os próprios botões de **Copiar** e **Exportar**, ao lado do seletor: eles
sempre agem sobre a face que está na tela. Copiar leva o texto como ele se lê;
exportar escreve um `.md` em `Exportações/`, dentro da pasta do aplicativo, e
abre o Finder com o arquivo selecionado.

O painel do Echo é o único que **se arrasta**: pegue por qualquer área vazia
dele e puxe para tirar a transcrição da frente da reunião. E, enquanto grava ou
transcreve, ele **não some quando você clica na reunião** — dá para acompanhar o
texto e a chamada ao mesmo tempo. Esc e o botão continuam fechando, e a
gravação não para com o painel fechado. A posição não fica guardada: o próximo
`⌘⇧E` abre de volta no centro.

O **Track** não tem atalho nem painel de propósito: ele não grava nada, só lê o
que os outros seis módulos já gravaram.

### O notch

Em MacBook com o recorte da câmera, o notch ganha dois usos — e, sem nada
acontecendo, continua sendo só o recorte:

- **A ilha**: enquanto o Echo grava ou o Focus conta, o que está rodando aparece
  em volta do recorte; com o mouse em cima ela abre, com pausar e parar.
- **A porta do Nest**: levar um arquivo até o notch no meio do arraste abre,
  logo abaixo dele, a pilha de arquivos do Nest (tela do Nest → Ajustes →
  "Abrir pelo notch"). Com arquivos na pilha, fechar o Nest a guarda no notch
  em vez de sumir com ela.

Em Mac sem recorte nada disso existe, nem as linhas de preferência.

---

### Atalhos dentro do painel do Pin

| Tecla | Ação |
|---|---|
| `↑` `↓` | Navega pela lista |
| `enter` | Copia o item selecionado e fecha |
| `⌘1`…`⌘5` | Copia direto o 1º…5º **recente** e fecha |
| `⌥1`…`⌥5` | Copia direto o 1º…5º **fixado** e fecha |
| `←` `→` | Anda pela fila de filtros por tipo |
| `⌘P` | Fixa/desafixa o item selecionado |
| `⌘G` | No filtro de CPF ou CNPJ, gera um documento válido e copia |
| `⌥↑` `⌥↓` | Reordena o fixado selecionado dentro do grupo |
| `⌘⌫` | Apaga o item selecionado, sem fechar o painel |
| `⌘R` | Dá um apelido ao item selecionado |
| `tab` | Abre o preview do item |
| `⌘,` | Abre as preferências e fecha o painel |
| `esc` | Fecha o preview; se não houver preview, fecha o painel |

A busca está sempre focada, por isso apagar é `⌘⌫` e não `Delete` puro — um
Backspace solto precisa continuar apagando o texto digitado.

O badge à direita de cada linha mostra o atalho dela — não é preciso contar
posições.

#### Tipos de item

Cada item é classificado na captura como **texto**, **link**, **e-mail**,
**telefone**, **CPF**, **CNPJ** ou **comando**, e o tipo vira uma pílula de
filtro na busca. **Imagens** também entram — uma captura de tela, uma imagem
copiada do navegador ou um arquivo de imagem copiado no Finder — e colar
devolve a imagem, não o caminho. Quando a cópia traz texto e imagem juntos (um
parágrafo do Pages), fica o texto. Arquivos que não são imagem e rich text
continuam de fora.

#### Apelidos

Qualquer item — fixado ou não — pode ganhar um apelido: `⌘R`, ou o campo
"Apelido para achar depois" no preview (`tab`). Enter guarda, `esc` descarta.

O apelido passa a ser o que a lista mostra, com o conteúdo logo atrás em cinza,
e a busca também procura por ele — dá para achar "chave pix" sem lembrar os
números. **O que é copiado continua sendo o conteúdo original**; o apelido só
existe para você reencontrar o item.

#### Por que duas camadas de números

Fixados e recentes têm numerações independentes: `⌘1` é **sempre** a última
coisa copiada, não importa quantos itens estejam fixados acima dela. Uma
numeração corrida pela lista inteira faria `⌘1` mudar de significado toda vez
que você fixasse algo.

#### Como escolher o atalho de um fixado

Pela **ordem em que você fixa**: o primeiro item fixado vira `⌥1`, o segundo
`⌥2`, e assim por diante. Essa ordem é estável — recopiar um item fixado
atualiza a data dele mas não muda a posição, então `⌥1` continua sendo `⌥1`.

Para reatribuir, use `⌥↑`/`⌥↓` com um fixado selecionado: ele troca de lugar com
o vizinho e leva o número junto. Nas pontas do grupo, e fora dos fixados, as
teclas não fazem nada. Reordenar **arrastando** ainda não existe.

No overlay o `⌥` é sempre "os fixados": ele os alcança no `⌥1`…`⌥5` e os
reordena no `⌥↑`/`⌥↓`.

#### Colar automaticamente

Desligado por padrão. Ligado (Configurações → Pin → "Colar automaticamente"), o
Evergreen devolve o foco ao app anterior e dispara um `⌘V` sintético — o item
não só vai para a área de transferência, ele chega no campo.

Isso exige a permissão de **Acessibilidade**. Sem ela o item é apenas copiado,
sem erro: o `⌘V` fica manual, como antes.

---

## Permissões do macOS

| Permissão | Para quê | Sem ela |
|---|---|---|
| **Acessibilidade** | Atalhos globais e o auto-colar do Pin | Os atalhos não disparam; o auto-colar só copia |
| **Microfone** e **Gravação de tela** | O Echo captura as duas faixas de áudio | O Echo não grava |

Ficam em Ajustes → Privacidade e Segurança.

### "Iniciar com o macOS" em build de desenvolvimento

O toggle usa `SMAppService` (macOS 13+) e o sistema costuma **recusar** o
registro enquanto o app roda de `build/macos/...`, sem assinatura estável e fora
de `/Applications`. Nesse caso o toggle volta sozinho para desligado — é
intencional: ele reflete o estado real do sistema, não a intenção.

Para testar de verdade, instale com `./run_build_copy` e rode de
`/Applications`.

---

## As duas janelas

O Evergreen tem duas janelas, cada uma em um engine Flutter próprio:

| Janela | O que é | Como abre |
|---|---|---|
| **Painel flutuante** | Painel estilo Spotlight, compartilhado por Pin, Focus, Leaf, Awake, Echo e Nest — um painel de cada vez | `⌘⇧C` `⌘⇧F` `⌘⇧D` `⌘⇧X` `⌘⇧E` `⌘⇧R` |
| **Hub** | Painel principal: módulos, configurações e as telas de leitura | `⌘⇧,` ou o menu da barra |

O painel flutuante nunca é destruído, só escondido — por isso abre
instantaneamente, e é ele quem hospeda a captura da área de transferência, o
cronômetro do Focus, a trava do Awake, os atalhos globais e o ícone da barra de
menus, mesmo com tudo fechado.

Ele é um `NSPanel` não-ativante: recebe o teclado **sem** tirar da frente o app
em que você estava.

O porquê desse arranjo (e o que ele custa) está em
[docs/Ideis projeto/sugestoes-futuras-migracao-nativa.md](docs/Ideis%20projeto/sugestoes-futuras-migracao-nativa.md)
e em [docs/Ideis projeto/focus-janela-compartilhada.md](docs/Ideis%20projeto/focus-janela-compartilhada.md).

---

## Banco de dados

**Não é preciso instalar nada.** O macOS já vem com SQLite, e o pacote `sqlite3`
se conecta a ele automaticamente via *native assets* — sem CocoaPods extra, sem
`build_runner`, sem geração de código.

> O plano original citava Isar. Ele foi trocado por SQLite direto: o Isar está
> sem manutenção ativa e o codegen dele quebra no Dart 3.11. O acesso está
> isolado atrás de repositórios, então trocar de motor no futuro não toca a UI
> nem as ViewModels.

Um arquivo só, com uma tabela por módulo que grava (`clipboard_items`,
`focus_sessions`, `leaf_notes`, `echo_meetings`, `awake_sessions`,
`nest_transfers`):

```
~/Library/Application Support/com.alencardev.evergreen/evergreen.db
```

Para inspecionar com o app rodando (WAL permite leitura concorrente):

```bash
sqlite3 ~/Library/Application\ Support/com.alencardev.evergreen/evergreen.db \
  "SELECT id, type, is_pinned, substr(content,1,60) FROM clipboard_items ORDER BY copied_at DESC LIMIT 20;"
```

Para começar do zero, feche o app e apague `evergreen.db*` (os três arquivos:
`.db`, `.db-shm`, `.db-wal`).

### Backup

Como nada sai da máquina, não há servidor de onde puxar o banco de volta — então
o app guarda ele mesmo. Configurações → Aplicativo tem o backup manual, a lista
dos automáticos e a restauração; ficam os **cinco** mais recentes.

O snapshot é um `VACUUM INTO`: um arquivo único, consistente e compactado, sem
`-wal` nem `-shm` para acompanhar. Dá para copiar para onde quiser.

O que não mora no banco fica **fora** do backup: as imagens do Pin
(`Pin/Imagens`) e o áudio das reuniões do Echo (`Reuniões`, guardado por 14
dias), ambos na pasta do aplicativo.

---

## Arquitetura

```
lib/
  app/          composição: providers, raiz do app, bootstrap dos serviços
  core/
    design/     tokens: cores, tipografia, métricas, tema
    storage/    banco SQLite, migrações e backup
    system/     barra de menus, atalhos globais, foco do app anterior, autostart
    window/     criação e controle das duas janelas
  shared/
    widgets/    design system (prefixo Eg*) — reutilizável entre módulos
    utils/
  features/
    home/       o Hub e as configurações do aplicativo
    notch/      a ilha do notch (desenhada pelo Swift) e as preferências dele
    pin/  focus/  leaf/  awake/  echo/  nest/  track/
      data/         repositórios e serviços do módulo
      models/       entidades
      presentation/
        viewmodels/ estado e regras (Notifier do Riverpod)
        views/      telas
        widgets/    componentes do módulo
```

Fora do `lib/`:

```
macos/Runner/         o lado nativo: um canal Swift por assunto que o Flutter não alcança
  AppDelegate.swift         ciclo de vida: fechar janela não encerra o app
  MainFlutterWindow.swift   janela 0, Hub, área de transferência, imagem do Pin, trava do Awake,
                            iniciar com o macOS e devolver o foco ao app anterior
  EchoChannel.swift         captura, transcrição e resumo do Echo (macOS 26)
  EchoPlayerChannel.swift   o player do áudio guardado da reunião
  NestChannel.swift         arraste do Finder, miniaturas e saída da prateleira
  NestDragMonitor.swift     chacoalhar o arquivo e levá-lo ao notch
  NotchIsland.swift         a ilha do notch, uma NSPanel sem Flutter
  NotificationChannel.swift notificações do sistema
assets/               ícone da barra de menus (gerado a partir da marca) e imagens do onboarding
test/                 espelha lib/; goldens/ guarda as imagens de conferência, tools/ os geradores
docs/Ideis projeto/   decisões de arquitetura, alternativas descartadas e propostas futuras
docs/                 especificação do redesign "Estufa" e documentos históricos
.github/workflows/    label de bump na PR, bump da versão no merge e CI na promoção
```

As convenções de arquitetura — a regra do MVVM, como adicionar um módulo, o
design system, as migrações de schema e o que não pode sair de
`MainFlutterWindow.swift` — estão no [AGENTS.md](AGENTS.md).

---

## Testes

```bash
flutter test
flutter analyze
```

Além dos testes de unidade e de widget, há **goldens de conferência visual** —
imagens das telas para revisar o design a olho. Ficam fora da suíte padrão
porque dependem das fontes do sistema:

```bash
flutter test --run-skipped -t preview --update-goldens
```

As imagens são geradas em [test/goldens/](test/goldens/).

---

## Versão

O `version:` do `pubspec.yaml` é o que a sidebar do Hub mostra no rodapé. Quem
bumpa é o GitHub Actions no merge de uma PR na `validation`, lendo a label
`bump:` da própria PR; a `main` herda o número pela PR de promoção. Quando o
Actions está fora do ar, `./bump_version` faz o mesmo à mão — na `validation`,
depois do merge.

O caminho de uma mudança é `feature → validation → main`: a PR de feature pede
a label e faz a versão subir, e a PR de promoção é a que roda `flutter analyze`
e `flutter test`.

---

## O que ainda não está pronto

- **Pin não guarda arquivos nem rich text.** Texto e imagem já entram; o resto
  está no plano.
- **Fixados não se reordenam arrastando.** Por teclado (`⌥↑`/`⌥↓`) já funciona;
  o arrasto com o mouse é que falta.

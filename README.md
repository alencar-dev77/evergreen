# Evergreen

Suíte de produtividade para a barra de menus do macOS. Tudo roda na sua
máquina: nada do que você copia, anota, grava ou organiza sai dela.

Roda em **Mac com Apple Silicon** (M1 ou mais novo) a partir do **macOS 14**. Mac
Intel não é suportado: o app nunca foi testado lá, e o que ele faz com IA local
(o resumo das reuniões e o parágrafo do dia) não roda em Intel.

Sete módulos em um app só: **Pin** (área de transferência), **Focus**
(cronômetro), **Leaf** (anotações), **Awake** (tela acesa), **Echo** (reuniões),
**Nest** (prateleira de arquivos) e **Track** (o dia reconstruído).

Código aberto, sob a [GPL-3.0](LICENSE).

---

## Instalando

1. **[Baixe o Evergreen](https://github.com/alencar-dev77/evergreen/releases/latest/download/Evergreen.dmg)**
   — é sempre a versão mais nova (as novidades de cada uma estão na
   [página do release](https://github.com/alencar-dev77/evergreen/releases/latest)).
   Ele é assinado e notarizado pela Apple, então o macOS o abre sem aviso.
   Precisa de um Mac com Apple Silicon (M1 ou mais novo) e macOS 14 ou superior;
   o Echo pede o macOS 26.
2. Abra o `.dmg` e arraste o Evergreen para **Aplicativos**. Se você abrir o app
   direto do `.dmg` ou dos Downloads, ele mesmo oferece se mover para lá.
3. Procure o **canivete na barra de menus**. O Evergreen não abre janela ao
   iniciar e não aparece no Dock. As configurações abrem com `⌘⇧,`, ou pelo
   menu da barra → **Configurações**.
4. O macOS vai pedir algumas permissões conforme você usa cada módulo — a
   tabela em [Permissões do macOS](#permissões-do-macos) diz qual é para quê.

Já tem o Evergreen? Baixar de novo e arrastar para Aplicativos substitui o que
está lá ("Substituir"), e os seus dados ficam — eles moram fora do app.

**Atualizações** chegam sozinhas: uma vez por dia o Evergreen procura versão
nova e, se houver, pergunta se pode instalar — as permissões continuam valendo.
Dá para procurar na hora, ou desligar a procura, em Configurações → Aplicativo →
**Atualizações**.

**Para desinstalar**, use Configurações → Aplicativo → **Desinstalar o Evergreen**: além de
mandar o app para o Lixo, ele apaga os dados, as preferências, as permissões e
o item de início. Arrastar só o app para o Lixo deixa os dados para trás.

### O que sai da máquina

A versão completa, módulo por módulo e com os prazos, está na
[política de privacidade](PRIVACY.md). O que mudou em cada versão está nas
[novidades](CHANGELOG.md).

Nada do que você usa. O histórico do Pin, as anotações, as reuniões gravadas e
os arquivos do Nest ficam no disco do seu Mac, e o Evergreen não tem conta,
servidor nem telemetria. Só quatro coisas saem dele:

- **O download, uma vez, do modelo que separa as vozes do Echo**, do Hugging
  Face, na primeira reunião com fala do outro lado. Só baixa: nada
  é enviado.
- **O modelo de transcrição do idioma**, que o macOS baixa da Apple a pedido do
  Echo, na primeira reunião naquele idioma. Nenhum áudio é enviado.
- **O LM Studio, se você o escolher como modelo local** — e esse fica na própria
  máquina (`127.0.0.1`), nunca na internet.
- **A procura por versão nova**, uma vez por dia: o Evergreen lê no GitHub qual é
  a última versão. Não leva nada seu, pergunta antes de baixar, e desliga em
  Configurações → Aplicativo → **Atualizações**.

Os erros vão para um registro local (ver [Quando algo dá errado](#quando-algo-dá-errado)),
que nunca leva o que você copiou, anotou ou gravou.

---

## Rodando a partir do código

```bash
flutter pub get
flutter run -d macos
```

O Evergreen é um **agente de barra de menus** (`LSUIElement`): ao iniciar, **não
abre janela nenhuma e não aparece no Dock**. Procure o canivete na barra
superior do macOS.

### Instalando a partir do código

Os comandos moram em [`scripts/`](scripts/README.md), cada um explicado lá.

```bash
./scripts/run_build_copy
```

Builda em release, reassina com uma identidade estável e copia para
`/Applications`. A reassinatura importa: o projeto builda com assinatura ad-hoc,
cujo hash muda a cada build — e a cada mudança o macOS descarta as permissões
guardadas para o app, entre elas a Acessibilidade que sustenta o auto-colar do
Pin. O cabeçalho do script explica a ordem em que ele escolhe o certificado.

### Gerando o instalador

```bash
./scripts/release
```

Gera `build/release/Evergreen-<versão>.dmg`, assinado com o Developer ID e
notarizado pela Apple, e o publica no GitHub Release da tag — é o arquivo que
se manda para outra pessoa. Roda da `main` promovida, com a tag da versão no
HEAD. A configuração de uma vez por máquina (certificado e credencial da
notarização) está em
[docs/Ideis projeto/instalador-dmg.md](docs/Ideis%20projeto/instalador-dmg.md).

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

O resumo das reuniões e o parágrafo do dia do Track são escritos por um **modelo
local**. O padrão é o do **Apple Intelligence**, que já vem no sistema. Em
Configurações → Aplicativo → **Modelo local** dá para trocar por um modelo que
você tenha baixado no [LM Studio](https://lmstudio.ai) — o Qwen3.5 4B, por
exemplo, lê uma reunião de uma hora de uma vez. O modelo só ocupa memória
enquanto escreve, e todo texto diz quem o escreveu ("Resumido por …"). Para não
precisar abrir o LM Studio, ligue nele o **Serviço Local de LLM** (Developer):
o servidor sobe com o Mac, leve e sem modelo carregado.

Uma reunião aberta no Hub tem duas faces — resumo e transcrição — e cada uma
tem os próprios botões de **Copiar** e **Exportar**, ao lado do seletor: eles
sempre agem sobre a face que está na tela. Copiar leva o texto como ele se lê;
exportar escreve um `.md` em `Exportações/`, dentro da pasta do aplicativo, e
abre o Finder com o arquivo selecionado.

Todo painel **se arrasta**: pegue por qualquer área vazia dele e puxe para
tirar da frente o que você quer ver atrás — a reunião, o texto de onde vai
copiar. A posição não fica guardada: o próximo atalho abre de volta no centro.
E o painel do Echo, enquanto grava ou transcreve, **não some quando você clica
na reunião** — dá para acompanhar o texto e a chamada ao mesmo tempo. Esc e o
botão continuam fechando, e a gravação não para com o painel fechado.

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

## Quando algo dá errado

Nada sai da máquina, então nenhum relatório de falha chega a ninguém sozinho.
Em vez disso, o Evergreen guarda os próprios erros num registro local
(`Diagnóstico/`, na pasta do aplicativo) — só o que aconteceu e onde, **nunca**
o que passou pela área de transferência, o que foi anotado, gravado ou o nome
de um arquivo.

Configurações → Aplicativo → **Diagnóstico**:

- **Copiar diagnóstico** — põe na área de transferência um texto pronto para
  colar numa issue: versão, macOS, chip, módulos ligados, permissões, tamanho
  do banco e as últimas linhas do registro.
- **Registro de erros** e **Falhas do macOS** — abrem no Finder a pasta do
  registro e a `~/Library/Logs/DiagnosticReports`, onde o sistema guarda os
  relatórios (`.ips`) de quando um app fecha sozinho.

---

## Permissões do macOS

| Permissão | Para quê | Sem ela |
|---|---|---|
| **Acessibilidade** | O auto-colar do Pin (desligado por padrão) | O auto-colar só copia |
| **Microfone** e **Gravação de tela** | O Echo captura as duas faixas de áudio | O Echo não grava |

Ficam em Ajustes → Privacidade e Segurança.

### "Iniciar com o macOS" em build de desenvolvimento

O toggle usa `SMAppService` (macOS 13+) e o sistema costuma **recusar** o
registro enquanto o app roda de `build/macos/...`, sem assinatura estável e fora
de `/Applications`. Nesse caso o toggle volta sozinho para desligado — é
intencional: ele reflete o estado real do sistema, não a intenção.

Para testar de verdade, instale com `./scripts/run_build_copy` e rode de
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
    diagnostics/ registro de erros local e o texto do "Copiar diagnóstico"
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
packages/             hotkey_manager_macos vendorizado, com Package.swift (é o que tira o CocoaPods)
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
Actions está fora do ar, `./scripts/bump_version` faz o mesmo à mão — na `validation`,
depois do merge.

O caminho de uma mudança é `feature → validation → main`: a PR de feature pede
a label e faz a versão subir, e a PR de promoção é a que roda `flutter analyze`
e `flutter test`.

---

## O que o Evergreen não faz

O app está completo com os sete módulos. Estes são limites, não pendências:

- **O Pin não guarda arquivos nem rich text.** Texto e imagem entram; o resto
  fica de fora.
- **Os fixados não se reordenam arrastando.** É pelo teclado (`⌥↑`/`⌥↓`).

---

## Contribuindo

Issues com bug, dúvida ou ideia são muito bem-vindas — para bug, cole junto o
texto do **Copiar diagnóstico** (Configurações → Aplicativo → Diagnóstico).

Para mandar código:

1. Faça um fork e crie a sua branch a partir da `validation`.
2. Antes de abrir a PR, rode `flutter analyze` e `flutter test` — a suíte só roda
   no CI na promoção para a `main`, então é a sua máquina que segura a barra.
3. Abra a PR para a **`validation`**. A label de versão (`bump:patch`,
   `bump:minor` ou `bump:major`) quem põe é o mantenedor.

As convenções do projeto (arquitetura, regras de UI, por que cada decisão foi
tomada) estão no [AGENTS.md](AGENTS.md) e em [docs/](docs/). A interface é em
português do Brasil. Ao contribuir, você concorda em licenciar a sua
contribuição sob a mesma GPL-3.0 do projeto.

## Apoie o projeto

O Evergreen é gratuito e vai continuar sendo. Se ele te ajuda e você quiser
contribuir com o desenvolvimento, qualquer valor via **Pix** é bem-vindo, pela chave aleatória:

```
94e2aa73-999c-4e5f-8cf2-0572f565eeb2
```

## Licença

Copyright © 2026 Lucas Alencar Simões de Melo.

[GNU General Public License v3.0](LICENSE). Você pode usar, estudar, modificar e
redistribuir o Evergreen; quem distribuir uma versão modificada precisa
distribuí-la também sob a GPL-3.0, com o código.

O pacote vendorizado em [`packages/hotkey_manager_macos/`](packages/hotkey_manager_macos/)
mantém a licença MIT do autor original. As licenças de todos os componentes que
o Evergreen usa estão dentro do app, em Configurações → Aplicativo → Sobre →
**Licenças**.

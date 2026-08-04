# Evergreen

Suíte pessoal de produtividade para macOS. Tudo local, nada vai para a internet.

**v0.1 — módulo Pin** (gerenciador de área de transferência).

---

## Rodando

```bash
flutter pub get
flutter run -d macos
```

O Evergreen é um **agente de barra de menus** (`LSUIElement`): ao iniciar, **não
abre janela nenhuma e não aparece no Dock**. Procure o quadrado verde na barra
superior do macOS.

- `⌘⇧C` — abre o painel do Pin, de qualquer aplicativo
- Clique no ícone da barra → **Configurações** — abre o Hub
- Clique no ícone da barra → **Encerrar Evergreen** — é a única forma de sair

### Atalhos dentro do painel do Pin

| Tecla | Ação |
|---|---|
| `↑` `↓` | Navega pela lista |
| `enter` | Copia o item selecionado e fecha |
| `⌘1`…`⌘5` | Copia direto o 1º…5º **recente** e fecha |
| `⌥1`…`⌥5` | Copia direto o 1º…5º **fixado** e fecha |
| `⌘P` | Fixa/desafixa o item selecionado |
| `⌘R` | Dá um apelido ao item selecionado |
| `tab` | Abre o preview do item |
| `esc` | Fecha o preview; se não houver preview, fecha o painel |

O badge à direita de cada linha mostra o atalho dela — não é preciso contar
posições.

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

Para reatribuir, desafixe e fixe de novo na ordem desejada. (Reordenar
arrastando é um passo natural daqui — ainda não existe.)

### Primeira execução

O macOS vai pedir permissão de **Acessibilidade** para o atalho global
(Ajustes → Privacidade e Segurança → Acessibilidade). Sem ela, o `⌘⇧C` não
dispara; o resto funciona normalmente.

### "Iniciar com o macOS" em build de desenvolvimento

O toggle usa `SMAppService` (macOS 13+) e o sistema costuma **recusar** o
registro enquanto o app roda de `build/macos/...`, sem assinatura estável e fora
de `/Applications`. Nesse caso o toggle volta sozinho para desligado — é
intencional: ele reflete o estado real do sistema, não a intenção.

Para testar de verdade, copie o `.app` para `/Applications` e rode de lá.

---

## As duas janelas

O Evergreen tem dois painéis **independentes** — abrir ou fechar um não afeta o
outro:

| Painel | O que é | Como abre |
|---|---|---|
| **Overlay do Pin** | Painel flutuante estilo Spotlight com o histórico da área de transferência | `⌘⇧C` |
| **Hub** | Painel principal: lista os módulos da suíte e concentra as configurações de cada um | menu da barra → Configurações |

Cada um roda em um engine Flutter próprio. A janela do overlay nunca é
destruída, só escondida — por isso ela abre instantaneamente e é ela quem
hospeda a captura da área de transferência, o atalho global e o ícone da barra
de menus, mesmo com tudo fechado.

O porquê desse arranjo (e o que ele custa) está em
[docs/Ideis projeto/sugestoes-futuras-migracao-nativa.md](docs/Ideis%20projeto/sugestoes-futuras-migracao-nativa.md).

---

## Banco de dados

**Não é preciso instalar nada.** O macOS já vem com SQLite, e o pacote `sqlite3`
se conecta a ele automaticamente via *native assets* — sem CocoaPods extra, sem
`build_runner`, sem geração de código.

> O plano original citava Isar. Ele foi trocado por SQLite direto: o Isar está
> sem manutenção ativa e o codegen dele quebra no Dart 3.11. O acesso está
> isolado atrás da interface `ClipboardRepository`, então trocar de motor no
> futuro não toca a UI nem as ViewModels.

### Onde fica o arquivo

```
~/Library/Application Support/com.example.evergreen/evergreen.db
```

Para inspecionar com o app rodando (WAL permite leitura concorrente):

```bash
sqlite3 ~/Library/Application\ Support/com.example.evergreen/evergreen.db \
  "SELECT id, type, is_pinned, substr(content,1,60) FROM clipboard_items ORDER BY copied_at DESC LIMIT 20;"
```

Para começar do zero, feche o app e apague `evergreen.db*` (os três arquivos:
`.db`, `.db-shm`, `.db-wal`).

Convenções de schema e detalhes do código nativo do Runner (o que não pode ser
removido de `MainFlutterWindow.swift` e por quê) estão documentados no
`AGENTS.md`.

---

## Arquitetura

```
lib/
  app/          composição: providers, raiz do app, bootstrap dos serviços
  core/
    design/     tokens: cores, tipografia, métricas, tema
    storage/    banco SQLite e migrações
    system/     barra de menus, atalho global, iniciar com o macOS
    window/     criação e controle das duas janelas
  shared/
    widgets/    design system (prefixo Eg*) — reutilizável entre módulos
    utils/
  features/
    home/       o Hub
    pin/
      data/         repositórios e captura da área de transferência
      models/       entidades
      presentation/
        viewmodels/ estado e regras (Notifier do Riverpod)
        views/      telas
        widgets/    componentes do módulo
```

Convenções de arquitetura (regra do MVVM, como adicionar um módulo, design
system em `lib/core/design/` e `lib/shared/widgets/`) estão no `AGENTS.md`.

---

## Testes

```bash
flutter test
```

Além dos testes de unidade e de widget, há **goldens de conferência visual** —
imagens das telas para revisar o design a olho. Ficam fora da suíte padrão
porque dependem das fontes do sistema:

```bash
flutter test --run-skipped -t preview --update-goldens
```

As imagens são geradas em [test/goldens/](test/goldens/).

---

## O que ainda não está pronto

- **"Colar novamente" copia, mas não cola.** O item volta para a área de
  transferência; o `⌘V` no app de destino ainda é manual. Colar de verdade exige
  simular evento de teclado via Accessibility API.
- **Atalho global fixo** em `⌘⇧C`. A tela de configurações mostra o atalho, mas
  ainda não permite regravá-lo.
- **Só texto e links.** Imagens, arquivos e rich text estão no plano, não na v0.1.
- **Bundle identifier ainda é `com.example.evergreen`**, o padrão do template.
  Vale trocar em `macos/Runner/Configs/AppInfo.xcconfig` antes de distribuir —
  ele define o caminho do banco, então trocar depois "esconde" o histórico atual.

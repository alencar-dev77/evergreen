# Scripts

Os comandos de instalar, versionar e publicar o Evergreen. Rode da raiz do
projeto (`./scripts/<nome>`); de qualquer outro lugar também funciona, porque
cada script começa entrando na raiz.

| Script | Para quê | Quando |
|---|---|---|
| [`run_build_copy`](run_build_copy) | Instalar na sua máquina | Sempre que quiser testar de verdade |
| [`release`](release) | Gerar o `.dmg` para outra pessoa e publicar | A cada versão, da `main` |
| [`bump_version`](bump_version) | Subir a versão e escrever o changelog | Quase nunca à mão — o Actions faz |
| [`documentos`](documentos) | Gerar os PDFs da licença e da política de privacidade | O `release` chama sozinho |

O cabeçalho de cada script tem o porquê de cada passo. Aqui fica o como.

---

## `run_build_copy` — instalar na sua máquina

```bash
./scripts/run_build_copy
```

Encerra o Evergreen que estiver rodando, builda em release, assina, troca a
cópia de `/Applications` pela nova e abre.

A assinatura é o que importa: com um certificado estável, o macOS guarda as
permissões (Acessibilidade, Microfone) contra a identidade do app, e elas
sobrevivem às builds. Ele reusa o certificado com que a cópia instalada foi
assinada, para essa escolha não andar sozinha.

```bash
EVERGREEN_SIGN_IDENTITY=<hash> ./scripts/run_build_copy   # força um certificado
EVERGREEN_RESET_TCC=1   ./scripts/run_build_copy          # zera a Gravação de Tela
EVERGREEN_RESET_TCC=all ./scripts/run_build_copy          # zera também Microfone e Acessibilidade
```

Os hashes aparecem em `security find-identity -v -p codesigning`. Se o build ou
a assinatura falharem, a cópia instalada fica onde estava.

---

## `release` — o instalador `.dmg`

```bash
./scripts/release                  # tudo: build, assina, notariza, publica
./scripts/release --sem-publicar   # para no .dmg notarizado, sem GitHub Release
./scripts/release --sem-notarizar  # só assina e monta — para conferir a janela
```

Gera `build/release/Evergreen-<versão>.dmg`, assinado com o Developer ID e
notarizado pela Apple — o arquivo que abre sem aviso no Mac de outra pessoa —
e o sobe no GitHub Release da tag `v<semver>+<build>`. As notas do release são
o que o [CHANGELOG.md](../CHANGELOG.md) acumulou desde a publicação anterior, e
os PDFs do `documentos` vão anexados.

Precisa de duas coisas no chaveiro, uma vez por máquina: o certificado
"Developer ID Application" e a credencial do `notarytool`. Enquanto elas não
existem (ver #127), só o `--sem-notarizar` roda — e o `.dmg` que sai dele o
macOS de outra pessoa bloqueia; dá para abrir em Ajustes do Sistema →
Privacidade e Segurança → "Abrir Mesmo Assim".

Para publicar, o script exige árvore limpa e o código igual ao da tag da
versão. O caminho de uma versão nova:

1. **Preparar release** — o botão na aba Actions (ou
   `./scripts/bump_version --build --push` na `validation`) soma +1 no build e
   cria a tag.
2. **Promover** — a PR `validation` → `main`. Ela exige o build novo.
3. **Publicar** — na `main`:
   ```bash
   git checkout main && git pull && git fetch --tags
   ./scripts/release
   ```

Na primeira vez, o macOS pergunta se o terminal pode controlar o Finder: é o
Finder quem arruma a janela do `.dmg`. Detalhes em
[docs/Ideis projeto/instalador-dmg.md](../docs/Ideis%20projeto/instalador-dmg.md).

---

## `bump_version` — a versão

São dois números, e cada um sobe por um motivo:

- **Semver (`0.33.0`)** — sobe a cada PR mergeada na `validation`, pela label
  `bump:patch|minor|major`. Quem faz é o `version-bump.yml`.
- **Build (`+2`)** — sobe uma vez por publicação, no "Preparar release". Quem
  faz é o `preparar-release.yml`.

Os dois workflows chamam este script. À mão, ele é a rede para quando o Actions
está fora do ar — sempre na `validation`, depois do merge:

```bash
./scripts/bump_version                # nível descoberto pelas PRs sem bump
./scripts/bump_version patch          # nível explícito (patch|minor|major)
./scripts/bump_version --pr 128       # nível da label daquela PR
./scripts/bump_version patch --nota "Texto (#12)"   # a linha do changelog
./scripts/bump_version --build        # +1 no build (preparar release)
./scripts/bump_version --dry-run      # só mostra o que faria
./scripts/bump_version --push         # commita, tagueia e envia
```

Sem `--push`, ele deixa o commit e a tag prontos e mostra os dois `git push`
para você conferir antes.

O bump de semver também escreve o [CHANGELOG.md](../CHANGELOG.md), no mesmo
commit: uma seção com a versão nova e uma linha por PR, que é o título dela (o
`--pr` e o modo sem argumento o buscam sozinhos, no Actions ele vem do evento
da PR, e o `--nota` o dá à mão). O
`--build` não escreve nada.

---

## `documentos` — os PDFs

```bash
./scripts/documentos                  # em build/documentos
```

Exporta a [LICENSE](../LICENSE) e o [PRIVACY.md](../PRIVACY.md) para PDF pelo
LibreOffice (`brew install --cask libreoffice`), que lê Markdown direto. O texto
no repositório é a fonte, e o PDF não é commitado: mexeu num documento, o PDF
do próximo release já sai com a mudança.

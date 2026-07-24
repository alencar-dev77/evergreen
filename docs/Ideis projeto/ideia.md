# Evergreen

> **Evergreen** é um aplicativo desktop desenvolvido em Flutter para macOS, criado para centralizar ferramentas de produtividade em um único lugar, com foco em desempenho, simplicidade e uma experiência premium.

---

# Visão do Projeto

O objetivo do Evergreen é substituir diversos pequenos aplicativos por uma única aplicação modular, totalmente local, rápida e elegante.

Cada funcionalidade será desenvolvida como um módulo independente, permitindo que o aplicativo evolua sem perder organização.

A filosofia do projeto é:

- Interface limpa
- Zero distrações
- Tudo local
- Performance acima de tudo
- Design premium
- Experiência nativa do macOS
- Fácil expansão

O Evergreen deverá iniciar automaticamente com o sistema e permanecer executando em segundo plano, consumindo poucos recursos.

---

# Filosofia

O Evergreen não pretende ser apenas mais um aplicativo.

Ele deve transmitir a sensação de uma ferramenta profissional, minimalista e agradável de utilizar diariamente.

A experiência deve lembrar aplicativos como:

- Raycast
- Arc Browser
- Linear
- Notion
- CleanShot X
- Maccy

O foco não é adicionar dezenas de funcionalidades, mas criar ferramentas extremamente bem executadas.

---

# Primeira versão

A primeira versão possuirá apenas um módulo.

## Pin

Pin é o gerenciador de área de transferência do Evergreen.

Seu objetivo é substituir o Maccy.

Funcionalidades iniciais:

- Histórico da área de transferência
- Pesquisa instantânea
- Fixar itens importantes
- Exclusão de itens
- Atalho global
- Execução em background
- Ícone na barra de menus
- Banco de dados local

Nenhum dado será enviado para a internet.

---

# Roadmap

## v0.1

✅ Pin (Clipboard)

---

## v0.2

Focus

Pomodoro moderno.

---

## v0.3

Shelf

Área temporária para armazenar arquivos arrastados.

---

## Futuro

- Notes
- Launch
- Branch
- Vision
- OCR
- Color Picker
- Snippets
- Recent Files
- Quick Actions

---

# Identidade Visual

## Conceito

Dark Premium.

Poucos elementos.

Muito espaço em branco.

Animações suaves.

Interface elegante.

---

## Paleta

### Fundo

#0B0B0B

---

### Superfície

#141414

---

### Cards

#1A1A1A

---

### Hover

#232323

---

### Borda

#262626

---

### Verde Principal

#22C55E

---

### Verde Claro

#4ADE80

---

### Texto Principal

#F5F5F5

---

### Texto Secundário

#9CA3AF

---

### Erro

#EF4444

---

### Warning

#F59E0B

---

# Tipografia

Utilizar fontes modernas.

Preferência:

- Inter
- SF Pro Display (macOS)

Hierarquia clara.

Nada exagerado.

---

# Estilo

O design deve transmitir:

- Elegância
- Minimalismo
- Organização
- Rapidez
- Tecnologia

Evitar:

- Gradientes exagerados
- Muitos ícones
- Interfaces poluídas
- Bordas chamativas
- Sombras pesadas

---

# Componentes

Todos os componentes devem seguir um padrão único.

Botões

- cantos arredondados
- leves animações
- feedback ao clicar

Cards

- discretos
- fundo escuro
- borda sutil

Campos

- fundo escuro
- foco em verde

Scroll

- fino
- discreto

---

# Layout

Sempre utilizar bastante respiro.

Nunca criar telas apertadas.

O usuário deve sentir leveza.

---

# Estrutura

Cada funcionalidade será um módulo.

```
lib/

features/

shared/

core/

app/
```

Dentro de cada módulo:

```
feature/

data/

models/

presentation/

viewmodels/

widgets/
```

---

# Arquitetura

Flutter Desktop

Arquitetura baseada em MVVM.

Separação clara entre:

- UI
- Estado
- Serviços
- Persistência

Evitar lógica de negócio dentro da interface.

---

# Banco de Dados

Inicialmente:

Isar

Todos os dados permanecerão locais.

Nenhuma sincronização será implementada inicialmente.

---

# Plataforma

Primeira plataforma:

macOS

No futuro:

- Windows
- Linux

---

# Menu Bar

O Evergreen deverá possuir um ícone na barra superior do macOS.

Ao clicar:

- Abrir painel principal
- Acessar configurações
- Encerrar aplicativo

---

# Inicialização

O aplicativo deverá possuir opção para:

- iniciar junto ao macOS

Quando iniciado:

- abrir minimizado
- permanecer em background

---

# Janela Principal

O Evergreen possuirá uma janela principal.

Essa janela poderá permanecer fechada.

Os módulos continuarão funcionando normalmente.

---

# Atalhos Globais

Cada módulo poderá registrar atalhos globais.

Exemplo:

Pin

```
⌘ + Shift + V
```

Ao pressionar:

Abrir a pesquisa do histórico da área de transferência.

Independentemente do aplicativo aberto.

---

# Pin

## Objetivo

Registrar tudo que o usuário copia.

Tipos suportados inicialmente:

- Texto
- Links

Posteriormente:

- Imagens
- Arquivos
- Rich Text

---

## Interface

Ao abrir:

```
──────────────────────────

Pesquisar...

──────────────────────────

Flutter

git pull origin develop

https://github...

Senha...

Comando Terminal...

──────────────────────────
```

Pesquisa em tempo real.

Teclas:

↑ ↓

Selecionam os itens.

Enter

Copia novamente.

Esc

Fecha.

---

# Performance

Prioridades:

- abertura instantânea
- baixo consumo de memória
- animações em 60 FPS
- banco extremamente rápido

---

# UX

Toda interação deve exigir o menor número possível de cliques.

O usuário deve conseguir executar qualquer ação em poucos segundos.

---

# Qualidade de Código

Todo código deverá seguir:

- SOLID
- Clean Code
- Arquivos pequenos
- Componentização
- Widgets reutilizáveis
- Boa documentação

Evitar:

- Widgets gigantes
- Arquivos enormes
- Código duplicado

---

# Objetivo Final

O Evergreen deverá se tornar uma suíte pessoal de produtividade para desktop, reunindo ferramentas independentes em uma única aplicação elegante, rápida e totalmente local.

Cada módulo deve parecer um aplicativo completo por si só, mas compartilhar a mesma identidade visual, arquitetura e experiência de uso.
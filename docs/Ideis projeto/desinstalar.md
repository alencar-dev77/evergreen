# Desinstalar o Evergreen

> Status: **implementado**. Issue #125.

Arrastar o Evergreen para o Lixo deixa quase tudo para trás: o banco, os
backups, o áudio das reuniões e as imagens do Pin (em
`~/Library/Application Support`), o modelo que separa as vozes do Echo (na
pasta do FluidAudio), as preferências, o item de início e as permissões de Acessibilidade, Microfone e
Gravação de Tela, que continuam listadas nos Ajustes do Sistema apontando para
um app que não existe mais. "Desinstalar" faz o resto.

## As duas portas

- **O menu da barra**: "Desinstalar Evergreen…", entre as preferências e o
  encerrar. As reticências avisam que o clique ainda pergunta: ele abre o Hub
  na tela do aplicativo com a confirmação já na tela
  (`HubDestination.uninstall`). A confirmação é um modal, e modal só existe no
  Hub — a janela 0 é um painel flutuante.
- **A tela do aplicativo**: o cartão "Sem volta", por último, como manda a ordem
  dos tópicos.

A pergunta diz o que vai, item por item, e avisa que os backups vão junto: eles
moram na pasta do aplicativo, e quem desinstala para reinstalar precisa saber
disso antes do sim.

## O que sai, e em que ordem

Tudo no lado nativo (`UninstallChannel`, em `MainFlutterWindow.swift`), num
método só, que termina com `exit(0)`. Sem volta ao Dart no meio: nenhum serviço
da janela 0 tem a vez de escrever de novo numa pasta que acabou de ser apagada.

1. O item de início (`SMAppService.mainApp.unregister`).
2. As permissões (`tccutil reset All <bundle id>`). Não pede senha de
   administrador. **Precisa vir antes de o app ir para o Lixo**: o `tccutil`
   acha o app pelo identificador no LaunchServices, e com o bundle fora do lugar
   ele responde "identificador desconhecido".
3. As notificações entregues e as agendadas. Cedo, porque o pedido ao sistema
   é assíncrono e precisa de tempo para sair antes do `exit`.
4. O registro no LaunchServices (`lsregister -u`), para o app não sobrar em
   "Abrir com".
5. O bundle vai para o Lixo (`trashItem`), e não é apagado: o Lixo é o
   desfazer do macOS. Sem permissão para mover, o Finder mostra o app.
6. As pastas com o identificador em `~/Library` (`Application Support`,
   `Caches`, `HTTPStorages`, `WebKit`, `Saved Application State`) e o modelo do
   FluidAudio (`Application Support/FluidAudio/Models/speaker-diarization`).
   Do FluidAudio sai só o nosso modelo: a pasta é do pacote, e outro app que o
   use dividiria a mesma. **As pastas vêm por último**, logo antes do `exit`.
   O Dart fica parado enquanto o método roda (no macOS ele roda na thread
   principal), mas as tarefas do Swift não param, e o Echo exportando o áudio
   de uma reunião recriaria a pasta dele.
7. As preferências, pelo `UserDefaults.removePersistentDomain` e só depois o
   arquivo. Apagar só o `.plist` deixaria a cópia do `cfprefsd` em memória
   escrevê-lo de volta.

Cada passo é tentativa. Um que falhe não impede os outros, porque uma
desinstalação pela metade é pior que uma com uma sobra.

## O que fica

- **A linha em Ajustes → Notificações.** Quem guarda essa linha é o macOS, e não
  há API para o app apagá-la.
- **Os modelos do `Speech`.** São do sistema e servem a outros apps.
- **Uma build de trabalho** usa o mesmo identificador da instalada. Desinstalar
  por ela apaga os dados de verdade, e o que vai para o Lixo é a build.

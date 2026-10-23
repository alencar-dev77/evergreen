# Política de privacidade

Última atualização: 22 de outubro de 2026.

O Evergreen é um aplicativo para macOS que roda inteiro no seu Mac. Ele não tem
conta, servidor, sincronização, anúncio nem telemetria. **Quem o desenvolve não
recebe nenhum dado seu**: nem o que você usa, nem como você usa, nem que você
instalou.

Esta política diz o que o Evergreen guarda no seu Mac, por quanto tempo, e as
quatro únicas ocasiões em que algo sai do aplicativo.

## O que fica no seu Mac

Tudo o que o Evergreen guarda fica na pasta do seu usuário do macOS, em três
lugares:

- `~/Library/Application Support/com.alencardev.evergreen/` — o banco de dados,
  as imagens do Pin, o áudio das reuniões, os backups, as exportações e o
  registro de diagnóstico;
- `~/Library/Preferences/com.alencardev.evergreen.plist` — as preferências;
- `~/Library/Application Support/FluidAudio/Models/` — o modelo que separa as
  vozes do Echo, depois de baixado.

E, só enquanto uma atualização baixa, o instalador dela fica em
`~/Library/Caches/com.alencardev.evergreen/`.

| Módulo | O que guarda | Por quanto tempo |
|---|---|---|
| **Pin** | O que você copia (texto e imagem), com a data e o tipo | Os 200 itens mais recentes (ajustável); os fixados ficam até você tirar |
| **Focus** | As sessões de foco: início, duração e o que você escreveu sobre elas | As últimas 4 semanas |
| **Leaf** | As anotações da parede, no máximo nove | Até você apagar |
| **Awake** | Quando a trava foi ligada e por quanto tempo | As últimas 4 semanas |
| **Echo** | A transcrição, o resumo e o título de cada reunião | As 100 mais recentes (ajustável); as marcadas com estrela ficam |
| **Echo** | O áudio da reunião | 14 dias, ou menos se a reunião sair antes; a estrela guarda |
| **Echo** | O resumo e a transcrição que você exportar, em `Exportações/` | Até você apagar o arquivo |
| **Nest** | Quando você enviou arquivos da prateleira e quantos eram — nunca o nome nem o caminho | As últimas 4 semanas |
| **Nest** | As pastas favoritas, com o caminho delas | Até você tirar da lista |
| **Track** | O parágrafo que o modelo local escreve sobre cada dia; o resto ele lê dos outros módulos | Até o dia mudar ou o parágrafo ser refeito |
| **Aplicativo** | As preferências e o nome que você escolher informar | Até você mudar |
| **Backup** | Cópias do banco de dados, feitas por você ou automaticamente, e as de segurança feitas antes de restaurar | As 5 mais recentes, mais até 3 de segurança |
| **Diagnóstico** | Um registro de erros do próprio app | Cerca de 3 MB; os mais antigos saem primeiro |

**O Pin guarda tudo o que passa pela área de transferência, inclusive senhas.**
Isso fica só no seu Mac — e vai junto em cada backup, que é uma cópia do banco.
Para que um item não fique no histórico, apague-o no painel do Pin (`⌘⌫`) ou
desligue o módulo.

**O registro de diagnóstico não guarda conteúdo**: nada do que você copiou,
anotou, gravou ou o nome de um arquivo seu. Ele só sai do seu Mac se você usar
"Copiar diagnóstico" e colar o texto em algum lugar.

## O que sai do seu Mac

Algo sai do Evergreen em só quatro situações, e nenhuma delas envia o que você
guardou:

1. **O modelo que separa as vozes do Echo.** Na primeira reunião com fala do
   outro lado, o Evergreen baixa uma vez esse modelo do
   [Hugging Face](https://huggingface.co). É só um download: o Hugging Face vê
   o endereço IP de quem baixa, como em qualquer download, e nada além disso.
   O áudio e a transcrição nunca saem do Mac.
2. **O modelo de transcrição do Echo.** Na primeira reunião num idioma, o
   Evergreen pede ao macOS o modelo de reconhecimento de fala daquele idioma, e
   quem o baixa é o próprio macOS, dos servidores da Apple. A transcrição
   acontece no seu Mac: nenhum áudio é enviado.
3. **O LM Studio, se você o escolher como modelo local.** O texto da reunião ou
   do dia vai para o servidor do LM Studio no endereço `127.0.0.1`, que é o
   próprio Mac. O Evergreen não aceita outro endereço.
4. **A procura por versão nova.** Uma vez por dia, e quando você clica em
   "Procurar", o Evergreen lê no GitHub um arquivo que diz qual é a versão mais
   nova (o `appcast.xml` do último release). O GitHub vê o endereço IP e,
   como em todo pedido de app, o nome e a versão do Evergreen; não vai perfil
   do sistema nem nada do que você guardou. Se houver versão nova, o Evergreen
   pergunta antes de baixar. Dá para desligar em Configurações → Aplicativo →
   **Atualizações**: desligada, nenhuma procura automática sai — só a que você
   pedir no botão "Procurar".

O resumo feito pelo Apple Intelligence também roda no seu Mac, pelo modelo
local do sistema.

**O que chega a quem desenvolve** é só o que o GitHub conta de qualquer
arquivo publicado: quantas vezes cada um foi baixado — o instalador e o
`appcast.xml` das procuras por versão nova. É um número por arquivo, sem nada
que diga quem baixou, de onde ou quando. O Evergreen não tem identificador de
instalação nem telemetria própria.

## Permissões do macOS

| Permissão | Para quê |
|---|---|
| **Acessibilidade** | O colar automático do Pin, que vem desligado. Sem ela, o item só é copiado |
| **Microfone** | O Echo grava a sua voz na reunião |
| **Gravação de Tela** | O Echo grava o som do computador (o outro lado da reunião). Ele não grava imagem da tela |
| **Notificações** | Avisar o fim de uma sessão do Focus, o fim do prazo do Awake, os lembretes do Leaf e o resumo da semana do Track |

Cada uma pode ser revogada a qualquer momento em Ajustes do Sistema →
Privacidade e Segurança.

## Gravar reuniões

O Echo grava conversas com outras pessoas. Avise quem está na reunião que ela
está sendo gravada e respeite as regras do lugar onde você está e da empresa em
que trabalha. Os dados dessas pessoas ficam com você, no seu Mac, e cuidar
deles é responsabilidade de quem grava.

## Apagar tudo

- O Pin, o Focus, o Leaf e o Echo têm como apagar o próprio histórico, na tela
  de cada um. O registro do Awake e o do Nest se apagam sozinhos depois de 4
  semanas: eles só contam quando e quanto, para o Track.
- **Configurações → Aplicativo → Desinstalar o Evergreen** apaga os dados, as
  preferências, as permissões e o próprio app. Arrastar só o app para o Lixo
  deixa os dados no disco.

## Contato

Dúvidas sobre esta política podem ser abertas como
[issue no GitHub](https://github.com/alencar-dev77/evergreen/issues). Para
relatar uma falha de segurança sem deixá-la pública, use
[Report a vulnerability](https://github.com/alencar-dev77/evergreen/security/advisories/new).

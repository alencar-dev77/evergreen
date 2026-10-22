# Política de privacidade

Última atualização: 22 de outubro de 2026.

O Evergreen é um aplicativo para macOS que roda inteiro no seu Mac. Ele não tem
conta, servidor, sincronização, anúncio nem telemetria. **Quem o desenvolve não
recebe nenhum dado seu**: nem o que você usa, nem como você usa, nem que você
instalou.

Esta política diz o que o Evergreen guarda no seu Mac, por quanto tempo, e as
duas únicas ocasiões em que ele se conecta a algo fora do aplicativo.

## O que fica no seu Mac

Tudo o que o Evergreen guarda fica em
`~/Library/Application Support/com.alencardev.evergreen/`, e só o seu usuário
do macOS tem acesso.

| Módulo | O que guarda | Por quanto tempo |
|---|---|---|
| **Pin** | O que você copia (texto e imagem), com a data e o tipo | Os 200 itens mais recentes (ajustável); os fixados ficam até você tirar |
| **Focus** | As sessões de foco: início, duração e o que você escreveu sobre elas | As últimas 4 semanas |
| **Leaf** | As anotações da parede, no máximo nove | Até você apagar |
| **Awake** | Quando a trava foi ligada e por quanto tempo | Até você apagar |
| **Echo** | A transcrição, o resumo e o título de cada reunião | As 100 mais recentes (ajustável); as marcadas com estrela ficam |
| **Echo** | O áudio da reunião | 14 dias, ou menos se a reunião sair antes; a estrela guarda |
| **Nest** | Quando você enviou arquivos da prateleira e quantos eram — nunca o nome nem o caminho | Até você apagar |
| **Track** | Nada próprio: ele lê o que os outros módulos guardaram | — |
| **Aplicativo** | As preferências e o nome que você escolher informar | Até você mudar |
| **Backup** | Cópias do banco de dados, feitas por você ou automaticamente | As 5 mais recentes |
| **Diagnóstico** | Um registro de erros do próprio app | Até 3 MB, os mais antigos saem primeiro |

**O Pin guarda tudo o que passa pela área de transferência, inclusive senhas.**
Isso fica só no seu Mac. Para que um item não fique no histórico, apague-o
no painel do Pin (`⌘⌫`) ou desligue o módulo.

**O registro de diagnóstico não guarda conteúdo**: nada do que você copiou,
anotou, gravou ou o nome de um arquivo seu. Ele só sai do seu Mac se você usar
"Copiar diagnóstico" e colar o texto em algum lugar.

## O que sai do seu Mac

O Evergreen se conecta a algo fora dele em só duas situações, e nenhuma delas
envia o que você guardou:

1. **O modelo que separa as vozes do Echo.** Na primeira reunião com fala do
   outro lado, o Evergreen baixa uma vez esse modelo do
   [Hugging Face](https://huggingface.co). É só um download: o Hugging Face vê
   o endereço IP de quem baixa, como em qualquer download, e nada além disso.
   O áudio e a transcrição nunca saem do Mac.
2. **O LM Studio, se você o escolher como modelo local.** O texto da reunião ou
   do dia vai para o servidor do LM Studio no endereço `127.0.0.1`, que é o
   próprio Mac. O Evergreen não aceita outro endereço.

O resumo feito pelo Apple Intelligence também roda no seu Mac, pelo modelo
local do sistema.

Se um dia o Evergreen passar a verificar se há versão nova, esta política será
atualizada antes, dizendo o que essa verificação envia.

## Permissões do macOS

| Permissão | Para quê |
|---|---|
| **Acessibilidade** | Os atalhos globais e o colar automático do Pin |
| **Microfone** | O Echo grava a sua voz na reunião |
| **Gravação de Tela** | O Echo grava o som do computador (o outro lado da reunião). Ele não grava imagem da tela |

Cada uma pode ser revogada a qualquer momento em Ajustes do Sistema →
Privacidade e Segurança.

## Gravar reuniões

O Echo grava conversas com outras pessoas. Avise quem está na reunião que ela
está sendo gravada e respeite as regras do lugar onde você está e da empresa em
que trabalha. Os dados dessas pessoas ficam com você, no seu Mac, e cuidar
deles é responsabilidade de quem grava.

## Apagar tudo

- Cada módulo tem como apagar o próprio histórico, na tela dele.
- **Configurações → Aplicativo → Desinstalar o Evergreen** apaga os dados, as
  preferências, as permissões e o próprio app. Arrastar só o app para o Lixo
  deixa os dados no disco.

## Contato

Dúvidas sobre esta política podem ser abertas como
[issue no GitHub](https://github.com/alencar-dev77/evergreen/issues). Para
relatar uma falha de segurança sem deixá-la pública, use
[Report a vulnerability](https://github.com/alencar-dev77/evergreen/security/advisories/new).

# Captura de clipboard: por que ela saiu do Dart

> Decisão tomada em 14/08/2026, resolvendo a issue #14.
> Registrada porque o `AGENTS.md` manda preferir Flutter puro e documentar em
> `docs/` toda vez que uma alternativa nativa vencer.

---

## O que existia

`ClipboardWatcher` era um `Timer` em Dart:

```dart
_timer = Timer.periodic(const Duration(milliseconds: 600), (_) => _poll());

Future<void> _poll() async {
  final content = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  if (content == null || content.trim().isEmpty) return;
  if (content == _lastSeen) return;   // <- o problema mora aqui
  _lastSeen = content;
  _controller.add(content);
}
```

## Por que não bastava

O polling comparava **conteúdo**. Conteúdo não é evento, e um gerenciador de
área de transferência precisa do evento:

1. **Recopiar a mesma coisa era invisível.** A string era igual à da volta
   anterior, `_poll` desistia na terceira linha, e o `copiedAt` do item não era
   atualizado — o item não subia para o topo. Para quem usa o Pin, a última
   coisa copiada simplesmente não era a primeira da lista.
2. **A leitura era cara.** `Clipboard.getData` traz a string inteira do
   pasteboard pelo canal de plataforma. Diminuir o intervalo para perder menos
   cópias significava pagar esse custo mais vezes por segundo — o remédio piorava
   a doença.

Nenhum dos dois se resolvia em Dart, porque em Dart não existe outra coisa para
observar além do conteúdo.

## O que passou a existir

`PasteboardWatcherChannel`, em `macos/Runner/MainFlutterWindow.swift`, observa
`NSPasteboard.general.changeCount` — um inteiro que o sistema incrementa a cada
escrita no pasteboard. **A mudança dele é o evento**, independente de o conteúdo
ser igual ao anterior.

Como a leitura não sai do processo nativo, o ciclo passou de 600ms para 200ms
sem ficar mais caro que antes. O conteúdo só atravessa o canal quando há
mudança de fato.

A interface Dart não mudou: `ClipboardWatcher.onCopy`, `start`, `stop`,
`acknowledge` e `isRunning` continuam com as mesmas assinaturas, e a ViewModel
não soube de nada.

## O que continua verdade

O macOS **não notifica** mudança de pasteboard — nem em Swift. Não existe
`NSPasteboardDidChangeNotification`; o `changeCount` é a forma canônica de
descobrir, e é o que Maccy, Raycast e afins também fazem. Continua sendo
polling; o que mudou foi o custo e a precisão de cada ciclo.

Uma consequência sobrevive: **duas cópias dentro do mesmo ciclo ainda viram
uma**. Quando o `changeCount` pula mais de um entre dois ciclos, o conteúdo
intermediário já foi substituído no pasteboard e não há de onde recuperá-lo.
A janela caiu de 600ms para 200ms; ela não fechou, e nenhuma API do sistema
fecha.

## Detalhes que valem lembrar

- **O canal é registrado nos dois engines, mas só um chama `start`.** Cada
  engine (janela 0 e Hub) registra o seu `FlutterMethodChannel`; o Swift guarda
  o canal de **quem pediu a captura**, que é sempre o da janela 0. Sem isso o
  aviso de cópia poderia sair pelo engine do Hub, onde ninguém escuta.
- **`acknowledge` confere o conteúdo antes de engolir o evento.** Se outro app
  copiou alguma coisa entre a escrita do Pin e a marcação, o `changeCount` que
  chegou é dele, não nosso — engoli-lo apagaria uma cópia de verdade.
- **`acknowledge` é aguardado no `copyItem`.** É o que garante que a marcação
  chegue ao nativo antes do próximo ciclo de leitura.
- **O aviso inicial no `start` foi mantido.** O que já estava copiado quando o
  Evergreen subiu entra no histórico, como antes.

## O que ficou de fora

Ignorar conteúdo marcado como transitório ou sigiloso
(`org.nspasteboard.ConcealedType`, o que gerenciadores de senha escrevem) é
possível a partir daqui e não foi feito nesta mudança — hoje uma senha copiada
do 1Password entra no histórico como qualquer texto. Vale uma issue própria.

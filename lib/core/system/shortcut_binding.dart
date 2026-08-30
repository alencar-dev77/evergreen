import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// As modificadoras que um atalho global do Evergreen pode usar.
///
/// A ordem dos valores é a **ordem de exibição** dos key-caps, e ela começa no
/// `⌘` porque é assim que a casa escreve os atalhos desde a v0.1 — `⌘⇧C` está
/// no README, no menu da barra e em toda a documentação. O macOS canônico
/// escreveria `⇧⌘C`; trocar agora reescreveria tudo o que já foi ensinado sem
/// ganhar nada.
///
/// `capsLock` e `fn` ficam de fora de propósito: o `hotkey_manager` os aceita,
/// mas nenhum dos dois é uma modificadora que se segura para apertar outra
/// tecla — `⇪` é um travamento e `fn` muda o significado das teclas de função.
enum ShortcutModifier {
  meta('⌘', 'Command'),
  control('⌃', 'Control'),
  option('⌥', 'Option'),
  shift('⇧', 'Shift');

  const ShortcutModifier(this.cap, this.spoken);

  /// O símbolo desenhado no key-cap.
  final String cap;

  /// Como o leitor de tela chama a tecla — ver `EgShortcutDisplay`.
  final String spoken;

  static ShortcutModifier? fromName(String name) {
    for (final modifier in values) {
      if (modifier.name == name) return modifier;
    }
    return null;
  }

  /// As modificadoras que estão fisicamente pressionadas agora.
  ///
  /// Lê o [HardwareKeyboard], e não o evento que chegou: quem grava um atalho
  /// aperta as modificadoras **antes** da tecla, e no evento da tecla final
  /// elas já não são novidade nenhuma.
  static Set<ShortcutModifier> pressed() {
    final keyboard = HardwareKeyboard.instance;

    return {
      if (keyboard.isMetaPressed) meta,
      if (keyboard.isControlPressed) control,
      if (keyboard.isAltPressed) option,
      if (keyboard.isShiftPressed) shift,
    };
  }
}

/// Uma combinação de teclas: a tecla final e as modificadoras seguradas.
///
/// Guarda a tecla **física**, e não a lógica, pelo mesmo motivo que o
/// `hotkey_manager` registra a física: o atalho é a posição no teclado, não o
/// caractere. Num teclado ABNT2 a tecla onde mora o `;` do ANSI produz `ç`, e
/// um atalho gravado como "a tecla ao lado do L" continua sendo a mesma tecla
/// depois de a pessoa trocar o layout de entrada.
@immutable
class ShortcutBinding {
  const ShortcutBinding({required this.key, required this.modifiers});

  final PhysicalKeyboardKey key;
  final Set<ShortcutModifier> modifiers;

  /// A combinação como key-caps, na ordem de exibição da casa.
  ///
  /// É o que alimenta o `EgShortcutDisplay` da tela de preferências e o texto
  /// do item no menu da barra de status.
  List<String> get caps => [
    for (final modifier in ShortcutModifier.values)
      if (modifiers.contains(modifier)) modifier.cap,
    label,
  ];

  /// A combinação escrita em linha: `⌘⇧C`.
  String get compact => caps.join();

  /// O nome da tecla final no key-cap (`C`, `1`, `→`, `F5`).
  ///
  /// Uma tecla fora do mapa devolve o `debugName` do Flutter, que é feio mas
  /// legível — e não acontece por caminho nenhum da interface, porque
  /// `ShortcutRules` recusa a gravação antes disso.
  String get label => ShortcutKeys.labelOf(key) ?? key.debugName ?? '?';

  /// Como a combinação é falada: "Command Shift C".
  String get spoken => [
    for (final modifier in ShortcutModifier.values)
      if (modifiers.contains(modifier)) modifier.spoken,
    label,
  ].join(' ');

  /// Como a combinação é gravada no disco: `meta+shift:6`.
  ///
  /// O número é o `usbHidUsage` da tecla física — o mesmo identificador que o
  /// `hotkey_manager` manda para o lado nativo, e o único que não muda com o
  /// layout de teclado nem com a versão do Flutter.
  String get storageValue {
    final names = [
      for (final modifier in ShortcutModifier.values)
        if (modifiers.contains(modifier)) modifier.name,
    ];

    return '${names.join('+')}:${key.usbHidUsage}';
  }

  /// O caminho de volta. Devolve `null` para qualquer coisa que não sirva —
  /// texto de outra versão, tecla que o Flutter não conhece mais, arquivo
  /// editado à mão. Quem chama cai no padrão, que é o comportamento certo para
  /// uma preferência ilegível.
  static ShortcutBinding? parse(String? value) {
    if (value == null) return null;

    final parts = value.split(':');
    if (parts.length != 2) return null;

    final usage = int.tryParse(parts[1]);
    if (usage == null) return null;

    final key = PhysicalKeyboardKey.findKeyByCode(usage);
    if (key == null) return null;

    final modifiers = <ShortcutModifier>{};
    for (final name in parts[0].split('+')) {
      if (name.isEmpty) continue;

      final modifier = ShortcutModifier.fromName(name);
      if (modifier == null) return null;
      modifiers.add(modifier);
    }

    return ShortcutBinding(key: key, modifiers: modifiers);
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutBinding &&
      other.key == key &&
      setEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, storageValue);

  @override
  String toString() => 'ShortcutBinding($compact)';
}

/// O nome de cada tecla física num key-cap.
///
/// Escrito aqui, e não herdado do `keyLabel` do `hotkey_manager`, por duas
/// razões: o mapa dele desenha o Backspace como `←` (que é a seta para a
/// esquerda, já usada por outra tecla) e o Enter como `↩︎`, enquanto o
/// Evergreen escreve `⌫` e `⏎` desde a v0.1 — e porque **este mapa é a lista de
/// teclas permitidas**. Uma tecla fora dele não vira atalho: é assim que o
/// gravador recusa `⇪`, `fn` e as teclas de mídia sem precisar enumerá-las.
abstract final class ShortcutKeys {
  /// `final`, e não `const`: [PhysicalKeyboardKey] sobrescreve `==`, e o Dart
  /// não deixa uma chave assim entrar num mapa constante.
  static final _labels = <PhysicalKeyboardKey, String>{
    PhysicalKeyboardKey.keyA: 'A',
    PhysicalKeyboardKey.keyB: 'B',
    PhysicalKeyboardKey.keyC: 'C',
    PhysicalKeyboardKey.keyD: 'D',
    PhysicalKeyboardKey.keyE: 'E',
    PhysicalKeyboardKey.keyF: 'F',
    PhysicalKeyboardKey.keyG: 'G',
    PhysicalKeyboardKey.keyH: 'H',
    PhysicalKeyboardKey.keyI: 'I',
    PhysicalKeyboardKey.keyJ: 'J',
    PhysicalKeyboardKey.keyK: 'K',
    PhysicalKeyboardKey.keyL: 'L',
    PhysicalKeyboardKey.keyM: 'M',
    PhysicalKeyboardKey.keyN: 'N',
    PhysicalKeyboardKey.keyO: 'O',
    PhysicalKeyboardKey.keyP: 'P',
    PhysicalKeyboardKey.keyQ: 'Q',
    PhysicalKeyboardKey.keyR: 'R',
    PhysicalKeyboardKey.keyS: 'S',
    PhysicalKeyboardKey.keyT: 'T',
    PhysicalKeyboardKey.keyU: 'U',
    PhysicalKeyboardKey.keyV: 'V',
    PhysicalKeyboardKey.keyW: 'W',
    PhysicalKeyboardKey.keyX: 'X',
    PhysicalKeyboardKey.keyY: 'Y',
    PhysicalKeyboardKey.keyZ: 'Z',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.minus: '-',
    PhysicalKeyboardKey.equal: '=',
    PhysicalKeyboardKey.bracketLeft: '[',
    PhysicalKeyboardKey.bracketRight: ']',
    PhysicalKeyboardKey.backslash: r'\',
    PhysicalKeyboardKey.semicolon: ';',
    PhysicalKeyboardKey.quote: "'",
    PhysicalKeyboardKey.backquote: '`',
    PhysicalKeyboardKey.comma: ',',
    PhysicalKeyboardKey.period: '.',
    PhysicalKeyboardKey.slash: '/',
    PhysicalKeyboardKey.space: '␣',
    PhysicalKeyboardKey.enter: '⏎',
    PhysicalKeyboardKey.backspace: '⌫',
    PhysicalKeyboardKey.delete: '⌦',
    PhysicalKeyboardKey.arrowUp: '↑',
    PhysicalKeyboardKey.arrowDown: '↓',
    PhysicalKeyboardKey.arrowLeft: '←',
    PhysicalKeyboardKey.arrowRight: '→',
    PhysicalKeyboardKey.home: '↖',
    PhysicalKeyboardKey.end: '↘',
    PhysicalKeyboardKey.pageUp: '⇞',
    PhysicalKeyboardKey.pageDown: '⇟',
    PhysicalKeyboardKey.f1: 'F1',
    PhysicalKeyboardKey.f2: 'F2',
    PhysicalKeyboardKey.f3: 'F3',
    PhysicalKeyboardKey.f4: 'F4',
    PhysicalKeyboardKey.f5: 'F5',
    PhysicalKeyboardKey.f6: 'F6',
    PhysicalKeyboardKey.f7: 'F7',
    PhysicalKeyboardKey.f8: 'F8',
    PhysicalKeyboardKey.f9: 'F9',
    PhysicalKeyboardKey.f10: 'F10',
    PhysicalKeyboardKey.f11: 'F11',
    PhysicalKeyboardKey.f12: 'F12',
  };

  /// As teclas que **são** uma modificadora.
  ///
  /// `final` pela mesma razão do mapa acima.
  static final _modifiers = <PhysicalKeyboardKey>{
    PhysicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight,
    PhysicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight,
    PhysicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight,
    PhysicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight,
    PhysicalKeyboardKey.capsLock,
    PhysicalKeyboardKey.fn,
  };

  static String? labelOf(PhysicalKeyboardKey key) => _labels[key];

  /// A tecla é uma modificadora?
  ///
  /// Quem grava um atalho aperta `⌘` antes da letra, e o `⌘` chega aqui como um
  /// `KeyDownEvent` igual a qualquer outro. Sem esta pergunta, toda gravação
  /// terminaria na primeira modificadora, com um "⌘" sozinho recusado pelas
  /// regras.
  static bool isModifier(PhysicalKeyboardKey key) => _modifiers.contains(key);

  /// A tecla pode ser a tecla final de um atalho?
  ///
  /// O `Esc` e o `Tab` estão fora não por serem do sistema, mas por serem as
  /// duas saídas do próprio gravador: quem aperta Esc está desistindo, e quem
  /// aperta Tab está indo para o controle seguinte.
  static bool isUsable(PhysicalKeyboardKey key) => _labels.containsKey(key);
}

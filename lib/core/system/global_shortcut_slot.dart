import 'package:flutter/services.dart';

import 'shortcut_binding.dart';

/// Cada coisa do Evergreen que se abre por um atalho global.
///
/// Sete: os seis painéis flutuantes e o Hub. O Track fica de fora porque não
/// tem painel — ele só existe dentro do Hub, e a janela que o contém já tem o
/// atalho dela.
///
/// O padrão de cada um mora aqui, e é o **único** lugar em que ele mora: até a
/// v0.14 a mesma combinação estava escrita três vezes (no `HotKey`, na lista de
/// key-caps da tela de preferências e como texto solto no item do menu da barra
/// de status), e trocar a tecla do Nest exigiu mexer nas três. Com o atalho
/// virando preferência, três fontes de verdade viram três formas de mostrar
/// coisas diferentes para a mesma pessoa.
enum GlobalShortcutSlot {
  /// `⌘⇧C` — o histórico da área de transferência.
  pin(
    identifier: 'evergreen.pin.toggle',
    openLabel: 'Abrir Pin',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.keyC,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ),

  /// `⌘⇧F` — o cronômetro de foco.
  focus(
    identifier: 'evergreen.focus.toggle',
    openLabel: 'Abrir Focus',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.keyF,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ),

  /// `⌘⇧D` — a parede de anotações.
  leaf(
    identifier: 'evergreen.leaf.toggle',
    openLabel: 'Abrir Leaf',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.keyD,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ),

  /// `⌘⇧X` — a trava que mantém o Mac acordado.
  ///
  /// Sem mnemônico, e de propósito: `⌘⇧A` é "ir para Aplicativos" no Finder e
  /// `⌘⇧D` ficou com o Leaf, então sobrou a tecla que ninguém disputa.
  awake(
    identifier: 'evergreen.awake.toggle',
    openLabel: 'Abrir Awake',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.keyX,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ),

  /// `⌘⇧E` — a gravação da reunião.
  ///
  /// `E` de Echo, e livre onde importa: `⌘⇧T` seria mnemônico de transcrever,
  /// mas como atalho global roubaria "reabrir aba" de todo navegador — e
  /// reunião acontece dentro do navegador.
  echo(
    identifier: 'evergreen.echo.toggle',
    openLabel: 'Abrir Echo',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.keyE,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ),

  /// `⌘⇧R` — a prateleira de arquivos.
  ///
  /// Era `⌘⇧S`, de *shelf*, e a letra saiu de circulação: `⌘⇧S` é o "Salvar
  /// como" que qualquer app pode ter, e como atalho global ele sequestra o de
  /// todos.
  nest(
    identifier: 'evergreen.nest.toggle',
    openLabel: 'Abrir Nest',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.keyR,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  ),

  /// `⌘⇧,` — as preferências.
  ///
  /// `⌘,` é a convenção de preferências do macOS, mas como atalho global ele
  /// roubaria a tecla de todos os outros apps. O `⇧` promove a convenção ao
  /// prefixo da casa sem trocar o mnemônico.
  hub(
    identifier: 'evergreen.hub.open',
    openLabel: 'Abrir preferências',
    fallback: ShortcutBinding(
      key: PhysicalKeyboardKey.comma,
      modifiers: {ShortcutModifier.meta, ShortcutModifier.shift},
    ),
  );

  const GlobalShortcutSlot({
    required this.identifier,
    required this.openLabel,
    required this.fallback,
  });

  /// Como o `hotkey_manager` chama este atalho do lado nativo.
  ///
  /// Estável para sempre: ele é a chave que casa o evento que volta do sistema
  /// com o handler registrado. Trocar a tecla não troca o identificador.
  final String identifier;

  /// O rótulo da linha na tela de preferências.
  final String openLabel;

  /// A combinação de fábrica — para onde "Restaurar padrão" volta.
  final ShortcutBinding fallback;

  /// Como a chave da preferência é escrita no disco.
  String get storageKey => 'shortcut.$name';
}

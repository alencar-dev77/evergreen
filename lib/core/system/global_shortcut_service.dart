import 'package:hotkey_manager/hotkey_manager.dart';

import 'global_shortcut_slot.dart';
import 'shortcut_binding.dart';

/// Registra os atalhos globais do Evergreen no sistema.
///
/// "Global" significa a nível de sistema: o atalho dispara mesmo com outro
/// aplicativo em foco, que é o requisito central do Pin.
///
/// Até a v0.14 havia um método por módulo e a combinação era constante. Agora
/// as combinações vêm de fora — do que a pessoa gravou nas preferências — e o
/// serviço passou a ter um verbo só, [apply]: ele apaga o que estava registrado
/// e registra o que foi pedido. Registrar em cima do que já existe não é uma
/// opção no macOS: o `RegisterEventHotKey` do sistema aceita a mesma combinação
/// duas vezes e passa a disparar as duas.
class GlobalShortcutService {
  GlobalShortcutService._();

  static final instance = GlobalShortcutService._();

  /// O que está registrado agora, para o [resume] saber ao que voltar.
  Map<GlobalShortcutSlot, ShortcutBinding> _current = {};
  Map<GlobalShortcutSlot, Future<void> Function()> _handlers = {};

  /// Se os atalhos estão suspensos — ver [suspend].
  bool _suspended = false;

  bool get isSuspended => _suspended;

  /// O que está de pé agora. Vazio enquanto suspenso.
  Map<GlobalShortcutSlot, ShortcutBinding> get registered =>
      _suspended ? const {} : Map.unmodifiable(_current);

  /// Deve rodar uma única vez, antes de registrar qualquer atalho.
  Future<void> initialize() async {
    // Atalhos do sistema sobrevivem a um hot restart do engine; limpar evita
    // registros duplicados durante o desenvolvimento.
    await hotKeyManager.unregisterAll();
  }

  /// Põe no sistema exatamente [bindings] — nem mais, nem menos.
  ///
  /// [handlers] é o que cada slot faz quando a combinação é apertada, e é
  /// guardado junto: um [resume] depois de um [suspend] precisa registrar de
  /// novo, e a essa altura quem pediu o registro (o bootstrap) já foi embora.
  ///
  /// Um slot ausente de [bindings] é um módulo desligado — e desligado quer
  /// dizer que a tecla volta a ser de quem estava usando ela antes.
  Future<void> apply(
    Map<GlobalShortcutSlot, ShortcutBinding> bindings, {
    Map<GlobalShortcutSlot, Future<void> Function()>? handlers,
  }) async {
    _current = Map.of(bindings);
    if (handlers != null) _handlers = Map.of(handlers);

    if (_suspended) return;
    await _register();
  }

  /// Tira todos os atalhos do sistema **sem esquecer quais eram**.
  ///
  /// É o que a gravação de um atalho novo precisa: o Hub é um aplicativo comum
  /// e um atalho global dispara com ele na frente também, então apertar `⌘⇧C`
  /// para gravar abriria o painel do Pin por cima da tela de preferências. Com
  /// os atalhos suspensos, a combinação chega ao gravador como uma tecla
  /// qualquer.
  ///
  /// Suspender é sempre temporário e sempre do lado de cá: quem suspende é
  /// quem chama [resume] depois, e a tela que grava chama os dois em pares.
  Future<void> suspend() async {
    if (_suspended) return;

    _suspended = true;
    await hotKeyManager.unregisterAll();
  }

  Future<void> resume() async {
    if (!_suspended) return;

    _suspended = false;
    await _register();
  }

  Future<void> _register() async {
    // Sempre a partir do zero: `unregisterAll` é a única forma de garantir que
    // a combinação antiga parou de disparar antes de a nova começar.
    await hotKeyManager.unregisterAll();

    for (final entry in _current.entries) {
      final handler = _handlers[entry.key];
      if (handler == null) continue;

      await hotKeyManager.register(
        _hotKeyFor(entry.key, entry.value),
        keyDownHandler: (_) => handler(),
      );
    }
  }

  static HotKey _hotKeyFor(GlobalShortcutSlot slot, ShortcutBinding binding) {
    return HotKey(
      identifier: slot.identifier,
      key: binding.key,
      modifiers: [
        for (final modifier in binding.modifiers) _modifierOf(modifier),
      ],
      scope: HotKeyScope.system,
    );
  }

  static HotKeyModifier _modifierOf(ShortcutModifier modifier) =>
      switch (modifier) {
        ShortcutModifier.meta => HotKeyModifier.meta,
        ShortcutModifier.control => HotKeyModifier.control,
        ShortcutModifier.option => HotKeyModifier.alt,
        ShortcutModifier.shift => HotKeyModifier.shift,
      };

  Future<void> dispose() => hotKeyManager.unregisterAll();
}

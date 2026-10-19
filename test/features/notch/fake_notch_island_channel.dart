import 'dart:async';

import 'package:evergreen/core/design/tokens/eg_palette.dart';
import 'package:evergreen/features/notch/data/notch_island_channel.dart';
import 'package:evergreen/features/notch/models/notch_activity.dart';
import 'package:evergreen/features/notch/models/notch_settings.dart';

/// A ilha do notch sem janela nativa: guarda o que lhe mandaram.
class FakeNotchIslandChannel implements NotchIslandChannel {
  FakeNotchIslandChannel({this.notch = true});

  /// O que `hasNotch` responde.
  bool notch;

  final enabled = <NotchModule, bool>{};
  final updates = <List<NotchActivity>>[];
  EgPalette? palette;

  final _events = StreamController<NotchIslandEvent>.broadcast();

  /// Aperta um botão da ilha, como o lado nativo faria.
  void press(NotchModule module, String action) =>
      _events.add(NotchIslandEvent(module, action));

  @override
  Stream<NotchIslandEvent> get onAction => _events.stream;

  /// O módulo que a ilha está mostrando, como o lado nativo o diria.
  NotchModule? showing;

  final _shown = StreamController<NotchModule?>.broadcast();

  /// A ilha passa a mostrar [module] (ou nada), como o lado nativo avisaria.
  void show(NotchModule? module) {
    showing = module;
    _shown.add(module);
  }

  @override
  Stream<NotchModule?> get onShown => _shown.stream;

  @override
  Future<NotchModule?> shown() async => showing;

  @override
  void listen() {}

  @override
  Future<bool> hasNotch() async => notch;

  @override
  Future<void> setEnabled(NotchModule module, {required bool enabled}) async {
    this.enabled[module] = enabled;
  }

  @override
  Future<void> configure(EgPalette palette) async {
    this.palette = palette;
  }

  bool quiet = false;

  @override
  Future<void> setQuiet({required bool quiet}) async {
    this.quiet = quiet;
  }

  @override
  Future<void> update(List<NotchActivity> activities) async {
    updates.add(activities);
  }

  @override
  void dispose() {
    _events.close();
    _shown.close();
  }
}

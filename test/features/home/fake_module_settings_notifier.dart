import 'package:evergreen/core/system/module_settings_host.dart';

/// A janela 0 imitada em memória.
///
/// Existe porque teste de widget roda no relógio falso do binding, e nele a
/// resposta do canal de janela nunca chega — a tela que grava um atalho espera
/// o aviso voltar antes de dizer que está à escuta, e travaria para sempre. Ver
/// [ModuleSettingsNotifier].
class FakeModuleSettingsNotifier implements ModuleSettingsNotifier {
  /// Quantas vezes o mundo foi mandado se atualizar.
  int reapplied = 0;

  /// A sequência de suspensões pedidas: `[true, false]` é uma gravação inteira.
  final suspensions = <bool>[];

  @override
  Future<void> reapply() async => reapplied++;

  @override
  Future<void> setSuspended({required bool suspended}) async =>
      suspensions.add(suspended);
}

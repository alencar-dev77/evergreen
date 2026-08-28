import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/system/previous_app_focus_channel.dart';

final accessibilityPermissionProvider =
    NotifierProvider<AccessibilityPermissionViewModel, bool>(
      AccessibilityPermissionViewModel.new,
    );

/// Estado da permissão de Acessibilidade do macOS, que é o que sustenta o
/// auto-colar do Pin.
///
/// Existe como estado à parte das preferências porque não é uma preferência: o
/// usuário liga o auto-colar uma vez, e é o **sistema** que pode tirar a
/// permissão depois, sem avisar ninguém. Acontece toda vez que o binário do
/// Evergreen muda — em desenvolvimento, a cada build — e o sintoma é o pior
/// possível: o item é copiado, nada é colado e o foco não volta. Sem alguém
/// perguntando ao sistema de tempos em tempos, a tela de configurações continua
/// dizendo que está tudo ligado.
class AccessibilityPermissionViewModel extends Notifier<bool> {
  /// Começa concedida e só piora depois da resposta do sistema: o aviso é sobre
  /// algo que deu errado, e um aviso que pisca antes de a pergunta ser
  /// respondida acusa o inocente.
  @override
  bool build() {
    refresh();
    return true;
  }

  Future<void> refresh() async {
    state = await PreviousAppFocusChannel.hasAccessibilityPermission();
  }

  /// Abre o diálogo do sistema (e os Ajustes) quando ainda não há permissão.
  ///
  /// Conceder acontece fora do app, então a resposta imediata quase sempre é
  /// "ainda não" — quem atualiza o aviso de verdade é o [refresh] da próxima
  /// vez que a tela for aberta.
  Future<void> request() async {
    state = await PreviousAppFocusChannel.requestAccessibilityPermission();
  }
}

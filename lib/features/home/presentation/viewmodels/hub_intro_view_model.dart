import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/feature_flags.dart';
import '../../data/hub_intro_repository.dart';

final hubIntroViewModelProvider = NotifierProvider<HubIntroViewModel, bool>(
  HubIntroViewModel.new,
);

/// Decide se o Hub abre com a marca ou já com o conteúdo.
///
/// A resposta é lida **uma vez**, quando o Hub monta, e não volta a mudar
/// sozinha: o estado é a decisão, não a pergunta. Fechar o Hub destrói a
/// sub-janela e a próxima abertura recria tudo, então esta decisão é retomada
/// do zero a cada abertura — é por isso que quem manda é o carimbo gravado, e
/// não o fato de a janela ser nova. Sem ele, a animação rodaria sempre.
class HubIntroViewModel extends Notifier<bool> {
  late final HubIntroRepository _repository;
  late final String _stamp;

  @override
  bool build() {
    _repository = ref.watch(hubIntroRepositoryProvider);
    _stamp = ref.watch(buildStampProvider);

    // A bandeira responde antes do carimbo, e é de propósito que ela não o
    // grave: desligada, ela não "consome" a abertura desta build. Ligada de
    // volta, quem nunca viu a marca desta versão vê — a bandeira decide se a
    // cena roda, não se ela já rodou.
    return FeatureFlags.intro && _repository.shouldShow(_stamp);
  }

  /// Chamado quando a animação termina de rodar — nunca quando ela começa.
  Future<void> complete() async {
    if (!state) return;
    state = false;
    await _repository.markSeen(_stamp);
  }
}

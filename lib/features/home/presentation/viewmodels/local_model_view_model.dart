import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/local_model/lm_studio_http.dart';
import '../../../../core/local_model/lm_studio_launcher.dart';
import '../../../../core/local_model/lm_studio_local_model.dart';
import '../../../../core/local_model/local_model.dart';
import 'app_settings_view_model.dart';

/// Em que pé está o servidor do LM Studio, visto daqui.
enum LmStudioServerState {
  /// A origem é o Apple Intelligence: ninguém pergunta nada ao LM Studio.
  idle,

  /// Ainda não respondeu à primeira pergunta.
  checking,

  /// O `lms` não existe nesta máquina.
  notInstalled,

  /// Instalado, e o servidor está desligado.
  offline,

  online,
}

@immutable
class LocalModelStatus {
  const LocalModelStatus({
    this.server = LmStudioServerState.idle,
    this.models = const [],
    this.isStarting = false,
  });

  final LmStudioServerState server;

  /// Só os que escrevem texto — os de embedding ficam de fora.
  final List<LmStudioModel> models;

  /// O "Ligar" foi apertado e o servidor ainda não respondeu.
  final bool isStarting;

  /// Os modelos que estão na memória do LM Studio agora — de quem quer que os
  /// tenha carregado. É o que acende a bolinha da barra lateral.
  List<LmStudioModel> get loaded =>
      models.where((model) => model.isLoaded).toList(growable: false);

  LocalModelStatus copyWith({
    LmStudioServerState? server,
    List<LmStudioModel>? models,
    bool? isStarting,
  }) {
    return LocalModelStatus(
      server: server ?? this.server,
      models: models ?? this.models,
      isStarting: isStarting ?? this.isStarting,
    );
  }
}

final lmStudioLauncherProvider = Provider<LmStudioLauncher>(
  (ref) => const ProcessLmStudioLauncher(),
);

final localModelViewModelProvider =
    NotifierProvider<LocalModelViewModel, LocalModelStatus>(
      LocalModelViewModel.new,
    );

/// O LM Studio visto do Hub: se está instalado, se o servidor responde, quais
/// modelos ele tem e quais estão na memória.
///
/// **Só pergunta com o LM Studio escolhido**, e enquanto o Hub está aberto: de
/// [pollInterval] em [pollInterval], para a bolinha da barra lateral apagar
/// quando o modelo sai da memória depois de um resumo. Perguntar não carrega
/// nada — `/api/v1/models` só lista.
class LocalModelViewModel extends Notifier<LocalModelStatus> {
  static const pollInterval = Duration(seconds: 5);

  late LmStudioApi _api;
  late LmStudioLauncher _launcher;

  @override
  LocalModelStatus build() {
    _api = LmStudioApi(ref.watch(lmStudioHttpProvider));
    _launcher = ref.watch(lmStudioLauncherProvider);

    // Só a origem: trocar de modelo não pode refazer este estado — a lista
    // piscaria em "Procurando o servidor…" a cada "Usar".
    final source = ref.watch(
      appSettingsViewModelProvider.select(
        (settings) => settings.localModel.source,
      ),
    );
    if (source != LocalModelSource.lmStudio) return const LocalModelStatus();

    final timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    ref.onDispose(timer.cancel);
    // Depois do build: o estado inicial precisa existir antes de a primeira
    // resposta chegar para substituí-lo.
    Future.microtask(refresh);

    return const LocalModelStatus(server: LmStudioServerState.checking);
  }

  Future<void> refresh() async {
    if (!_launcher.isInstalled) {
      _set(state.copyWith(server: LmStudioServerState.notInstalled));
      return;
    }

    try {
      final models = (await _api.models())
          .where((model) => model.isLlm)
          .toList(growable: false);
      _set(
        state.copyWith(
          server: LmStudioServerState.online,
          models: models,
          isStarting: false,
        ),
      );
      _pickFirstIfNoneChosen(models);
    } on LmStudioUnreachable {
      _set(state.copyWith(server: LmStudioServerState.offline, models: []));
    } on Object {
      // Roda num relógio, sem tela embaixo para pegar o erro: qualquer
      // resposta que não se entende vale como servidor fora, e a próxima
      // pergunta tenta de novo.
      _set(state.copyWith(server: LmStudioServerState.offline, models: []));
    }
  }

  /// O "Ligar": roda `lms server start` e pergunta de novo.
  Future<void> startServer() async {
    if (state.isStarting) return;

    _set(state.copyWith(isStarting: true));
    await _launcher.startServer();
    if (!ref.mounted) return;
    await refresh();
    _set(state.copyWith(isStarting: false));
  }

  /// Escolher o LM Studio sem escolher modelo deixaria o resumo sem ninguém
  /// para escrevê-lo, e calado. O primeiro da lista é o palpite de quem só tem
  /// um baixado — que é o caso comum.
  void _pickFirstIfNoneChosen(List<LmStudioModel> models) {
    final choice = ref.read(appSettingsViewModelProvider).localModel;
    if (!choice.isIncomplete || models.isEmpty) return;

    unawaited(choose(models.first));
  }

  Future<void> choose(LmStudioModel model) {
    return ref
        .read(appSettingsViewModelProvider.notifier)
        .setLocalModel(
          LocalModelChoice(
            source: LocalModelSource.lmStudio,
            modelId: model.key,
            modelName: model.displayName,
          ),
        );
  }

  void _set(LocalModelStatus value) {
    if (ref.mounted) state = value;
  }
}

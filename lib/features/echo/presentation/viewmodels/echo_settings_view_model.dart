import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/echo_channel.dart';
import '../../data/echo_settings_repository.dart';
import '../../models/echo_settings.dart';
import '../../models/transcription_language.dart';

final echoSettingsViewModelProvider =
    NotifierProvider<EchoSettingsViewModel, EchoSettings>(
      EchoSettingsViewModel.new,
    );

class EchoSettingsViewModel extends Notifier<EchoSettings> {
  late final EchoSettingsRepository _repository;
  late final EchoChannel _channel;

  @override
  EchoSettings build() {
    _repository = ref.watch(echoSettingsRepositoryProvider);
    _channel = ref.watch(echoChannelProvider);

    return _repository.load();
  }

  void setLiveTranscription(bool value) => _save(state.copyWith(liveTranscription: value));

  /// Troca o idioma e já pede o modelo dele, se faltar.
  ///
  /// Baixar aqui, e não na hora de gravar: descobrir que o modelo do idioma não
  /// está na máquina no instante em que a reunião começa é tarde demais.
  void setLanguage(TranscriptionLanguage language) {
    _save(state.copyWith(language: language));

    unawaited(() async {
      try {
        await _channel.installLanguage(language.locale);
      } on EchoException {
        // Sem rede ou sem suporte: a gravação avisa quando chegar a hora.
      }
    }());
  }

  void setSummaryInstructions(String instructions) =>
      _save(state.copyWith(summaryInstructions: instructions));

  void setHistoryLimit(int limit) => _save(state.copyWith(historyLimit: limit));

  void _save(EchoSettings settings) {
    state = settings;
    unawaited(_repository.save(settings));
  }
}

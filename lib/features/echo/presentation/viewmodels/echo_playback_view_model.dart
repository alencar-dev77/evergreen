import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../data/echo_audio_store.dart';
import '../../data/echo_player.dart';
import '../../models/meeting.dart';
import 'echo_library_view_model.dart';

/// Onde o áudio da reunião aberta está.
@immutable
class EchoPlaybackState {
  const EchoPlaybackState({
    this.meetingId,
    this.durationMs = 0,
    this.positionMs = 0,
    this.isPlaying = false,
    this.isFollowing = true,
  });

  /// A reunião cujo áudio está carregado; `null` quando não há o que tocar.
  final int? meetingId;
  final int durationMs;
  final int positionMs;
  final bool isPlaying;

  /// A transcrição rola sozinha atrás da palavra que toca?
  ///
  /// Começa ligado e desliga quando a pessoa rola a transcrição à mão — quem
  /// rolou foi ler outra coisa, e puxar a tela de volta a cada palavra seria
  /// brigar com ela. Volta a valer no play e no clique numa palavra.
  final bool isFollowing;

  bool get isReady => meetingId != null;

  EchoPlaybackState copyWith({
    int? positionMs,
    bool? isPlaying,
    bool? isFollowing,
  }) {
    return EchoPlaybackState(
      meetingId: meetingId,
      durationMs: durationMs,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

final echoPlaybackViewModelProvider =
    NotifierProvider<EchoPlaybackViewModel, EchoPlaybackState>(
      EchoPlaybackViewModel.new,
    );

/// O player da região de leitura do Echo.
///
/// Segue a seleção da biblioteca sozinho: abrir outra reunião troca o áudio,
/// e fechar a região pausa — ninguém quer uma reunião falando de uma coluna
/// que já não está na tela.
class EchoPlaybackViewModel extends Notifier<EchoPlaybackState> {
  /// O passo dos botões e das setas.
  static const skip = Duration(seconds: 10);

  /// De quanto em quanto tempo se pergunta ao player onde ele está.
  ///
  /// Uma palavra falada dura uns 300 ms; perguntando a cada 80 o destaque
  /// nunca fica mais de um quarto de palavra atrás da voz.
  static const _pollInterval = Duration(milliseconds: 80);

  late final EchoPlayer _player;
  late final EchoAudioStore _store;

  Timer? _poll;

  /// A seleção que pediu o último carregamento — o que impede uma resposta
  /// atrasada do disco de carregar a reunião anterior por cima da atual.
  int _generation = 0;

  @override
  EchoPlaybackState build() {
    _player = ref.watch(echoPlayerProvider);
    _store = ref.watch(echoAudioStoreProvider);

    ref.onDispose(() => _poll?.cancel());

    ref.listen<Meeting?>(
      echoLibraryViewModelProvider.select((library) => library.selected),
      (previous, next) {
        if (previous?.id == next?.id &&
            previous?.audioFile == next?.audioFile) {
          return;
        }
        unawaited(_open(next));
      },
    );

    // A reunião que já estava aberta quando o player nasceu. Numa microtarefa,
    // e não com `fireImmediately`: dentro do `build` o estado ainda não existe,
    // e `_open` precisa lê-lo.
    unawaited(
      Future.microtask(
        () => _open(ref.read(echoLibraryViewModelProvider).selected),
      ),
    );

    ref.listen<EvergreenModule?>(hubDetailProvider, (_, module) {
      if (module != EvergreenModule.echo && state.isPlaying) unawaited(pause());
    });

    return const EchoPlaybackState();
  }

  Future<void> _open(Meeting? meeting) async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    _stopPolling();

    if (state.isReady) await _player.unload();
    if (generation != _generation || !ref.mounted) return;

    state = const EchoPlaybackState();

    final fileName = meeting?.audioFile;
    if (meeting == null || fileName == null || !_store.exists(fileName)) {
      return;
    }

    final durationMs = await _player.load(_store.pathOf(fileName));
    if (generation != _generation || !ref.mounted || durationMs == null) {
      return;
    }

    state = EchoPlaybackState(meetingId: meeting.id, durationMs: durationMs);
  }

  Future<void> toggle() => state.isPlaying ? pause() : play();

  Future<void> play() async {
    if (!state.isReady) return;

    // Do fim, tocar começa de novo — e não "toca zero segundos e para".
    if (state.positionMs >= state.durationMs) await _player.seek(0);

    await _player.play();
    if (!ref.mounted) return;

    state = state.copyWith(isPlaying: true, isFollowing: true);
    _startPolling();
  }

  Future<void> pause() async {
    if (!state.isReady) return;

    // Parado antes de perguntar onde está: com `isPlaying` ainda ligado, a
    // resposta "não está tocando" seria lida como "chegou ao fim".
    _stopPolling();
    state = state.copyWith(isPlaying: false);

    await _player.pause();
    if (!ref.mounted) return;

    await _refresh();
  }

  Future<void> skipBy(Duration offset) =>
      seekTo(state.positionMs + offset.inMilliseconds);

  /// Leva o áudio até [positionMs] — o clique numa palavra, a barra, as setas.
  ///
  /// Saltar volta a seguir a fala: quem clicou num trecho quer ouvir e ver o
  /// mesmo trecho.
  Future<void> seekTo(int positionMs) async {
    if (!state.isReady) return;

    final clamped = positionMs.clamp(0, state.durationMs);
    await _player.seek(clamped);
    if (!ref.mounted) return;

    state = state.copyWith(positionMs: clamped, isFollowing: true);
  }

  void stopFollowing() {
    if (state.isFollowing) state = state.copyWith(isFollowing: false);
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _refresh() async {
    final status = await _player.status();
    if (!ref.mounted || !state.isReady) return;

    // O player chega ao fim sozinho: o relógio para no fim, e não volta ao
    // zero, para a barra mostrar que acabou.
    if (state.isPlaying && !status.isPlaying) {
      _stopPolling();
      state = state.copyWith(
        isPlaying: false,
        positionMs: status.positionMs == 0
            ? state.durationMs
            : status.positionMs,
      );
      return;
    }

    state = state.copyWith(positionMs: status.positionMs);
  }
}

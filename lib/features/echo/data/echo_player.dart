import 'package:flutter/services.dart';

/// Onde o player está, numa pergunta só.
class EchoPlayerStatus {
  const EchoPlayerStatus({required this.positionMs, required this.isPlaying});

  final int positionMs;
  final bool isPlaying;
}

/// Toca o áudio de uma reunião.
///
/// Interface, como o `NestFileService`: no teste de widget a resposta de um
/// canal nativo nunca chega, e a tela que espera por ela travaria. A de
/// verdade é o [ChannelEchoPlayer], sobre o `AVAudioPlayer`
/// (`macos/Runner/EchoPlayerChannel.swift`).
abstract interface class EchoPlayer {
  /// Abre o arquivo e devolve a duração em milissegundos, ou `null` se ele
  /// não abriu.
  Future<int?> load(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(int positionMs);

  /// A velocidade da fala: `1.0` é a normal. O tom não muda — o
  /// `AVAudioPlayer` estica o tempo sem deixar a voz aguda.
  Future<void> setRate(double rate);

  Future<EchoPlayerStatus> status();

  /// Para e solta o arquivo.
  Future<void> unload();
}

class ChannelEchoPlayer implements EchoPlayer {
  ChannelEchoPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('echo_player');

  final MethodChannel _channel;

  @override
  Future<int?> load(String path) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('load', {
        'path': path,
      });
      return (result?['durationMs'] as num?)?.toInt();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> play() => _call('play');

  @override
  Future<void> pause() => _call('pause');

  @override
  Future<void> seek(int positionMs) =>
      _call('seek', {'positionMs': positionMs});

  @override
  Future<void> setRate(double rate) => _call('rate', {'rate': rate});

  @override
  Future<EchoPlayerStatus> status() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('status');
      return EchoPlayerStatus(
        positionMs: (result?['positionMs'] as num?)?.toInt() ?? 0,
        isPlaying: result?['isPlaying'] as bool? ?? false,
      );
    } on PlatformException {
      return const EchoPlayerStatus(positionMs: 0, isPlaying: false);
    } on MissingPluginException {
      return const EchoPlayerStatus(positionMs: 0, isPlaying: false);
    }
  }

  @override
  Future<void> unload() => _call('unload');

  /// O player é enfeite da leitura: um canal que falha não derruba a tela.
  Future<void> _call(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Sem o que fazer: o próximo `status` diz onde ficou.
    } on MissingPluginException {
      // Fora do macOS ou em teste.
    }
  }
}

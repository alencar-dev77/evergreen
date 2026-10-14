import 'package:evergreen/features/echo/data/echo_audio_store.dart';
import 'package:evergreen/features/echo/data/echo_player.dart';

/// A pasta `Reuniões` em memória: um conjunto de nomes.
class FakeEchoAudioStore implements EchoAudioStore {
  FakeEchoAudioStore([Iterable<String> files = const []]) : files = {...files};

  final Set<String> files;

  @override
  String pathOf(String fileName) => '/reunioes/$fileName';

  @override
  bool exists(String fileName) => files.contains(fileName);

  @override
  void delete(String fileName) => files.remove(fileName);

  @override
  List<String> list() => files.toList();
}

/// Um player sem som: o relógio anda quando o teste manda.
class FakeEchoPlayer implements EchoPlayer {
  FakeEchoPlayer({this.durationMs = 60000});

  int durationMs;
  String? loaded;
  int positionMs = 0;
  bool isPlaying = false;
  double rate = 1;
  final calls = <String>[];

  @override
  Future<int?> load(String path) async {
    calls.add('load');
    loaded = path;
    positionMs = 0;
    isPlaying = false;
    return durationMs;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    isPlaying = false;
  }

  @override
  Future<void> seek(int positionMs) async {
    calls.add('seek $positionMs');
    this.positionMs = positionMs;
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('rate $rate');
    this.rate = rate;
  }

  @override
  Future<EchoPlayerStatus> status() async =>
      EchoPlayerStatus(positionMs: positionMs, isPlaying: isPlaying);

  @override
  Future<void> unload() async {
    calls.add('unload');
    loaded = null;
    isPlaying = false;
  }
}

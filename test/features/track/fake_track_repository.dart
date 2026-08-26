import 'package:evergreen/features/track/data/track_repository.dart';
import 'package:evergreen/features/track/models/track_day.dart';

/// Um Track sem banco: a lista de dias é posta na mão.
class FakeTrackRepository implements TrackRepository {
  FakeTrackRepository([this.days = const []]);

  List<TrackDay> days;

  /// A partir de quando a última leitura pediu — é como o teste confere que o
  /// recorte chegou ao repositório.
  DateTime? loadedSince;

  int loads = 0;

  @override
  List<TrackDay> loadDays({required DateTime since}) {
    loadedSince = since;
    loads++;

    return days
        .where((day) => !day.date.isBefore(since))
        .toList(growable: true);
  }
}

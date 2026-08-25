import 'package:evergreen/features/trail/data/trail_repository.dart';
import 'package:evergreen/features/trail/models/trail_day.dart';

/// Um Trail sem banco: a lista de dias é posta na mão.
class FakeTrailRepository implements TrailRepository {
  FakeTrailRepository([this.days = const []]);

  List<TrailDay> days;

  /// A partir de quando a última leitura pediu — é como o teste confere que o
  /// recorte chegou ao repositório.
  DateTime? loadedSince;

  int loads = 0;

  @override
  List<TrailDay> loadDays({required DateTime since}) {
    loadedSince = since;
    loads++;

    return days
        .where((day) => !day.date.isBefore(since))
        .toList(growable: true);
  }
}

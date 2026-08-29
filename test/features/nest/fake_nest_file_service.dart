import 'package:evergreen/features/nest/data/nest_file_service.dart';
import 'package:evergreen/features/nest/models/nest_destination.dart';
import 'package:evergreen/features/nest/models/nest_item.dart';
import 'package:evergreen/features/nest/models/nest_transfer.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';
import 'package:path/path.dart' as p;

/// Um sistema de arquivos de mentira, em memória.
///
/// Existe por uma razão específica do teste de widget: ele roda num relógio
/// falso, e a resposta de uma leitura de disco de verdade **nunca chega** nesse
/// relógio — o painel ficaria esperando para sempre o tamanho do primeiro
/// arquivo. Quem verifica o disco de verdade é o teste do
/// `LocalNestFileService`, que roda fora do binding de widgets.
///
/// Imita só o que a tela precisa: o que existe, o que vai embora ao mover e o
/// nome livre no destino.
class FakeNestFileService implements NestFileService {
  FakeNestFileService({DateTime? now}) : _now = now ?? DateTime(2026, 8, 28);

  final DateTime _now;

  /// Os caminhos que existem, e o tamanho de cada um. Pasta é tamanho nulo.
  final entries = <String, int?>{};

  void addFile(String path, {int size = 2048}) => entries[path] = size;

  void addFolder(String path) => entries[path] = null;

  @override
  Future<NestItem?> inspect(String path) async {
    if (!entries.containsKey(path)) return null;

    final size = entries[path];

    return NestItem(
      path: path,
      isDirectory: size == null,
      sizeInBytes: size ?? 0,
      modifiedAt: _now,
    );
  }

  @override
  Future<bool> exists(String path) async => entries.containsKey(path);

  @override
  Future<NestTransfer> send({
    required List<NestItem> items,
    required NestDestination destination,
    required NestTransferMode mode,
  }) async {
    final movements = <NestMovement>[];
    final failures = <NestFailure>[];

    for (final item in items) {
      if (!entries.containsKey(item.path)) {
        failures.add(
          NestFailure(path: item.path, reason: 'não está mais no lugar'),
        );
        continue;
      }

      final target = _freeName(destination.path, p.basename(item.path));
      entries[target] = entries[item.path];
      if (mode == NestTransferMode.move) entries.remove(item.path);

      movements.add(NestMovement(source: item.path, destination: target));
    }

    return NestTransfer(
      at: _now,
      mode: mode,
      destinationPath: destination.path,
      movements: movements,
      failures: failures,
    );
  }

  @override
  Future<int> undo(NestTransfer transfer) async {
    for (final movement in transfer.movements.reversed) {
      final size = entries.remove(movement.destination);
      if (transfer.mode == NestTransferMode.move) {
        entries[movement.source] = size;
      }
    }

    return transfer.movements.length;
  }

  String _freeName(String folder, String name) {
    var candidate = p.join(folder, name);
    if (!entries.containsKey(candidate)) return candidate;

    final extension = p.extension(name);
    final stem = name.substring(0, name.length - extension.length);

    for (var index = 2; ; index++) {
      candidate = p.join(folder, '$stem $index$extension');
      if (!entries.containsKey(candidate)) return candidate;
    }
  }
}

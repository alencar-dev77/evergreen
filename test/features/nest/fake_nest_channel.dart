import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:evergreen/features/nest/data/nest_channel.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';

/// O canal do Nest sem lado nativo: sem Finder e sem QuickLook.
///
/// Os fluxos são controláveis para que um teste possa soltar arquivos no painel
/// — o gesto central do módulo — sem uma sessão de arraste do sistema.
class FakeNestChannel implements NestChannel {
  final _dropped = StreamController<List<String>>.broadcast();
  final _dragOver = StreamController<bool>.broadcast();
  final _thumbnails = StreamController<NestThumbnail>.broadcast();
  final _dragOutEnded = StreamController<NestTransferMode?>.broadcast();
  final _shakes = StreamController<void>.broadcast();
  final _notch = StreamController<void>.broadcast();
  final _notchDragEnded = StreamController<void>.broadcast();
  final _pointerInside = StreamController<bool>.broadcast();

  /// A pasta que o seletor devolve; `null` é "cancelou".
  String? folderToChoose;

  bool isDropEnabled = false;

  /// Onde o painel disse que está desenhado. `null` quando ele saiu de cena.
  Rect? interactiveRect;
  bool isShakeEnabled = true;
  bool isNotchEnabled = false;

  final revealed = <String>[];
  final trashed = <String>[];
  final thumbnailsRequested = <String>[];

  /// O que foi pedido ao último arraste para fora, e com qual operação.
  List<String>? draggedOut;
  bool? draggedOutAsMove;

  /// Se o lado nativo consegue começar a sessão de arraste.
  bool canDragOut = true;

  /// Solta arquivos no painel, como o lado nativo faria.
  void drop(List<String> paths) => _dropped.add(paths);

  void sendThumbnail(String path, Uint8List bytes) =>
      _thumbnails.add(NestThumbnail(path: path, bytes: bytes));

  /// Chacoalha um arquivo, como o lado nativo faria.
  void shake() => _shakes.add(null);

  /// Para com um arquivo no notch, como o lado nativo faria.
  void reachNotch() => _notch.add(null);

  /// Solta o arraste que veio do notch.
  void endNotchDrag() => _notchDragEnded.add(null);

  /// O cursor entra ou sai do painel, como o lado nativo avisaria.
  void movePointer({required bool inside}) => _pointerInside.add(inside);

  /// Termina o arraste para fora, como o destino faria.
  void endDragOut(NestTransferMode? operation) => _dragOutEnded.add(operation);

  @override
  Stream<List<String>> get onDropped => _dropped.stream;

  @override
  Stream<bool> get onDragOver => _dragOver.stream;

  @override
  Stream<NestThumbnail> get onThumbnail => _thumbnails.stream;

  @override
  Stream<NestTransferMode?> get onDragOutEnded => _dragOutEnded.stream;

  @override
  Stream<void> get onShake => _shakes.stream;

  @override
  Stream<void> get onNotch => _notch.stream;

  @override
  Stream<void> get onNotchDragEnded => _notchDragEnded.stream;

  @override
  Stream<bool> get onPointerInside => _pointerInside.stream;

  @override
  void listen() {}

  @override
  Future<void> setShakeEnabled({required bool enabled}) async {
    isShakeEnabled = enabled;
  }

  @override
  Future<void> setNotchEnabled({required bool enabled}) async {
    isNotchEnabled = enabled;
  }

  @override
  Future<void> setDropEnabled({required bool enabled}) async {
    isDropEnabled = enabled;
  }

  @override
  Future<bool> beginDragOut(List<String> paths, {required bool move}) async {
    if (!canDragOut) return false;

    draggedOut = paths;
    draggedOutAsMove = move;
    return true;
  }

  @override
  Future<void> setInteractiveRect(Rect? rect) async {
    interactiveRect = rect;
  }

  @override
  Future<void> requestThumbnail(String path, {double size = 96}) async {
    thumbnailsRequested.add(path);
  }

  @override
  Future<String?> chooseFolder() async => folderToChoose;

  @override
  Future<void> revealInFinder(String path) async => revealed.add(path);

  @override
  Future<bool> moveToTrash(String path) async {
    trashed.add(path);
    return true;
  }

  @override
  void dispose() {
    _dropped.close();
    _dragOver.close();
    _thumbnails.close();
    _dragOutEnded.close();
    _shakes.close();
    _notch.close();
    _notchDragEnded.close();
    _pointerInside.close();
  }
}

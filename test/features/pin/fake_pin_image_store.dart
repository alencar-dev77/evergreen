import 'dart:typed_data';

import 'package:evergreen/features/pin/data/pin_image_store.dart';
import 'package:evergreen/features/pin/models/pin_image.dart';
import 'package:flutter/widgets.dart';

/// A pasta de imagens do Pin, em memória.
///
/// O desenho sai de um `MemoryImage`, e não de um arquivo: no relógio falso
/// do teste de widget, a leitura de disco que um `FileImage` faz nunca
/// termina.
class FakePinImageStore implements PinImageStore {
  final files = <String, Uint8List>{};

  @override
  PinImage save(CapturedImage image) {
    files.putIfAbsent(image.fileName, () => image.bytes);
    return image.toImage();
  }

  @override
  String pathOf(String fileName) => '/tmp/pin-imagens/$fileName';

  @override
  bool exists(String fileName) => files.containsKey(fileName);

  @override
  ImageProvider providerOf(
    String fileName, {
    int? cacheWidth,
    int? fitWithin,
  }) => sizedProvider(
    MemoryImage(files[fileName] ?? Uint8List(0)),
    cacheWidth: cacheWidth,
    fitWithin: fitWithin,
  );

  @override
  void delete(String fileName) => files.remove(fileName);

  @override
  List<String> list() => files.keys.toList();
}

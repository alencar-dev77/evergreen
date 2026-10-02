import 'dart:io';

import 'package:evergreen/core/storage/export_service.dart';

/// Um [ExportService] que não toca no disco e não abre o Finder.
///
/// Pelo motivo de sempre: teste de widget roda no relógio falso do binding, e
/// nele a resposta de uma escrita em arquivo **nunca chega** — a tela que
/// espera por ela fica travada, sem erro e sem mensagem. Aqui a escrita
/// responde no mesmo microtask, e o que ela guardou fica em [written] para o
/// teste conferir o que teria ido para o arquivo.
class FakeExportService implements ExportService {
  /// O que cada chamada escreveria: nome base e conteúdo.
  final written = <({String baseName, String content})>[];

  /// Os caminhos que o serviço mostraria no Finder.
  final revealed = <String>[];

  /// Quando presente, [write] falha com este erro — é como o teste chega ao
  /// caminho do disco cheio ou da pasta sem permissão.
  Object? failure;

  @override
  String get directoryLabel => '~/Library/Evergreen/Exportações';

  @override
  Future<File> write({
    required String baseName,
    required String content,
    String extension = 'md',
    bool reveal = true,
  }) async {
    final error = failure;
    if (error != null) throw error;

    written.add((baseName: baseName, content: content));

    final path = '$directoryLabel/$baseName.$extension';
    if (reveal) revealed.add(path);

    return File(path);
  }

  @override
  Future<void> reveal(String path) async => revealed.add(path);
}

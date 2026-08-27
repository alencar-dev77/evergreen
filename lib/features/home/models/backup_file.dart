import 'dart:io';

import 'package:flutter/foundation.dart';

/// Um backup que está na pasta.
@immutable
class BackupFile {
  const BackupFile({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    required this.isOurs,
    this.isSafetyCopy = false,
  });

  final String path;

  /// Quando o arquivo foi escrito.
  ///
  /// Da data de modificação do arquivo, e não do nome dele: um backup trazido
  /// de outra máquina pode se chamar qualquer coisa, e a lista precisa saber
  /// ordená-lo junto com os nossos.
  final DateTime createdAt;

  final int sizeBytes;

  /// Foi o Evergreen que escreveu este arquivo (o nome segue o padrão dele).
  ///
  /// Só estes entram na conta da limpeza automática. Um arquivo que a pessoa
  /// arrastou para a pasta fica onde está: ela o pôs ali de propósito, e
  /// apagá-lo por causa de um teto que ela não escolheu seria perder o backup
  /// que mais importava.
  final bool isOurs;

  /// Este arquivo é a rede que uma restauração deixou para trás — o banco como
  /// ele estava um instante antes de ser trocado.
  ///
  /// A lista precisa dizer isso na linha: os arquivos do Evergreen aparecem só
  /// pela data, e sem a etiqueta a cópia de emergência seria indistinguível de
  /// mais um backup semanal — justamente no minuto em que se procura por ela.
  final bool isSafetyCopy;

  factory BackupFile.of(
    File file, {
    required bool isOurs,
    bool isSafetyCopy = false,
  }) {
    final stat = file.statSync();

    return BackupFile(
      path: file.path,
      createdAt: stat.modified,
      sizeBytes: stat.size,
      isOurs: isOurs,
      isSafetyCopy: isSafetyCopy,
    );
  }

  String get name => path.split(Platform.pathSeparator).last;
}

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Um arquivo ou pasta esperando na prateleira.
///
/// **É uma referência, nunca uma cópia.** O arquivo continua exatamente onde
/// estava até uma transferência acontecer — é o que faz encher a prateleira ser
/// grátis e o que permite arrastar dez coisas de cinco pastas sem produzir nada
/// no disco. O preço é [isMissing]: o original pode ser movido, renomeado ou
/// desmontado junto com o volume enquanto espera aqui, e nesse caso o cartão
/// fica apagado e diz o que houve em vez de sumir sozinho da parede.
@immutable
class NestItem {
  const NestItem({
    required this.path,
    required this.isDirectory,
    required this.sizeInBytes,
    required this.modifiedAt,
    this.thumbnail,
    this.isMissing = false,
  });

  /// Caminho absoluto do original.
  final String path;

  final bool isDirectory;

  /// Tamanho do arquivo. Zero para pasta: medir uma pasta é percorrê-la
  /// inteira, e o cartão mostra "Pasta" no lugar do número.
  final int sizeInBytes;

  final DateTime modifiedAt;

  /// A miniatura já pronta, em PNG.
  ///
  /// Nula até o QuickLook responder — e o cartão desenha o ícone genérico nesse
  /// intervalo, em vez de um espaço vazio esperando. Ver `NestChannel`.
  final Uint8List? thumbnail;

  /// O original não está mais no lugar.
  final bool isMissing;

  String get name => p.basename(path);

  /// Chave do cache de miniatura.
  ///
  /// Caminho **mais** tamanho e data de modificação: o mesmo caminho pode
  /// guardar outro conteúdo depois de uma edição, e uma chave só de caminho
  /// devolveria a capa do PDF antigo.
  String get thumbnailKey =>
      '$path|$sizeInBytes|${modifiedAt.millisecondsSinceEpoch}';

  NestItem copyWith({Uint8List? thumbnail, bool? isMissing}) => NestItem(
    path: path,
    isDirectory: isDirectory,
    sizeInBytes: sizeInBytes,
    modifiedAt: modifiedAt,
    thumbnail: thumbnail ?? this.thumbnail,
    isMissing: isMissing ?? this.isMissing,
  );

  @override
  bool operator ==(Object other) =>
      other is NestItem &&
      other.path == path &&
      other.isDirectory == isDirectory &&
      other.sizeInBytes == sizeInBytes &&
      other.modifiedAt == modifiedAt &&
      other.isMissing == isMissing &&
      identical(other.thumbnail, thumbnail);

  @override
  int get hashCode =>
      Object.hash(path, isDirectory, sizeInBytes, modifiedAt, isMissing);
}

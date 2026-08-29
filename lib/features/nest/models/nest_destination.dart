import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Uma pasta favorita — para onde a prateleira sabe mandar.
///
/// É a saída do Nest, e é uma decisão de produto, não uma limitação: arrastar
/// para fora do painel depende de o aplicativo de destino honrar a operação de
/// mover, e o Finder só a honra dentro do mesmo volume. Uma lista de destinos
/// dentro do painel move para onde quer que seja, é operável por teclado
/// (`⌘1..⌘9`) e diz de antemão o que vai acontecer.
@immutable
class NestDestination {
  const NestDestination({required this.path, this.alias = ''});

  /// Caminho absoluto da pasta.
  final String path;

  /// Nome dado por quem cadastrou ("Recibos", "Entrada"). Vazio é o normal — a
  /// pasta se apresenta pelo próprio nome.
  final String alias;

  /// Como o destino aparece na lista.
  String get label => alias.trim().isEmpty ? p.basename(path) : alias.trim();

  NestDestination copyWith({String? path, String? alias}) =>
      NestDestination(path: path ?? this.path, alias: alias ?? this.alias);

  Map<String, Object?> toJson() => {'path': path, 'alias': alias};

  static NestDestination? fromJson(Map<String, Object?> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) return null;

    return NestDestination(
      path: path,
      alias: json['alias'] is String ? json['alias']! as String : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NestDestination && other.path == path && other.alias == alias;

  @override
  int get hashCode => Object.hash(path, alias);
}

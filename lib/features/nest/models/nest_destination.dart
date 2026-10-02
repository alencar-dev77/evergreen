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
  const NestDestination({
    required this.path,
    this.alias = '',
    this.isMissing = false,
  });

  /// Caminho absoluto da pasta.
  final String path;

  /// Nome dado por quem cadastrou ("Recibos", "Entrada"). Vazio é o normal — a
  /// pasta se apresenta pelo próprio nome.
  final String alias;

  /// A pasta não está mais onde este caminho diz.
  ///
  /// O favorito é um caminho de texto, e o Finder não avisa ninguém ao renomear
  /// ou mover uma pasta — o destino simplesmente deixa de existir, e `⌘3`
  /// passava a falhar toda vez sem que a lista de preferências mostrasse nada
  /// de errado. Quem confere é [NestDestinations.resolve], na abertura do
  /// painel e da tela.
  ///
  /// **Não é gravado.** É o que o disco respondeu agora, não um atributo do
  /// favorito: guardá-lo faria uma pasta em volume desmontado voltar marcada
  /// como perdida depois de remontada. Ver [toJson].
  final bool isMissing;

  /// Como o destino aparece na lista.
  String get label => alias.trim().isEmpty ? p.basename(path) : alias.trim();

  NestDestination copyWith({String? path, String? alias, bool? isMissing}) =>
      NestDestination(
        path: path ?? this.path,
        alias: alias ?? this.alias,
        isMissing: isMissing ?? this.isMissing,
      );

  /// Só o que é do favorito: [isMissing] é do disco, e não entra.
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
      other is NestDestination &&
      other.path == path &&
      other.alias == alias &&
      other.isMissing == isMissing;

  @override
  int get hashCode => Object.hash(path, alias, isMissing);
}

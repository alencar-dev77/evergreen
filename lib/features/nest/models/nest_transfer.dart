import 'package:flutter/foundation.dart';

import 'nest_transfer_mode.dart';

/// Um arquivo que saiu da prateleira: de onde veio e o que foi criado lá.
///
/// Os dois caminhos, e não só o destino, porque é o par que permite desfazer —
/// e o destino não se deriva da origem: um nome que já existia na pasta chega
/// lá como `contrato 2.pdf`.
@immutable
class NestMovement {
  const NestMovement({required this.source, required this.destination});

  /// Onde o arquivo estava.
  final String source;

  /// O que foi criado na pasta de destino.
  final String destination;
}

/// Um arquivo que não conseguiu sair, e por quê.
@immutable
class NestFailure {
  const NestFailure({required this.path, required this.reason});

  final String path;

  /// Frase curta para a barra de dicas — "não está mais no lugar", "sem
  /// permissão de escrita".
  final String reason;
}

/// O resultado de mandar a prateleira (ou parte dela) para um destino.
///
/// Guardado inteiro pelo ViewModel até o painel fechar, porque é o que o `⌘Z`
/// desfaz. Mover arquivo sem perguntar é ação destrutiva, e a convenção da casa
/// — a mesma do cartão arrancado do Leaf — é que ação destrutiva sem pergunta
/// precisa de desfazer, nunca de um diálogo de confirmação.
@immutable
class NestTransfer {
  const NestTransfer({
    required this.at,
    required this.mode,
    required this.destinationPath,
    this.movements = const [],
    this.failures = const [],
  });

  final DateTime at;
  final NestTransferMode mode;
  final String destinationPath;

  /// O que efetivamente chegou ao destino.
  final List<NestMovement> movements;

  /// O que ficou pelo caminho. Uma transferência pode ter as duas listas
  /// cheias: nove arquivos chegam, um sumiu enquanto esperava.
  final List<NestFailure> failures;

  int get fileCount => movements.length;

  bool get isEmpty => movements.isEmpty;

  bool get hasFailures => failures.isNotEmpty;
}

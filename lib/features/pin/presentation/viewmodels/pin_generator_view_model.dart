import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tax_id.dart';

/// O documento que a bancada do Hub está mostrando agora.
@immutable
class PinGeneratorState {
  const PinGeneratorState({required this.kind, required this.value});

  final TaxIdKind kind;

  /// Já formatado, como a Receita escreve.
  final String value;
}

/// A bancada de CPF e CNPJ da tela do Pin.
///
/// **A mesma conta do painel, outro uso.** No painel, o gerador é um atalho:
/// aparece como primeira linha quando se digita `cpf` e o clique já copia. Aqui
/// ele é bancada — gerar vários, conferir, escolher qual levar. São usos
/// diferentes, e é a única duplicidade que este redesenho aceita.
///
/// A conta não mora aqui: ela é do [TaxId], que é domínio. Este notifier só
/// guarda qual documento está na tela.
class PinGeneratorViewModel extends Notifier<PinGeneratorState> {
  @override
  PinGeneratorState build() => _next(TaxIdKind.cpf);

  /// Troca de documento — e já gera um do tipo novo, porque uma bancada vazia
  /// depois de um clique parece que o clique não funcionou.
  void setKind(TaxIdKind kind) => state = _next(kind);

  /// Outro número, do mesmo tipo.
  void regenerate() => state = _next(state.kind);

  static PinGeneratorState _next(TaxIdKind kind) =>
      PinGeneratorState(kind: kind, value: TaxId.generate(kind));
}

final pinGeneratorViewModelProvider =
    NotifierProvider<PinGeneratorViewModel, PinGeneratorState>(
      PinGeneratorViewModel.new,
    );

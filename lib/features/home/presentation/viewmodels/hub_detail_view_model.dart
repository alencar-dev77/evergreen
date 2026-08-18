import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/evergreen_module.dart';

/// Qual módulo tem uma região de leitura aberta ao lado do conteúdo do Hub.
///
/// Vive fora dos módulos porque quem abre a região é o módulo, mas quem a
/// desenha — e quem manda a janela crescer — é o Hub. O estado guarda só *de
/// quem* é a região: o conteúdo dela sai do estado do próprio módulo, que já
/// sabe qual item está selecionado.
final hubDetailProvider = NotifierProvider<HubDetailViewModel, EvergreenModule?>(
  HubDetailViewModel.new,
);

class HubDetailViewModel extends Notifier<EvergreenModule?> {
  @override
  EvergreenModule? build() => null;

  void open(EvergreenModule module) => state = module;

  void close() => state = null;
}

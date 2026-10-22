import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/evergreen_module.dart';

/// Qual módulo tem uma região de leitura aberta ao lado do conteúdo do Hub.
///
/// Vive fora dos módulos porque quem abre a região é o módulo, mas quem a
/// desenha — e quem manda a janela crescer — é o Hub. O estado guarda só *de
/// quem* é a região: o conteúdo dela sai do estado do próprio módulo, que já
/// sabe qual item está selecionado.
final hubDetailProvider =
    NotifierProvider<HubDetailViewModel, EvergreenModule?>(
      HubDetailViewModel.new,
    );

class HubDetailViewModel extends Notifier<EvergreenModule?> {
  @override
  EvergreenModule? build() => null;

  void open(EvergreenModule module) => state = module;

  void close() => state = null;
}

/// O que a tela do aplicativo tem aberto na região de leitura.
///
/// À parte do [hubDetailProvider] porque a tela do aplicativo não é um
/// módulo — é o `null` da barra lateral —, e a região de um módulo é
/// identificada pelo módulo. Hoje é uma coisa só; o enum é para a próxima
/// entrar aqui, e não num segundo `bool` ao lado.
enum AppDetail { licenses }

final appDetailProvider = NotifierProvider<AppDetailViewModel, AppDetail?>(
  AppDetailViewModel.new,
);

class AppDetailViewModel extends Notifier<AppDetail?> {
  @override
  AppDetail? build() => null;

  void open(AppDetail detail) => state = detail;

  void close() => state = null;
}

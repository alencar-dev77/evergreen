import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pedidos de levar o teclado à busca do Echo — o `⌘F` do Hub.
///
/// Um contador, e não um `FocusNode` exposto: o nó é do campo, que nasce e
/// morre com a aba das reuniões, e o Hub não tem como segurá-lo. O campo
/// escuta o número e pede o foco quando ele sobe — inclusive quando nasce
/// por causa do próprio pedido, porque o `⌘F` dado na aba de ajustes troca
/// de aba antes de o campo existir.
final echoSearchFocusProvider = NotifierProvider<EchoSearchFocus, int>(
  EchoSearchFocus.new,
);

class EchoSearchFocus extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

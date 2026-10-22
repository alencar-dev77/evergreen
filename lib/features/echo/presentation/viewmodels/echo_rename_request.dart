import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pedidos de renomear a reunião aberta — o `⌘R` do Hub, o mesmo do apelido do
/// Pin.
///
/// Um contador, pelo mesmo motivo do `echoSearchFocusProvider`: o campo é do
/// cabeçalho da leitura, nasce e morre com ela, e o Hub não tem como segurar o
/// nó dele. O título escuta o número e vira campo quando ele sobe.
final echoRenameRequestProvider = NotifierProvider<EchoRenameRequest, int>(
  EchoRenameRequest.new,
);

class EchoRenameRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

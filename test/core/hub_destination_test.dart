import 'package:evergreen/core/window/hub_destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O destino de uma abertura do Hub.
///
/// Ele atravessa dois engines pelo disco, e é **gasto ao ser lido**: é o pedido
/// de uma abertura, não uma preferência de onde o Hub abre. Sem isso, quem
/// fechasse uma reunião cairia no Echo pelo resto da instalação.
void main() {
  // O aviso pelo canal precisa do binding para ser **tentado** — e, sem lado
  // nativo, ele falha e é engolido, que é exatamente o caminho de quando o Hub
  // ainda não subiu.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sem pedido, não há destino', () async {
    expect(await HubDestination.take(), isNull);
  });

  test('o destino pedido é lido uma vez, e some', () async {
    await HubDestination.request('echo');

    expect(await HubDestination.take(), 'echo');
    expect(await HubDestination.take(), isNull);
  });

  test('o último pedido vence', () async {
    await HubDestination.request('echo');
    await HubDestination.request('focus');

    expect(await HubDestination.take(), 'focus');
  });
}

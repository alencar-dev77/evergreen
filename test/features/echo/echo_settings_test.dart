import 'package:evergreen/features/echo/models/echo_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vocabulário', () {
    test('uma palavra por linha vira um termo por linha', () {
      const settings = EchoSettings(vocabulary: 'Evergreen\nRiverpod\nDiletta');

      expect(settings.vocabularyTerms, ['Evergreen', 'Riverpod', 'Diletta']);
    });

    test('separado por vírgula vale igual', () {
      // Ninguém lê a instrução do campo antes de digitar: as duas maneiras são
      // o que a pessoa faz sem pensar, e nenhuma é mais certa que a outra.
      const settings = EchoSettings(vocabulary: 'Evergreen, Riverpod; Diletta');

      expect(settings.vocabularyTerms, ['Evergreen', 'Riverpod', 'Diletta']);
    });

    test('linha em branco e espaço solto não viram termo', () {
      // Um termo vazio na lista de contexto é ruído entregue ao reconhecimento.
      const settings = EchoSettings(vocabulary: '  Evergreen  \n\n , \n');

      expect(settings.vocabularyTerms, ['Evergreen']);
    });

    test('campo vazio não manda termo nenhum', () {
      expect(const EchoSettings().vocabularyTerms, isEmpty);
    });
  });
}

import 'package:evergreen/features/home/data/license_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fora do `testWidgets`: o catálogo de verdade lê arquivos do pacote do app,
  // e no relógio falso a leitura nunca termina.
  test(
    'o Evergreen vem primeiro, e os pacotes Swift entram na lista',
    () async {
      final licenses = await const FlutterLicenseCatalog().load();
      final names = licenses.map((license) => license.name).toList();

      expect(names.first, FlutterLicenseCatalog.evergreen);
      expect(
        licenses.first.texts.single,
        contains('GNU GENERAL PUBLIC LICENSE'),
      );
      expect(names, containsAll(['FluidAudio', 'HotKey']));
      // O registro também traz o pacote raiz; ele não pode aparecer de novo no
      // meio da lista.
      expect(
        names.where((name) => name.toLowerCase() == 'evergreen'),
        hasLength(1),
      );
      expect(
        licenses
            .firstWhere((license) => license.name == 'FluidAudio')
            .texts
            .single,
        contains('Apache License'),
      );

      // Depois do Evergreen, em ordem alfabética, sem diferenciar maiúscula.
      final rest = names.skip(1).map((name) => name.toLowerCase()).toList();
      expect(rest, [...rest]..sort());
    },
  );
}

import 'package:evergreen/features/home/data/license_catalog.dart';
import 'package:evergreen/features/home/models/package_license.dart';

/// Um catálogo em memória: o de verdade lê arquivos do pacote do app, e no
/// relógio falso do teste de widget essa leitura nunca termina.
class FakeLicenseCatalog implements LicenseCatalog {
  const FakeLicenseCatalog();

  @override
  Future<List<PackageLicense>> load() async => const [
    PackageLicense(name: 'Evergreen', texts: ['GNU GENERAL PUBLIC LICENSE']),
    PackageLicense(name: 'flutter_riverpod', texts: ['MIT License']),
    PackageLicense(name: 'FluidAudio', texts: ['Apache License']),
  ];
}

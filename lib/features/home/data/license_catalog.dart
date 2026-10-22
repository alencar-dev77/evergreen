import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/package_license.dart';

/// As licenças de tudo o que vai dentro do Evergreen.
///
/// Interface pelo motivo do `NestFileService`: a lista sai de um arquivo do
/// pacote do app, e no relógio falso do teste de widget essa leitura nunca
/// termina.
abstract interface class LicenseCatalog {
  /// O Evergreen primeiro; depois os componentes, em ordem alfabética.
  Future<List<PackageLicense>> load();
}

/// O catálogo de verdade: o registro do Flutter mais o que ele não vê.
///
/// O `LicenseRegistry` junta sozinho as licenças de todo pacote Dart, inclusive
/// o `hotkey_manager_macos` vendorizado. O que fica de fora é o que entra pelo
/// Swift Package Manager direto no `Runner` (o FluidAudio) ou por dentro de um
/// plugin (o HotKey): esses dois moram em `assets/licenses/`, copiados do
/// pacote na versão que o `Package.resolved` trava. Pacote Swift novo entra
/// lá do mesmo jeito.
class FlutterLicenseCatalog implements LicenseCatalog {
  const FlutterLicenseCatalog();

  static const evergreen = 'Evergreen';

  static const _native = {
    'FluidAudio': 'assets/licenses/FluidAudio.txt',
    'HotKey': 'assets/licenses/HotKey.txt',
  };

  @override
  Future<List<PackageLicense>> load() async {
    final texts = <String, List<String>>{};

    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n\n')
          .trim();
      if (text.isEmpty) continue;

      for (final package in entry.packages) {
        final known = texts.putIfAbsent(package, () => []);
        // O mesmo texto chega mais de uma vez quando um pacote o repete em
        // mais de um arquivo — uma vez basta.
        if (!known.contains(text)) known.add(text);
      }
    }

    for (final MapEntry(key: package, value: asset) in _native.entries) {
      texts[package] = [(await rootBundle.loadString(asset)).trim()];
    }

    final packages =
        texts.entries
            .map((entry) => PackageLicense(name: entry.key, texts: entry.value))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return [
      PackageLicense(
        name: evergreen,
        texts: [(await rootBundle.loadString('LICENSE')).trim()],
      ),
      ...packages,
    ];
  }
}

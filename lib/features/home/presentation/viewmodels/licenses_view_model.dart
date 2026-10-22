import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/license_catalog.dart';
import '../../models/package_license.dart';

/// As licenças, lidas uma vez por abertura da tela.
///
/// `autoDispose`: a lista tem o texto inteiro de uma centena de licenças, e
/// ninguém precisa dela guardada depois de fechar a leitura.
final licensesProvider = FutureProvider.autoDispose<List<PackageLicense>>(
  (ref) => ref.watch(licenseCatalogProvider).load(),
);

/// Quantos componentes de outras pessoas a lista tem — todos menos o próprio
/// Evergreen.
int thirdPartyCount(List<PackageLicense> licenses) => licenses
    .where((license) => license.name != FlutterLicenseCatalog.evergreen)
    .length;

/// Qual componente está com o texto aberto — um por vez.
///
/// Um por vez porque a lista é para achar, e o texto é para ler: com dois
/// abertos, o segundo começa lá embaixo, depois de páginas da GPL.
final openLicenseProvider =
    NotifierProvider.autoDispose<OpenLicenseViewModel, String?>(
      OpenLicenseViewModel.new,
    );

class OpenLicenseViewModel extends Notifier<String?> {
  @override
  String? build() => null;

  /// Abre [name], ou fecha se ele já estava aberto.
  void toggle(String name) => state = state == name ? null : name;
}

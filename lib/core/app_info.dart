import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Identidade da versão do Evergreen.
///
/// Existe para que a versão apareça em um lugar só: ela é exibida na barra
/// lateral do Hub e no rodapé "Sobre", e as duas divergirem seria o tipo de
/// detalhe que denuncia falta de cuidado.
///
/// O número vem do bundle (`CFBundleShortVersionString`), que o Xcode preenche
/// a partir do `version:` do `pubspec.yaml` — antes ele era uma constante
/// escrita à mão aqui, e já tinha divergido do pubspec sem ninguém notar. O
/// pubspec é a fonte porque é dele que sai também o aplicativo instalado.
abstract final class AppInfo {
  static String _version = '';

  /// Lê a versão do bundle. Chamada em `main`, antes do `runApp`.
  ///
  /// Cada janela roda um engine próprio e executa o mesmo `main`, então cada
  /// uma faz a sua leitura — é um plist já carregado pelo sistema, não vale um
  /// canal para compartilhar o valor entre engines.
  static Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version;
  }

  static String get version => _version;

  /// Assinatura da build instalada — a data de modificação do executável.
  ///
  /// Serve para responder "este binário é o mesmo da última vez?", que é o que
  /// decide se a abertura animada do Hub roda. **Não** é a versão do
  /// `pubspec`: o `run_build_copy` reinstala sem bumpar, e por versão a
  /// animação sumiria justamente no ciclo de desenvolvimento, que é quando ela
  /// mais precisa ser vista.
  ///
  /// O preço é um falso positivo raro — copiar o `.app`, restaurar um backup,
  /// reassinar à mão também mexem na data. Custa 300ms, uma vez.
  ///
  /// Devolve string vazia se o executável não puder ser lido; quem chama trata
  /// isso como "não sei", e o vazio nunca casa com um carimbo já guardado.
  static String readBuildStamp() {
    try {
      final stat = File(Platform.resolvedExecutable).statSync();
      return stat.modified.microsecondsSinceEpoch.toString();
    } on FileSystemException {
      return '';
    }
  }

  /// Como a versão é escrita na interface.
  ///
  /// Vazio antes de [load]: em vez de um "v" solto, a interface fica sem
  /// versão nenhuma.
  static String get versionLabel => _version.isEmpty ? '' : 'v$_version';
}

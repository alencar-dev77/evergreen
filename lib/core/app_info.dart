/// Identidade da versão do Evergreen.
///
/// Existe para que a versão apareça em um lugar só: ela é exibida na barra
/// lateral do Hub e no rodapé "Sobre", e as duas divergirem seria o tipo de
/// detalhe que denuncia falta de cuidado.
abstract final class AppInfo {
  static const version = '0.2.0';

  /// Como a versão é escrita na interface.
  static const versionLabel = 'v$version';
}

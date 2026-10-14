/// Texto dobrado para comparar: minúsculo e sem acento.
///
/// **Mesmo comprimento que o original, caractere por caractere.** É a
/// propriedade que importa: quem busca no texto dobrado acha uma posição, e
/// essa posição precisa servir para grifar o texto de verdade, com acento e
/// maiúscula. Por isso a troca é sempre de um caractere por um — e quando
/// minusculizar mudaria o comprimento (o `İ` turco vira dois), o caractere
/// fica como estava.
abstract final class TextFold {
  static const _accented = 'áàâãäåéèêëíìîïóòôõöúùûüçñý';
  static const _plain = 'aaaaaaeeeeiiiiooooouuuucny';

  static String fold(String text) {
    final buffer = StringBuffer();

    for (var index = 0; index < text.length; index++) {
      buffer.write(foldChar(text[index]));
    }

    return buffer.toString();
  }

  /// Um caractere dobrado — sempre um caractere.
  static String foldChar(String char) {
    final lower = char.toLowerCase();
    if (lower.length != 1) return char;

    final at = _accented.indexOf(lower);
    return at < 0 ? lower : _plain[at];
  }
}

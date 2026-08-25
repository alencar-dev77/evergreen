/// Tamanho de arquivo em texto curto e em português.
///
/// Base 1024 com os nomes de sempre (KB, MB), que é o que o Finder mostrava
/// até o Snow Leopard e o que ainda se lê em qualquer lugar — a precisão de
/// base 1000 não muda nenhuma decisão de quem olha "o backup tem 2,4 MB".
abstract final class ByteSize {
  static const _units = <String>['B', 'KB', 'MB', 'GB'];

  /// `840 KB`, `2,4 MB`. Vírgula decimal, como o resto da interface.
  ///
  /// Uma casa decimal só a partir de MB: `2,4 MB` diz alguma coisa, `840,3 KB`
  /// só ocupa espaço.
  static String compact(int bytes) {
    if (bytes < 1024) return '$bytes B';

    var value = bytes.toDouble();
    var unit = 0;

    while (value >= 1024 && unit < _units.length - 1) {
      value /= 1024;
      unit++;
    }

    if (unit < 2) return '${value.round()} ${_units[unit]}';

    return '${value.toStringAsFixed(1).replaceAll('.', ',')} ${_units[unit]}';
  }
}

import 'dart:convert';
import 'dart:typed_data';

/// O que o Pin sabe de uma imagem copiada — o arquivo dela e de onde veio.
///
/// A imagem em si não mora no banco: é um arquivo na pasta `Pin/Imagens` do
/// aplicativo (`PinImageStore`), como o áudio do Echo. Aqui fica o nome dele e
/// o que a lista e o preview mostram. Por isso ela fica fora do backup — o
/// backup é uma cópia do banco, e um histórico de capturas de tela dentro
/// dele engordaria cada `VACUUM INTO` com o que ninguém vai restaurar.
class PinImage {
  const PinImage({
    required this.fileName,
    required this.width,
    required this.height,
    required this.byteSize,
    this.name,
    this.path,
    this.source,
  });

  /// O arquivo na pasta de imagens: o hash do conteúdo e a extensão.
  ///
  /// O hash é a identidade: copiar a mesma imagem de novo cai no mesmo nome,
  /// e o item sobe para o topo em vez de virar uma segunda linha — o mesmo
  /// que acontece com um texto copiado duas vezes.
  final String fileName;

  final int width;
  final int height;
  final int byteSize;

  /// O nome do arquivo, quando a imagem veio do Finder.
  final String? name;

  /// O caminho de onde ela foi copiada, quando veio do Finder.
  final String? path;

  /// O endereço da página, quando ela veio de um navegador que o informa.
  final String? source;

  /// O que a lista mostra: o nome do arquivo, ou "Imagem 1280×720" quando a
  /// imagem não tem nome — a captura de tela direto para a área de
  /// transferência, a imagem do navegador.
  String get title {
    final trimmed = name?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'Imagem $dimensions';
  }

  String get dimensions => '$width×$height';

  /// O texto em que a busca procura além do título: o caminho, o site e as
  /// dimensões escritas com um `x` comum — ninguém digita o `×` do título.
  String get searchable => [?path, ?source, '${width}x$height'].join('\n');

  /// O título como o leitor de tela o diz: "Imagem de 1280 por 720" — o `×`
  /// do título ele lê "vezes".
  String get spokenTitle {
    final trimmed = name?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'Imagem de $width por $height';
  }

  String toJson() => jsonEncode({
    'file': fileName,
    'width': width,
    'height': height,
    'bytes': byteSize,
    'name': ?name,
    'path': ?path,
    'source': ?source,
  });

  /// `null` para o que não tem forma de imagem — uma linha corrompida não
  /// derruba a lista, vira um texto como outro qualquer.
  static PinImage? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, Object?>) return null;

      final file = map['file'];
      if (file is! String || file.isEmpty) return null;

      // Campo a campo, perguntando o tipo: um JSON válido com o tipo errado
      // num campo não pode derrubar a lista inteira do Pin.
      int number(String key) => switch (map[key]) {
        final num value => value.toInt(),
        _ => 0,
      };
      String? text(String key) => switch (map[key]) {
        final String value => value,
        _ => null,
      };

      return PinImage(
        fileName: file,
        width: number('width'),
        height: number('height'),
        byteSize: number('bytes'),
        name: text('name'),
        path: text('path'),
        source: text('source'),
      );
    } on FormatException {
      return null;
    }
  }
}

/// Uma imagem que acabou de passar pela área de transferência, com os bytes
/// — o que o lado nativo entrega, antes de virar arquivo.
class CapturedImage {
  const CapturedImage({
    required this.bytes,
    required this.hash,
    required this.extension,
    required this.width,
    required this.height,
    this.name,
    this.path,
    this.source,
  });

  final Uint8List bytes;

  /// SHA-256 do conteúdo, em hexadecimal — ver [PinImage.fileName].
  final String hash;

  /// `png`, `jpg`, `heic`… — o formato em que ela chegou, e no qual ela é
  /// guardada: converter a foto do Finder para PNG a deixaria cinco vezes
  /// maior, e mudaria o que a pessoa copiou.
  final String extension;

  final int width;
  final int height;
  final String? name;
  final String? path;
  final String? source;

  String get fileName => '$hash.$extension';

  PinImage toImage() => PinImage(
    fileName: fileName,
    width: width,
    height: height,
    byteSize: bytes.length,
    name: name,
    path: path,
    source: source,
  );

  static CapturedImage? fromMap(Map<Object?, Object?> map) {
    final bytes = map['bytes'];
    final hash = map['hash'];
    final extension = map['extension'];
    if (bytes is! Uint8List || hash is! String || extension is! String) {
      return null;
    }

    String? text(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    return CapturedImage(
      bytes: bytes,
      hash: hash,
      extension: extension,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      name: text('name'),
      path: text('path'),
      source: text('source'),
    );
  }
}

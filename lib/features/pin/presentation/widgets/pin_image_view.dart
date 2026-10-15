import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../models/pin_image.dart';

/// Uma imagem do histórico, lida da pasta de imagens do Pin.
///
/// Duas medidas, o mesmo desenho: a miniatura do tamanho do ícone de tipo,
/// na linha da lista — sem linha mais alta, sem grade, a imagem é só mais um
/// item —, e a imagem inteira no preview.
///
/// Sem o arquivo (uma restauração de backup traz a linha e não a imagem), ela
/// volta a ser o ícone de imagem: a linha continua na lista, com o nome, e o
/// preview diz que a imagem não está mais no disco.
class PinImageView extends ConsumerWidget {
  /// A miniatura da linha, num quadrado de [size].
  const PinImageView.thumbnail({
    super.key,
    required this.image,
    required double size,
  }) : _size = size,
       _isThumbnail = true;

  /// A imagem inteira, cabendo no espaço que tiver.
  const PinImageView.full({super.key, required this.image})
    : _size = null,
      _isThumbnail = false;

  final PinImage image;
  final double? _size;
  final bool _isThumbnail;

  /// Até quanto a imagem do preview é decodificada, nos dois lados. O painel
  /// tem menos de 500 pontos de largura; decodificar uma captura 5K inteira
  /// para mostrá-la ali seria gastar memória num tamanho que ninguém vê.
  static const _fullDecodeSize = 1200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(pinImageStoreProvider);
    final size = _size;

    if (!store.exists(image.fileName)) return _missing(context);

    if (size != null) {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

      final radius = BorderRadius.circular(context.eg.shapes.radiusThumb);

      // A aresta por cima da imagem, e não em volta: uma captura escura numa
      // linha escura sumia sem ela, e por fora ela somaria um pixel a cada
      // lado do quadrado que precisa ter o tamanho do ícone.
      return Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: context.eg.colors.edge),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image(
            image: store.providerOf(image.fileName, cacheWidth: pixels * 4),
            width: size,
            height: size,
            // Recortada no quadrado, como o ícone que ela substitui: uma
            // captura larga espremida inteira num quadrado de 18 pontos vira
            // uma faixa que ninguém reconhece.
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) => _missing(context),
          ),
        ),
      );
    }

    return Image(
      image: store.providerOf(image.fileName, fitWithin: _fullDecodeSize),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: image.spokenTitle,
      errorBuilder: (context, _, _) => _missing(context),
    );
  }

  Widget _missing(BuildContext context) {
    final icon = EgIcon(
      EgIconData.image,
      size: _isThumbnail ? AppIconSizes.md : AppIconSizes.lg,
      color: context.eg.colors.textSecondary,
    );

    if (_isThumbnail) {
      return SizedBox.square(
        dimension: _size,
        child: Center(child: icon),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A imagem não está mais no disco.',
            style: context.eg.text.footnote.copyWith(
              color: context.eg.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

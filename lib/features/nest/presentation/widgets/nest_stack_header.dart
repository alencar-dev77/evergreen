import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/design/tokens/eg_squircle.dart';
import '../../../../shared/utils/byte_size.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/nest_item.dart';

/// A cara da prateleira: a miniatura do primeiro item, quantos são e quanto
/// pesam.
///
/// **É a pilha, não um item.** A miniatura do primeiro é a capa dela, como a
/// foto de cima num maço de fotos — e por isso ele continua na lista abaixo,
/// clicável e escolhível como os outros. Um cabeçalho que *fosse* o primeiro
/// item o tiraria da lista, e com ele a chance de escolher só ele para mandar.
///
/// O que o cabeçalho responde é o que a lista não responde de relance: quantos
/// arquivos estão esperando e quanto isso pesa junto — as duas coisas que
/// decidem se dá para mandar tudo agora.
class NestStackHeader extends StatelessWidget {
  const NestStackHeader({
    super.key,
    required this.items,
    required this.selected,
  });

  final List<NestItem> items;

  /// Quantos estão escolhidos. Zero é o normal, e quer dizer "vai tudo".
  final int selected;

  /// Lado da capa. Grande o bastante para uma miniatura de PDF dizer que
  /// documento é aquele — que é a razão de o Nest pedir miniatura ao sistema.
  static const _cover = 56.0;

  /// Lado da etiqueta de contagem, no canto da capa.
  static const _badge = 22.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _stack(context),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EgSectionLabel(
                selected > 0 ? '$selected de ${items.length}' : 'Na prateleira',
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _count,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: eg.text.panelTitle,
              ),
              const SizedBox(height: AppSpacing.hairline),
              Text(
                _origin(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: eg.text.footnote.copyWith(color: eg.colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A capa, com a contagem no canto.
  ///
  /// A etiqueta fica **sobre** a miniatura, como o número de uma pilha de
  /// papéis: ao lado, ela viraria mais um dado numa linha de dados; ali ela diz
  /// "isto aqui é um monte".
  Widget _stack(BuildContext context) {
    final eg = context.eg;

    return SizedBox.square(
      dimension: _cover + AppSpacing.xs,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: eg.colors.surface,
                shape: EgSquircle.shape(eg.shapes.radiusCard, side: eg.edge),
              ),
              child: SizedBox.square(
                dimension: _cover,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: _preview(context),
                ),
              ),
            ),
          ),
          if (items.length > 1)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: _badge,
                height: _badge,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: eg.colors.accent,
                  shape: const CircleBorder(),
                ),
                child: Text(
                  '${items.length}',
                  style: eg.text.keycap.copyWith(color: eg.colors.onAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final first = items.first;
    final thumbnail = first.thumbnail;

    if (thumbnail != null && !first.isMissing) {
      return ClipRRect(
        borderRadius: context.eg.shapes.rowAll,
        child: Image.memory(
          thumbnail,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    return Center(
      child: EgIcon(
        first.isDirectory ? EgIconData.folder : EgIconData.document,
        size: AppIconSizes.lg,
        color: context.eg.colors.textSecondary,
      ),
    );
  }

  /// "12 arquivos · 8,4 MB" — o que está esperando, somado.
  ///
  /// A soma ignora pasta, como a linha de cada item: medir uma pasta é
  /// percorrê-la inteira, e o número que sairia disso não vale a espera.
  String get _count {
    final total = items.fold(0, (sum, item) => sum + item.sizeInBytes);
    final label = items.length == 1 ? '1 arquivo' : '${items.length} arquivos';

    return total == 0 ? label : '$label · ${ByteSize.compact(total)}';
  }

  /// De onde eles vieram: a pasta, quando todos vieram da mesma; o número de
  /// pastas, quando não.
  ///
  /// É a única coisa do cabeçalho que a lista não repete de outro jeito — e é
  /// o que dá o "de onde para onde" do painel, com o destino logo abaixo.
  String _origin() {
    final folders = {for (final item in items) p.dirname(item.path)};

    if (folders.length > 1) return 'de ${folders.length} pastas';

    return _short(folders.first);
  }

  /// `/Users/lucas/Downloads` → `~/Downloads`; qualquer outro caminho longo →
  /// `…/duas/últimas`.
  ///
  /// O corte é no **começo**, e não no fim: o que identifica uma origem é a
  /// pasta em que ela termina, e um `overflow: ellipsis` comum comeria
  /// justamente essa parte, deixando na tela o pedaço que não diz nada
  /// (`/var/folders/q4/sn8_rnts…`).
  static String _short(String folder) {
    final home = folder.replaceFirst(RegExp(r'^/Users/[^/]+'), '~');
    if (home.length <= _pathLimit) return home;

    final parts = p.split(home).where((part) => part != '/').toList();
    if (parts.length <= 2) return home;

    return '…/${parts[parts.length - 2]}/${parts.last}';
  }

  /// A partir de quantos caracteres o caminho passa a ser cortado. Cabe com
  /// folga na largura do painel, no corpo de rodapé.
  static const _pathLimit = 38;
}

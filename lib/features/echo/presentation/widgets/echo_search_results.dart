import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/meeting_search.dart';
import '../viewmodels/echo_library_view_model.dart';

/// O que a busca achou, no lugar da lista de reuniões.
///
/// Uma reunião por bloco: a linha dela — o título, grifado onde casou, e
/// quando foi — e logo abaixo os trechos, com quem falou e em que minuto. É
/// a resposta à pergunta que levou à busca ("quando falamos disso, e quem
/// disse?") sem abrir nada; abrir é para ouvir e ler em volta.
///
/// O grifo é a cor do texto, como na busca do Pin, e pelo mesmo motivo: ele
/// aparece em muitas linhas ao mesmo tempo, e um fundo em cada uma viraria a
/// lista num mosaico. Na leitura, onde o verde já quer dizer "isto já foi
/// dito", o grifo é outro — ver `EgPalette.findMark`.
class EchoSearchResults extends StatefulWidget {
  const EchoSearchResults({
    super.key,
    required this.query,
    required this.results,
    required this.activeEntry,
    required this.onOpen,
    this.now,
  });

  final String query;
  final List<MeetingSearchResult> results;

  /// A linha que o teclado aponta — ver [EchoLibraryState.entries].
  final int? activeEntry;

  /// O clique numa linha, pelo índice dela em [EchoLibraryState.entries].
  final void Function(int entry) onOpen;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  State<EchoSearchResults> createState() => _EchoSearchResultsState();
}

class _EchoSearchResultsState extends State<EchoSearchResults> {
  /// Uma chave por linha, para a rolagem acompanhar o teclado.
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(EchoSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);

    final active = widget.activeEntry;
    if (active == null || active == oldWidget.activeEntry) return;

    // Depois do quadro: a linha precisa estar desenhada para ter onde rolar.
    // Sem alinhamento — só o bastante para ela entrar na tela, como a seleção
    // do Finder: a lista não pula a cada seta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[active]?.currentContext;
      if (context == null || !context.mounted) return;

      Scrollable.ensureVisible(
        context,
        duration: AppDurations.movement(context, AppDurations.fast),
        curve: AppDurations.curve,
        alignmentPolicy: active > (oldWidget.activeEntry ?? 0)
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    if (results.isEmpty) return _nothing(context);

    var entry = 0;
    final blocks = <Widget>[];

    for (final result in results) {
      final header = entry++;
      final rows = <Widget>[
        _ResultRow(
          key: _keys.putIfAbsent(header, GlobalKey.new),
          result: result,
          isActive: widget.activeEntry == header,
          onTap: () => widget.onOpen(header),
          now: widget.now,
        ),
      ];

      for (final hit in result.hits) {
        final index = entry++;
        rows.add(
          _HitRow(
            key: _keys.putIfAbsent(index, GlobalKey.new),
            hit: hit,
            isActive: widget.activeEntry == index,
            onTap: () => widget.onOpen(index),
          ),
        );
      }

      final hidden = result.hitCount - result.hits.length;
      if (hidden > 0) rows.add(_MoreRow(hidden: hidden));

      if (blocks.isNotEmpty) {
        blocks.add(const SizedBox(height: AppSpacing.md));
      }
      blocks.add(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          // Região viva: quem digita sem ver a tela ouve o tamanho da
          // resposta mudar a cada tecla, como quem vê lê.
          child: Semantics(
            liveRegion: true,
            child: Text(
              _tally(results),
              style: context.eg.text.footnote.copyWith(
                color: context.eg.colors.textTertiary,
              ),
            ),
          ),
        ),
        ...blocks,
      ],
    );
  }

  /// "7 trechos em 3 reuniões" — o tamanho da resposta antes dela.
  static String _tally(List<MeetingSearchResult> results) {
    final hits = results.fold(0, (sum, result) => sum + result.hitCount);
    final meetings = results.length == 1
        ? '1 reunião'
        : '${results.length} reuniões';

    if (hits == 0) return 'Só no título de $meetings';

    return '${hits == 1 ? '1 trecho' : '$hits trechos'} em $meetings';
  }

  /// Nada casou. Diz o que foi procurado e onde — sem ilustração, sem botão:
  /// a saída é apagar uma letra, e o cursor já está lá.
  Widget _nothing(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nada sobre “${widget.query.trim()}” nas reuniões.',
          style: context.eg.text.body,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Todas as palavras precisam estar na mesma reunião.',
          style: context.eg.text.footnote.copyWith(
            color: context.eg.colors.textTertiary,
          ),
        ),
      ],
    ),
  );
}

/// A linha da reunião: o título e quando foi.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.result,
    required this.isActive,
    required this.onTap,
    this.now,
  });

  final MeetingSearchResult result;
  final bool isActive;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final meeting = result.meeting;
    final day = DayLabel.of(meeting.startedAt, now: now);
    final time = DayLabel.time(meeting.startedAt);
    final count = result.hitCount == 1
        ? '1 trecho'
        : '${result.hitCount} trechos';

    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isActive,
      // Sem foco próprio: a linha não é parada do Tab. Quem anda pela lista
      // é a busca, com as setas; abrir — pelo clique ou pelo Enter — tira o
      // cursor do campo e entrega o teclado à leitura.
      focusable: false,
      height: _HitRow.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      // Por extenso: o "·" da tela o leitor pronuncia "ponto".
      semanticLabel: [
        'Reunião ${meeting.title}',
        '$day às $time',
        if (result.hitCount > 0) count,
      ].join(', '),
      child: Row(
        children: [
          EgIcon(
            EgIconData.microphone,
            size: AppIconSizes.sm,
            color: context.eg.colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: marked(
                  context,
                  meeting.title,
                  result.titleMarks,
                  // Apontada é peso, como toda linha selecionada do app.
                  isActive
                      ? context.eg.text.bodyStrong
                      : context.eg.text.bodyEmphasis,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('$day · $time', style: context.eg.text.footnote),
        ],
      ),
    );
  }
}

/// Um trecho: quem falou e o que disse, alinhados ao título da reunião, e o
/// minuto à direita, na coluna da data.
///
/// O texto começa exatamente onde o título começa — é o que faz o trecho ler
/// como parte da reunião acima dele, e não como uma reunião a mais —, e o
/// minuto divide a borda direita com a data: os relógios de um bloco formam
/// uma coluna só, que se lê de cima a baixo.
class _HitRow extends StatelessWidget {
  const _HitRow({
    super.key,
    required this.hit,
    required this.isActive,
    required this.onTap,
  });

  final MeetingHit hit;
  final bool isActive;
  final VoidCallback onTap;

  static const headerHeight = 36.0;

  /// Duas linhas de texto — quem falou e o que disse — e o respiro delas.
  static const _height = 46.0;

  /// Onde o título da reunião começa: o glifo e o vão depois dele.
  static const indent = AppIconSizes.sm + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final isSummary = hit.kind == MeetingHitKind.summary;
    final who = isSummary ? 'Resumo' : (hit.speaker ?? '');

    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isActive,
      focusable: false,
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      semanticLabel: [
        who,
        ?hit.timestamp,
        hit.snippet,
      ].where((part) => part.isNotEmpty).join(', '),
      child: Row(
        children: [
          const SizedBox(width: indent),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.eg.text.overline.copyWith(
                    color: context.eg.colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxs),
                Text.rich(
                  TextSpan(
                    children: marked(
                      context,
                      hit.snippet,
                      hit.marks,
                      context.eg.text.body.copyWith(
                        // Apontado, o trecho sobe ao tom do texto principal.
                        color: isActive
                            ? context.eg.colors.textPrimary
                            : context.eg.colors.textSecondary,
                      ),
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(hit.timestamp ?? '', style: context.eg.text.monoSmall),
        ],
      ),
    );
  }
}

/// "mais 4 trechos, grifados na leitura" — o que não coube, contado e não
/// escondido.
class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.hidden});

  final int hidden;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.sm + _HitRow.indent,
      top: AppSpacing.xxs,
    ),
    child: Text(
      hidden == 1
          ? 'mais 1 trecho, grifado na leitura'
          : 'mais $hidden trechos, grifados na leitura',
      style: context.eg.text.footnote.copyWith(
        color: context.eg.colors.textTertiary,
      ),
    ),
  );
}

/// [text] em pedaços, com o que a busca casou em verde.
///
/// Só a cor muda — nem peso nem fundo —, pela mesma razão do grifo do Pin.
List<InlineSpan> marked(
  BuildContext context,
  String text,
  List<MatchRange> marks,
  TextStyle style,
) {
  if (marks.isEmpty) return [TextSpan(text: text, style: style)];

  final highlight = style.copyWith(color: context.eg.colors.accent);
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final mark in marks) {
    if (mark.start < cursor || mark.end > text.length) continue;
    if (mark.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, mark.start), style: style),
      );
    }
    spans.add(
      TextSpan(text: text.substring(mark.start, mark.end), style: highlight),
    );
    cursor = mark.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: style));
  }

  return spans;
}

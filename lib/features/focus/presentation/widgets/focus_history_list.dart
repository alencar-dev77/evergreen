import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_groups.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_day_header.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/focus_session.dart';
import '../../../../core/design/eg_tokens.dart';

/// O histórico da semana, agrupado por dia.
///
/// Uma lista, não uma tabela: a dimensão principal é o que foi feito, e o resto
/// (quando, quanto) são metadados ao redor. A linha responde "que horas, em quê
/// e quanto"; o conteúdo longo (anotações, resumo) mora na região de leitura
/// que abre ao lado, a um clique ou um Enter de distância.
///
/// Três decisões que a versão anterior não tinha, e que eram o que fazia a
/// lista parecer desalinhada:
///
/// - **O dia é do grupo, não da linha.** Antes cada linha repetia "Hoje ·", e
///   cinco sessões do mesmo dia escreviam a mesma palavra cinco vezes.
/// - **Toda linha tem a mesma altura.** Antes uma sessão com anotação ocupava
///   duas linhas e uma sem anotação ocupava uma, e a lista ficava serrilhada.
/// - **Hora e duração em colunas fixas.** É o que deixa comparar as sessões
///   correndo o olho por uma coluna, em vez de caçar o número dentro do texto.
class FocusHistoryList extends StatelessWidget {
  const FocusHistoryList({
    super.key,
    required this.sessions,
    required this.onOpen,
    this.selectedId,
    this.now,
  });

  final List<FocusSession> sessions;

  /// Escolhe a sessão e abre a região de leitura — as duas coisas são o mesmo
  /// gesto, porque uma sessão selecionada e fechada não serve para nada.
  final void Function(int id) onOpen;

  /// A sessão aberta na região, que a lista marca como selecionada: sem isso,
  /// a coluna ao lado mostra um conteúdo que nada na lista reivindica.
  final int? selectedId;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EgEmptyState(
        icon: EgIconData.timer,
        title: 'Nenhuma sessão esta semana',
        message: 'As sessões concluídas aparecem aqui, com suas anotações.',
      );
    }

    final groups = DayGroups.of(
      sessions,
      (session) => session.startedAt,
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          EgDayHeader(label: group.label, total: _totalOf(group.items)),
          for (final session in group.items)
            _SessionRow(
              session: session,
              isSelected: session.id != null && session.id == selectedId,
              onTap: () => onOpen(session.id!),
            ),
        ],
      ],
    );
  }

  /// O quanto de foco aquele dia teve — a soma das sessões, que é a pergunta
  /// que a faixa da semana logo acima responde para a semana inteira.
  static String _totalOf(List<FocusSession> sessions) => DurationFormat.compact(
    sessions.fold(Duration.zero, (total, session) => total + session.duration),
  );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isSelected,
    required this.onTap,
  });

  final FocusSession session;
  final bool isSelected;
  final VoidCallback onTap;

  /// Altura fixa, como a linha do Pin: é o que mantém a coluna da direita
  /// legível quando se corre o olho por ela.
  static const _height = 34.0;

  /// Coluna da hora. Larga o bastante para `09:12` em dígitos tabulares.
  static const _timeColumn = 44.0;

  /// Coluna da duração. Fixa, e não encolhida ao conteúdo, porque é ela que
  /// permite comparar as sessões correndo o olho por uma coluna só — com
  /// largura variável, cada linha põe o número num lugar diferente.
  static const _durationColumn = 64.0;

  @override
  Widget build(BuildContext context) {
    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isSelected,
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _timeColumn,
            child: Text(
              DayLabel.time(session.startedAt),
              style: context.eg.text.monoSmall.copyWith(
                color: context.eg.colors.textTertiary,
              ),
            ),
          ),
          Expanded(child: _label(context)),
          const SizedBox(width: AppSpacing.md),
          // Duração à direita, sempre na mesma coluna: é o número que se
          // compara entre linhas ao correr o olho pela lista.
          SizedBox(
            width: _durationColumn,
            child: Text(
              DurationFormat.compact(session.duration),
              textAlign: TextAlign.right,
              style: context.eg.text.bodyEmphasis,
            ),
          ),
        ],
      ),
    );
  }

  /// O nome da sessão e, atrás dele, o que há guardado no detalhe.
  ///
  /// Num parágrafo só, como o apelido e o conteúdo na linha do Pin: assim o
  /// corte por ellipsis come primeiro o anúncio ("1 anotação · resumo"), que é
  /// acessório, e nunca o nome, que é como a pessoa reconhece a sessão.
  Widget _label(BuildContext context) {
    final contents = _contents();
    if (contents == null) return _title(context);

    return Text.rich(
      TextSpan(
        text: _titleText(context),
        children: [
          TextSpan(
            text: '   $contents',
            style: context.eg.text.footnote.copyWith(
              color: context.eg.colors.textTertiary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: _titleStyle(context),
    );
  }

  Widget _title(BuildContext context) {
    return Text(
      _titleText(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: _titleStyle(context),
    );
  }

  /// Sem atividade escrita não há nome — e a hora, que antes fazia esse papel,
  /// agora tem coluna própria. "Sessão" se apresenta como o registro sem nome
  /// que é, em texto de segundo nível.
  String _titleText(BuildContext context) =>
      session.hasActivity ? session.activity! : 'Sessão';

  TextStyle _titleStyle(BuildContext context) => session.hasActivity
      ? context.eg.text.bodyEmphasis
      : context.eg.text.bodyEmphasis.copyWith(
          color: context.eg.colors.textSecondary,
        );

  /// O que a linha promete que existe lá dentro. `null` quando não há nada — e
  /// aí a linha não anuncia nada, em vez de anunciar um vazio.
  String? _contents() {
    final parts = <String>[
      if (session.notes.isNotEmpty)
        '${session.notes.length} '
            '${session.notes.length == 1 ? 'anotação' : 'anotações'}',
      if (session.hasSummary) 'resumo',
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }
}

import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_groups.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/focus_session.dart';
import 'focus_session_dialog.dart';

/// O histórico da semana, agrupado por dia.
///
/// Uma lista, não uma tabela: a dimensão principal é o que foi feito, e o resto
/// (quando, quanto) são metadados ao redor. A linha responde "que horas, em quê
/// e quanto"; o conteúdo longo (anotações, resumo) mora no detalhe, a um clique
/// ou um Enter de distância.
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
  const FocusHistoryList({super.key, required this.sessions, this.now});

  final List<FocusSession> sessions;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EgEmptyState(
        icon: EgIconData.timer,
        title: 'Nenhuma sessão esta semana',
        message: 'As sessões concluídas aparecem aqui, com o que você anotou.',
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
          // O rótulo do grupo alinha com o texto das linhas, não com a borda do
          // fundo de hover — daí o recuo igual ao padding horizontal da linha.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xxs,
            ),
            child: EgSectionLabel(group.label),
          ),
          for (final session in group.items) _SessionRow(session: session),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final FocusSession session;

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
      onTap: () => FocusSessionDialog.show(context, session),
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _timeColumn,
            child: Text(
              DayLabel.time(session.startedAt),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(child: _label()),
          const SizedBox(width: AppSpacing.md),
          // Duração à direita, sempre na mesma coluna: é o número que se
          // compara entre linhas ao correr o olho pela lista.
          SizedBox(
            width: _durationColumn,
            child: Text(
              DurationFormat.compact(session.duration),
              textAlign: TextAlign.right,
              style: AppTypography.bodyCompactEmphasis,
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
  Widget _label() {
    final contents = _contents();
    if (contents == null) return _title();

    return Text.rich(
      TextSpan(
        text: _titleText(),
        children: [
          TextSpan(
            text: '   $contents',
            style: AppTypography.captionXS.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: _titleStyle(),
    );
  }

  Widget _title() {
    return Text(
      _titleText(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: _titleStyle(),
    );
  }

  /// Sem atividade escrita não há nome — e a hora, que antes fazia esse papel,
  /// agora tem coluna própria. "Sessão" se apresenta como o registro sem nome
  /// que é, em texto de segundo nível.
  String _titleText() => session.hasActivity ? session.activity! : 'Sessão';

  TextStyle _titleStyle() => session.hasActivity
      ? AppTypography.bodyCompactEmphasis
      : AppTypography.bodyCompactEmphasis.copyWith(
          color: AppColors.textSecondary,
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

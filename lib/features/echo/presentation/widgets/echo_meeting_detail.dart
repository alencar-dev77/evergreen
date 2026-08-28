import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../models/echo_capabilities.dart';
import '../../models/meeting.dart';
import '../../models/meeting_segment.dart';
import '../../models/meeting_turn.dart';
import '../../../../core/design/eg_tokens.dart';

/// O corpo da região de leitura: o resumo ou a transcrição da reunião aberta.
///
/// O título e a data ficam no cabeçalho da região (`HubDetailRegion`), ao lado
/// do botão de fechar — aqui fica só o que se lê.
///
/// **Um de cada vez, e não os dois empilhados.** Empilhados, a transcrição
/// empurrava tudo o mais para fora da tela: a lista de reuniões sumia sob meia
/// hora de fala, e trocar de reunião exigia rolar de volta ao topo. São dois
/// documentos sobre a mesma coisa, e o seletor diz qual deles está aberto —
/// que é o mesmo motivo de um app de e-mail não mostrar a mensagem e o anexo
/// no mesmo scroll.
///
/// O resumo abre primeiro de propósito: quem volta a uma reunião de semanas
/// atrás quer o que foi decidido, não reler trinta minutos de fala.
class EchoMeetingDetail extends StatefulWidget {
  const EchoMeetingDetail({
    super.key,
    required this.meeting,
    required this.userName,
    required this.summaries,
    required this.isSummarizing,
    required this.progress,
    required this.onSummarize,
    required this.onDelete,
  });

  final Meeting meeting;

  /// Como chamar quem falou pelo microfone. Vazio, o rótulo é "Você".
  final String userName;

  final SummaryAvailability summaries;
  final bool isSummarizing;

  /// "bloco 2 de 4" enquanto o resumo acontece em partes.
  final (int, int)? progress;

  final VoidCallback onSummarize;
  final VoidCallback onDelete;

  @override
  State<EchoMeetingDetail> createState() => _EchoMeetingDetailState();
}

enum _DetailTab {
  summary('Resumo'),
  transcript('Transcrição');

  const _DetailTab(this.label);

  final String label;
}

class _EchoMeetingDetailState extends State<EchoMeetingDetail> {
  /// Trocar de reunião mantém a aba: quem está comparando a transcrição de duas
  /// reuniões não quer voltar ao resumo a cada clique na lista.
  var _tab = _DetailTab.summary;

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!meeting.isEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: EgSegmentedControl<_DetailTab>(
              value: _tab,
              options: _DetailTab.values,
              labelOf: (option) => option.label,
              onChanged: (option) => setState(() => _tab = option),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // A leitura rola dentro do painel, não na página: é o que mantém a
        // lista ao lado sempre à vista.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _body(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _actions(),
      ],
    );
  }

  Widget _body() {
    if (widget.meeting.isEmpty) {
      return Text(
        'Nenhuma fala foi reconhecida. As causas comuns: o microfone estava '
        'sem permissão, ninguém falou, ou o idioma da transcrição não era o '
        'idioma da reunião.',
        style: context.eg.text.captionSmall,
      );
    }

    return switch (_tab) {
      _DetailTab.summary => _summary(),
      _DetailTab.transcript => _transcript(),
    };
  }

  Widget _summary() {
    final meeting = widget.meeting;

    if (meeting.hasSummary) {
      // Refazendo: o progresso entra **acima** do resumo que já existe, sem
      // apagá-lo. Trocar o texto antigo por "Resumindo…" tiraria da tela a
      // única coisa que a pessoa tem para ler enquanto espera — e ela pediu um
      // resumo novo justamente para comparar com este.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isSummarizing) ...[
            Text(_summarizingLabel(), style: context.eg.text.captionSmall),
            const SizedBox(height: AppSpacing.md),
          ],
          SelectableText(meeting.summary!, style: context.eg.text.reading),
          if (meeting.hasSummaryPrompt) _prompt(meeting.summaryPrompt!),
        ],
      );
    }

    if (widget.isSummarizing) {
      return Text(_summarizingLabel(), style: context.eg.text.captionSmall);
    }

    final explanation = widget.summaries.explanation;
    if (explanation != null) {
      return Text(explanation, style: context.eg.text.captionSmall);
    }

    // Sem resumo ainda, o lugar dele explica o que ele é — melhor que um vazio
    // com um botão solto no rodapé.
    return Text(
      'Esta reunião ainda não foi resumida. O resumo é feito na sua máquina, '
      'a partir da transcrição, e leva alguns segundos.',
      style: context.eg.text.captionSmall,
    );
  }

  /// A instrução que o modelo recebeu para escrever o resumo acima.
  ///
  /// **Depois do resumo, não antes.** O resumo é o que a pessoa veio ler; a
  /// instrução é a procedência dele, e procedência se consulta depois de ler,
  /// como uma nota de rodapé. Acima, ela empurraria o texto para baixo em toda
  /// abertura e faria a leitura começar por um parágrafo que não é o conteúdo.
  ///
  /// Existe porque refazer o resumo é barato e é assim que se experimenta
  /// formatos: o campo das preferências guarda a instrução **da próxima vez**,
  /// e sobrescrevê-lo apagava a memória de como o texto que está na tela foi
  /// pedido. O rótulo diz "deste resumo" justamente para separar as duas.
  ///
  /// Selecionável como o resumo e a transcrição — o uso previsto é copiá-la de
  /// volta para as preferências e mexer em uma frase.
  Widget _prompt(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EgSectionLabel('Instrução deste resumo'),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(prompt, style: context.eg.text.captionSmall),
        ],
      ),
    );
  }

  /// "bloco 2 de 4" quando o texto é longo o bastante para ser resumido em
  /// partes; "Resumindo…" quando é uma só. Progresso real vale mais que uma
  /// ampulheta — é a razão de o estado carregar essa contagem.
  String _summarizingLabel() {
    final progress = widget.progress;

    return progress == null || progress.$2 <= 1
        ? 'Resumindo…'
        : 'Resumindo — bloco ${progress.$1} de ${progress.$2}';
  }

  Widget _transcript() {
    final turns = MeetingTurn.from(widget.meeting.segments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final turn in turns) ...[
          _TurnBlock(turn: turn, userName: widget.userName),
          if (turn != turns.last) const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }

  /// A ação da aba aberta à esquerda; apagar sempre à direita, longe dela.
  ///
  /// Só a aba do resumo tem ação: a transcrição é o que a gravação produziu,
  /// não há o que refazer nela.
  Widget _actions() {
    final meeting = widget.meeting;

    // `isSummarizing` **não** entra aqui. Entrava, e o efeito era o botão sair
    // da árvore no instante em que a pessoa o apertava: a linha subia, o
    // "Apagar" pulava para a esquerda e nada na tela dizia que o resumo estava
    // sendo feito. Refazendo era pior ainda — o corpo da aba volta o resumo
    // antigo, porque `_summary` trata "já tem resumo" antes de "está
    // resumindo", então não sobrava indicação nenhuma. Agora o botão fica, e é
    // ele que carrega a espera.
    final canSummarize =
        !meeting.isEmpty &&
        widget.summaries.isAvailable &&
        _tab == _DetailTab.summary;

    return Row(
      children: [
        if (canSummarize)
          meeting.hasSummary
              // Refazer é barato quando a instrução mudou — e é assim que a
              // pessoa experimenta formatos sem regravar nada.
              ? EgButton.secondary(
                  label: 'Refazer resumo',
                  onPressed: widget.onSummarize,
                  isLoading: widget.isSummarizing,
                )
              : EgButton(
                  label: 'Resumir',
                  onPressed: widget.onSummarize,
                  isLoading: widget.isSummarizing,
                ),
        const Spacer(),
        EgButton.destructive(label: 'Apagar', onPressed: widget.onDelete),
      ],
    );
  }
}

/// Uma fala inteira: quem falou, quando, e o texto em parágrafo.
///
/// O cabeçalho é uma linha só e discreta; o peso visual fica no texto, que é o
/// que a pessoa veio ler. O nome vem antes do horário porque "quem falou" é a
/// pergunta que se faz ao percorrer a transcrição — o horário só interessa
/// quando já se achou o trecho.
///
/// Sem balões de conversa: isso é vocabulário de aplicativo de mensagem, e o
/// que está aqui é um documento para reler, não um bate-papo.
class _TurnBlock extends StatelessWidget {
  const _TurnBlock({required this.turn, required this.userName});

  final MeetingTurn turn;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final isMe = turn.speaker == Speaker.me;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              turn.speaker.labelFor(userName),
              // Verde para você, neutro para a reunião: é a única cor da tela e
              // carrega significado. Quem não distingue a cor lê o nome, que
              // está escrito do lado.
              style: context.eg.text.overline.copyWith(
                color: isMe
                    ? context.eg.colors.accent
                    : context.eg.colors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(turn.timestamp, style: context.eg.text.monoSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(turn.text, style: context.eg.text.reading),
      ],
    );
  }
}

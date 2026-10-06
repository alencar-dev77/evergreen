import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../models/echo_capabilities.dart';
import '../../models/meeting.dart';
import '../../models/meeting_document.dart';
import '../../models/meeting_segment.dart';
import '../../models/meeting_turn.dart';
import '../viewmodels/echo_playback_view_model.dart';
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
    required this.onCancelSummary,
    required this.onCopy,
    required this.onExport,
    required this.onDelete,
    this.playback,
    this.onSeek,
    this.onUserScroll,
  });

  final Meeting meeting;

  /// O player desta reunião, quando ela tem áudio carregado. `null` desenha a
  /// transcrição como sempre foi: texto selecionável, sem relógio.
  final EchoPlaybackState? playback;

  /// O clique numa palavra da transcrição.
  final void Function(int positionMs)? onSeek;

  /// A pessoa rolou a leitura à mão — a transcrição para de seguir a fala.
  final VoidCallback? onUserScroll;

  /// Como chamar quem falou pelo microfone. Vazio, o rótulo é "Você".
  final String userName;

  final SummaryAvailability summaries;
  final bool isSummarizing;

  /// "bloco 2 de 4" enquanto o resumo acontece em partes.
  final (int, int)? progress;

  final VoidCallback onSummarize;

  /// Desistir do resumo em curso. Ver `EchoSummaryRunner.cancel`.
  final VoidCallback onCancelSummary;

  /// Leva a face aberta para a área de transferência e devolve a confirmação
  /// a mostrar — ou `null` se não havia o que copiar.
  final Future<String?> Function(MeetingDocumentKind kind) onCopy;

  /// Escreve a face aberta num arquivo e devolve o nome dele.
  final Future<String?> Function(MeetingDocumentKind kind) onExport;

  final VoidCallback onDelete;

  @override
  State<EchoMeetingDetail> createState() => _EchoMeetingDetailState();
}

class _EchoMeetingDetailState extends State<EchoMeetingDetail> {
  /// Quanto tempo a confirmação de copiar ou exportar fica na tela.
  ///
  /// Tempo de ler três palavras e nada mais: ela responde "deu certo", e a
  /// resposta perde o sentido assim que a pessoa volta ao texto. Permanente,
  /// viraria um rótulo fixo dizendo algo que já não está acontecendo — o
  /// cartão do Leaf pode manter o "copiado" porque o painel dele fecha em
  /// seguida, e esta região fica aberta pelo tempo que a leitura durar.
  static const _noteDuration = Duration(seconds: 3);

  /// O quanto a confirmação pode ocupar na linha do documento.
  static const _noteMaxWidth = 140.0;

  /// Trocar de reunião mantém a aba: quem está comparando a transcrição de duas
  /// reuniões não quer voltar ao resumo a cada clique na lista.
  var _tab = MeetingDocumentKind.summary;

  /// O que acabou de acontecer com este documento — "Resumo copiado", o nome
  /// do arquivo escrito. `null` no repouso, que é quase sempre.
  String? _note;
  Timer? _noteTimer;

  /// Exportar mexe no disco e abre o Finder: o botão carrega a espera em vez
  /// de sair da tela, como todo botão de trabalho demorado do aplicativo.
  var _isExporting = false;

  /// Uma chave por fala, para a rolagem achar a que está tocando.
  final _turnKeys = <int, GlobalKey>{};

  /// A fala que a rolagem foi buscar por último — rolar de novo só quando a
  /// voz passa para a próxima, e não a cada pergunta ao player.
  int? _followedTurn;

  @override
  void didUpdateWidget(EchoMeetingDetail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trocar de reunião apaga a confirmação: "Resumo copiado" sobre a reunião
    // seguinte diria que o resumo *dela* foi copiado, e não foi.
    if (oldWidget.meeting.id != widget.meeting.id) {
      _clearNote();
      _turnKeys.clear();
      _followedTurn = null;
    }
  }

  @override
  void dispose() {
    _noteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!meeting.isEmpty) ...[
          _documentBar(),
          const SizedBox(height: AppSpacing.md),
        ],
        // A leitura rola dentro do painel, não na página: é o que mantém a
        // lista ao lado sempre à vista.
        Expanded(
          // Só a rolagem da pessoa conta: a que a leitura faz sozinha para
          // seguir a fala não tem direção de usuário, e não desliga nada.
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                widget.onUserScroll?.call();
              }
              return false;
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _body(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _actions(),
      ],
    );
  }

  /// A linha do documento: que face está aberta, e o que fazer com ela.
  ///
  /// **Copiar e exportar moram aqui, e não no rodapé com "Resumir" e
  /// "Apagar".** O rodapé é o que se faz com a *reunião* — refazer o resumo
  /// dela, apagá-la. Estes dois são o que se faz com o *documento* que está
  /// aberto, e por isso ficam na linha que escolhe qual deles é: o botão muda
  /// de alvo junto com a aba, e ver as duas coisas na mesma linha é o que
  /// torna isso óbvio sem uma palavra de explicação.
  Widget _documentBar() {
    // `Wrap`, e não `Row` — a mesma razão que o `EgSegmentedControl` documenta
    // para a fila dele: a região de leitura tem 480px, e numa tela pequena
    // demais para a janela crescer, ou nos 220ms em que ela ainda está
    // crescendo, o seletor mais os dois botões não cabem na mesma linha.
    // Quebrando, as ações continuam todas visíveis; num `Row` elas estourariam
    // o layout, que é o mesmo que escondê-las. Onde há largura — que é o caso
    // normal — nada muda: `spaceBetween` mantém o seletor à esquerda e as ações
    // à direita, numa linha só.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppSpacing.sm,
      children: [
        EgSegmentedControl<MeetingDocumentKind>(
          value: _tab,
          options: MeetingDocumentKind.values,
          labelOf: (option) => option.label,
          onChanged: _selectTab,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _noteLabel(),
            EgButton.secondary(
              label: 'Copiar',
              compact: true,
              onPressed: _hasDocument ? _copy : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            EgButton.secondary(
              label: 'Exportar',
              compact: true,
              isLoading: _isExporting,
              onPressed: _hasDocument ? _export : null,
            ),
          ],
        ),
      ],
    );
  }

  /// A confirmação, alinhada à direita, colada nos botões que a produziram.
  ///
  /// Texto, e não um toast: um aviso flutuante para "copiei" é peso de mais
  /// para uma ação que não pode dar errado, e a região de leitura não tem
  /// canto onde ele caberia sem cobrir o que se está lendo.
  Widget _noteLabel() {
    final note = _note;
    if (note == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ConstrainedBox(
        // Teto, e não largura: a confirmação é curta ("Resumo copiado"), e o
        // teto existe para ela nunca empurrar os botões que a produziram para
        // fora da linha. É também por isso que exportar confirma "exportado" e
        // não o nome do arquivo — o nome é longo, e quem vai lê-lo é a janela
        // do Finder que abriu com ele selecionado.
        constraints: const BoxConstraints(maxWidth: _noteMaxWidth),
        child: Text(
          note,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.eg.text.footnote,
        ),
      ),
    );
  }

  /// Há texto nesta face para levar embora?
  ///
  /// É a mesma pergunta que o corpo responde ao desenhar: resumo que ainda não
  /// foi feito não tem o que copiar, e oferecer o botão assim mesmo seria
  /// prometer uma cópia vazia.
  bool get _hasDocument =>
      MeetingDocument.body(
        widget.meeting,
        _tab,
        userName: widget.userName,
      ) !=
      null;

  void _selectTab(MeetingDocumentKind kind) {
    // A confirmação é da face que estava aberta; a aba nova começa limpa.
    _clearNote();
    setState(() => _tab = kind);
  }

  Future<void> _copy() async {
    final note = await widget.onCopy(_tab);
    _showNote(note);
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);

    final String? note;
    try {
      note = await widget.onExport(_tab);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }

    _showNote(note);
  }

  void _showNote(String? note) {
    if (!mounted || note == null) return;

    _noteTimer?.cancel();
    setState(() => _note = note);
    _noteTimer = Timer(_noteDuration, _clearNote);
  }

  void _clearNote() {
    _noteTimer?.cancel();
    _noteTimer = null;

    if (!mounted || _note == null) return;
    setState(() => _note = null);
  }

  Widget _body() {
    if (widget.meeting.isEmpty) {
      return Text(
        'Nenhuma fala reconhecida. Em geral é o microfone sem permissão ou '
        'o idioma errado na transcrição.',
        style: context.eg.text.caption,
      );
    }

    return switch (_tab) {
      MeetingDocumentKind.summary => _summary(),
      MeetingDocumentKind.transcript => _transcript(),
    };
  }

  /// O resumo e, depois dele, a procedência.
  Widget _summary() {
    final meeting = widget.meeting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryText(),
        if (meeting.hasSummaryPrompt) _prompt(meeting.summaryPrompt!),
      ],
    );
  }

  Widget _summaryText() {
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
            Text(_summarizingLabel(), style: context.eg.text.caption),
            const SizedBox(height: AppSpacing.md),
          ],
          SelectableText(meeting.summary!, style: context.eg.text.reading),
        ],
      );
    }

    if (widget.isSummarizing) {
      return Text(_summarizingLabel(), style: context.eg.text.caption);
    }

    final explanation = widget.summaries.explanation;
    if (explanation != null) {
      return Text(explanation, style: context.eg.text.caption);
    }

    // Sem resumo ainda, o lugar dele explica o que ele é — melhor que um vazio
    // com um botão solto no rodapé.
    return Text(
      'Ainda sem resumo. Ele é feito nesta máquina, a partir da '
      'transcrição, e leva alguns segundos.',
      style: context.eg.text.caption,
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
          SelectableText(prompt, style: context.eg.text.caption),
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
    final playback = widget.playback;
    final isPlayable =
        playback != null && playback.meetingId == widget.meeting.id;
    final position = isPlayable ? playback.positionMs : null;

    final active = position == null ? null : _activeTurn(turns, position);
    if (isPlayable && playback.isFollowing) _follow(active);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < turns.length; index++) ...[
          _TurnBlock(
            key: isPlayable
                ? _turnKeys.putIfAbsent(index, GlobalKey.new)
                : null,
            turn: turns[index],
            userName: widget.userName,
            spoken: position == null
                ? 0
                : turns[index].spokenCount(position),
            onSeek: isPlayable ? widget.onSeek : null,
          ),
          if (index != turns.length - 1) const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );

    // Com áudio, cada fala é desenhada em pedaços clicáveis, e a seleção de
    // texto passa a ser da coluna inteira — o `SelectableText` de cada fala
    // não aceita pedaços com clique.
    return isPlayable ? SelectionArea(child: column) : column;
  }

  /// A fala em que a voz está agora: a última que já começou.
  static int? _activeTurn(List<MeetingTurn> turns, int positionMs) {
    int? active;
    for (var index = 0; index < turns.length; index++) {
      if (turns[index].startMs > positionMs) break;
      active = index;
    }
    return active;
  }

  /// Rola até a fala que está tocando, uma vez por fala.
  ///
  /// Depois do quadro: a fala precisa estar desenhada para ter onde rolar.
  /// Um terço abaixo do topo, e não colada nele — o que acabou de ser dito
  /// continua à vista acima.
  void _follow(int? turn) {
    if (turn == null || turn == _followedTurn) return;
    _followedTurn = turn;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _turnKeys[turn]?.currentContext;
      if (context == null || !context.mounted) return;

      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: AppDurations.medium,
        curve: AppDurations.curve,
      );
    });
  }

  /// A ação da aba aberta à esquerda; apagar sempre à direita, longe dela.
  ///
  /// Só a aba do resumo tem ação: a transcrição é o que a gravação produziu,
  /// não há o que refazer nela. Copiar e exportar não estão aqui de propósito
  /// — eles são do documento, e moram na linha dele (ver [_documentBar]).
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
        _tab == MeetingDocumentKind.summary;

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
        // "Cancelar" ao lado, e não no lugar de "Resumir": o botão que carrega
        // a espera é o mesmo que a começou, e trocá-lo por outro no instante do
        // clique é a armadilha que o comentário acima já descreve. Secundário
        // porque desistir nunca é a ação principal da tela.
        if (canSummarize && widget.isSummarizing) ...[
          const SizedBox(width: AppSpacing.sm),
          EgButton.secondary(
            label: 'Cancelar',
            onPressed: widget.onCancelSummary,
          ),
        ],
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
///
/// Com áudio, o parágrafo é desenhado pedaço por pedaço: o que já foi dito
/// fica em verde (é algo ligado, que é o papel do verde no aplicativo) e o
/// resto no tom de leitura, então a fronteira entre os dois é onde a voz está.
/// Clicar em qualquer pedaço leva o áudio até ele.
class _TurnBlock extends StatefulWidget {
  const _TurnBlock({
    super.key,
    required this.turn,
    required this.userName,
    this.spoken = 0,
    this.onSeek,
  });

  final MeetingTurn turn;
  final String userName;

  /// Quantos pedaços desta fala já foram ditos — de nenhum, numa fala que
  /// ainda não chegou, a todos, numa que já passou.
  final int spoken;

  /// `null` sem áudio: a fala fica como sempre foi, texto selecionável.
  final void Function(int positionMs)? onSeek;

  @override
  State<_TurnBlock> createState() => _TurnBlockState();
}

class _TurnBlockState extends State<_TurnBlock> {
  /// Um reconhecedor por pedaço, criado uma vez — recriá-los a cada pergunta
  /// ao player seria jogar fora centenas de objetos dez vezes por segundo.
  List<TapGestureRecognizer> _taps = const [];

  @override
  void initState() {
    super.initState();
    _buildTaps();
  }

  @override
  void didUpdateWidget(_TurnBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.turn.pieces, widget.turn.pieces) ||
        (oldWidget.onSeek == null) != (widget.onSeek == null)) {
      _disposeTaps();
      _buildTaps();
    }
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  void _buildTaps() {
    if (widget.onSeek == null) {
      _taps = const [];
      return;
    }

    _taps = [
      for (final piece in widget.turn.pieces)
        TapGestureRecognizer()
          ..onTap = () => widget.onSeek?.call(piece.startMs),
    ];
  }

  void _disposeTaps() {
    for (final tap in _taps) {
      tap.dispose();
    }
    _taps = const [];
  }

  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    final userName = widget.userName;
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
        if (_taps.isEmpty || _taps.length != turn.pieces.length)
          SelectableText(turn.text, style: context.eg.text.reading)
        else
          Text.rich(
            TextSpan(
              style: context.eg.text.reading,
              children: [
                for (var index = 0; index < turn.pieces.length; index++)
                  TextSpan(
                    text: turn.pieces[index].text,
                    recognizer: _taps[index],
                    mouseCursor: SystemMouseCursors.click,
                    style: index < widget.spoken
                        ? TextStyle(color: context.eg.colors.accent)
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/leaf_note.dart';
import '../../models/leaf_reminder.dart';
import '../../../../core/design/eg_tokens.dart';

/// Medidas do cartão da parede.
///
/// Vivem aqui, e não em `app_metrics.dart`, porque são geometria deste módulo —
/// como o `_panelWidth` de cada painel do overlay. O que é do design system
/// (espaçamento, raio, cor) continua vindo dos tokens.
abstract final class LeafCardMetrics {
  /// Largura do cartão. Com três colunas e o respiro de [gap], fecha o painel
  /// em 778 (ver `LeafGrid.widthFor`).
  static const width = 236.0;

  /// Altura do cartão.
  ///
  /// É o teto, não uma preferência: três linhas de cartão mais o rodapé de
  /// dicas precisam caber inteiras na janela flutuante, que tem 800px de altura
  /// (ver `OverlayWindow`) e é centralizada na tela. Com 200, a parede cheia
  /// fecha em 706 e ainda sobra a margem da sombra; um cartão mais alto faria a
  /// última linha ser cortada pela borda da janela.
  ///
  /// É o que separa "anotação de reunião" de "recado de post-it": em 236x200
  /// cabem [LeafNote.maxLength] caracteres em nove linhas — quatro vezes a área
  /// do quadrado pequeno com que o módulo nasceu.
  static const height = 200.0;

  static const gap = AppSpacing.lg;

  /// Quantas linhas de texto o cartão mostra.
  static const contentLines = 9;
}

/// Um cartão colado na parede.
///
/// Não é um post-it de papel: sem amarelo, sem sombra e sem inclinação. A
/// sensação de post-it vem do comportamento — efêmero, sempre à vista, jogado
/// fora sem cerimônia —, não da textura. Cor aqui só significa estado
/// (selecionado), como em qualquer outra superfície do Evergreen.
class LeafNoteCard extends StatelessWidget {
  const LeafNoteCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.isCopied,
    required this.onTap,
    required this.onDelete,
    required this.onRemind,
    required this.onToggleHidden,
    this.isPeeking = false,
    this.now,
  });

  final LeafNote note;
  final bool isSelected;

  /// Esta é a vaga que acabou de ser copiada.
  final bool isCopied;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// O sino: o cartão vira o seletor de lembrete.
  final VoidCallback onRemind;

  /// O olho: põe o cartão sob o vidro fosco, ou o tira de lá.
  final VoidCallback onToggleHidden;

  /// O espaço está apertado sobre este cartão: o vidro sai enquanto durar.
  final bool isPeeking;

  /// Injetável para o teste não depender do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final reminder = note.reminderAfter(now ?? DateTime.now());

    return EgHoverable(
      onTap: onTap,
      // A vaga é o endereço do cartão na parede — é por ela que se fala dele
      // ("o três"), e ela está desenhada como um número solto no rodapé, que
      // lido cru sai como um algarismo sem assunto.
      // O cartão sob o vidro também não é lido em voz alta: o leitor de tela
      // é outra forma de a tela mostrar o texto.
      semanticLabel: note.isHidden
          ? 'Vaga ${note.slot}, oculta'
          : 'Vaga ${note.slot}, ${note.content}',
      selected: isSelected ? true : null,
      builder: (context, state) {
        return _LeafCardSurface(
          state: state,
          isSelected: isSelected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, state.isHovered),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _FrostedGlass(
                  // Espiar é sob o mouse ou com o espaço apertado, e só
                  // enquanto durar: ler o segredo não pode exigir lembrar de
                  // escondê-lo de novo.
                  frosted: note.isHidden && !state.isHovered && !isPeeking,
                  child: Text(
                    note.content,
                    maxLines: LeafCardMetrics.contentLines,
                    overflow: TextOverflow.ellipsis,
                    style: context.eg.text.bodyCompact,
                  ),
                ),
              ),
              // A idade fica, e fica embaixo: ela é a única coisa que a parede
              // conta sobre o tempo, e é o que separa o recado de hoje do que
              // está colado ali há três semanas. No pé, no tom mais baixo da
              // escala, ela não disputa com o texto nem com o número.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      // A idade do recado, não a do papel: uma anotação
                      // reescrita agora dizia "há 3 semanas" — ver
                      // [LeafNote.changedAt].
                      RelativeTime.format(note.changedAt, now: now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.eg.text.footnote.copyWith(
                        color: context.eg.colors.textQuaternary,
                      ),
                    ),
                  ),
                  // O lembrete marcado mora no pé, ao lado da idade: as duas
                  // são o que o cartão diz sobre o tempo — de quando é e para
                  // quando é.
                  if (reminder != null)
                    _ReminderTag(
                      label: LeafReminder.label(
                        reminder,
                        now ?? DateTime.now(),
                      ),
                      onTap: onRemind,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// A vaga em cima, à esquerda: ela é o **atalho**, não um rodapé.
  ///
  /// O número era um algarismo solto no pé do cartão, ao lado da idade da
  /// anotação — informação que ninguém procura num mural de nove recados. Em
  /// cima, em etiqueta, ele é a tecla que copia aquele cartão, e a primeira
  /// coisa que o olho encontra ao varrer a parede.
  ///
  /// À direita, o que acabou de acontecer: "copiado" logo depois da tecla, e a
  /// lixeira sob o mouse. Trocar em vez de somar, como no rodapé de antes — o
  /// cartão não tem largura para os dois, e sobrepor seria pior.
  Widget _header(BuildContext context, bool isHovered) {
    final eg = context.eg;

    return Row(
      children: [
        _SlotBadge(slot: note.slot, isCopied: isCopied),
        const Spacer(),
        if (isHovered) ...[
          _IconAffordance(
            icon: note.isHidden ? EgIconData.eyeOff : EgIconData.eye,
            semanticLabel: note.isHidden ? 'Mostrar texto' : 'Ocultar texto',
            // Riscado e verde quando o vidro está posto: é um estado
            // **ligado** no cartão, como o sino do lembrete.
            color: note.isHidden ? eg.colors.accentLight : null,
            onTap: onToggleHidden,
          ),
          const SizedBox(width: AppSpacing.sm),
          _IconAffordance(
            icon: EgIconData.bell,
            semanticLabel: 'Lembrete',
            onTap: onRemind,
          ),
          const SizedBox(width: AppSpacing.sm),
          _DeleteAffordance(onTap: onDelete),
        ] else if (isCopied)
          Text(
            'copiado',
            style: eg.text.monoSmall.copyWith(color: eg.colors.textSecondary),
          )
        // Fora do mouse, o olho riscado fica no canto: sem ele, um cartão
        // borrado parece um cartão com defeito, e não um cartão protegido.
        else if (note.isHidden)
          EgIcon(
            EgIconData.eyeOff,
            size: AppIconSizes.xs,
            color: eg.colors.textTertiary,
          ),
      ],
    );
  }
}

/// A etiqueta com o número da vaga.
///
/// Verde só quando aquele cartão acabou de ser copiado: é o mesmo verde de
/// "ligado" do resto do aplicativo, aqui no sentido de "foi este".
class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.slot, this.isCopied = false});

  final int slot;
  final bool isCopied;

  /// Lado da etiqueta. Quadrada, e do tamanho de um key-cap: ela **é** a tecla
  /// que copia o cartão.
  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgIconBadge(
      size: _size,
      color: isCopied ? eg.colors.accent : eg.colors.control,
      child: Text(
        '$slot',
        style: eg.text.keycap.copyWith(
          color: isCopied ? eg.colors.onAccent : eg.colors.textSecondary,
        ),
      ),
    );
  }
}

/// Uma vaga vazia da parede: o número, e o contorno tracejado.
///
/// **Tracejado, e não sólido**: o traço interrompido é o que diz "aqui cabe
/// alguma coisa" sem desenhar um cartão que não existe. Sólida, a vaga vazia
/// parecia um cartão em branco — e nove cartões em branco parecem nove
/// anotações que alguém apagou.
///
/// A primeira livre é a única clicável: ela é o alvo de mouse do `⌘+`, porque
/// nenhuma ação do Evergreen é só de teclado. As de trás dela ficam ali como
/// endereço — é o que faz "o sete" querer dizer alguma coisa antes de existir
/// um sétimo cartão.
class LeafEmptySlot extends StatelessWidget {
  const LeafEmptySlot({
    super.key,
    required this.slot,
    required this.isNext,
    required this.isSelected,
    this.onTap,
  });

  final int slot;

  /// É a próxima vaga a ser usada — a que o Enter e o `⌘+` preenchem.
  final bool isNext;

  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgHoverable(
      onTap: onTap,
      // Um contorno tracejado não diz nada a quem não vê a tela — e o que ele
      // conta (que ainda cabe anotação na parede) é justamente o que não está
      // escrito em lugar nenhum.
      semanticLabel: isNext
          ? 'Vaga $slot, livre — escrever anotação'
          : 'Vaga $slot, livre',
      selected: isSelected ? true : null,
      builder: (context, state) {
        final isLit = isSelected || state.isHovered;

        return CustomPaint(
          painter: _DashedBorder(
            color: isLit ? eg.colors.line : eg.colors.edge,
            radius: eg.shapes.cardAll.topLeft.x,
          ),
          child: SizedBox(
            width: LeafCardMetrics.width,
            height: LeafCardMetrics.height,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$slot',
                    style: eg.text.keycap.copyWith(
                      color: eg.colors.textQuaternary,
                    ),
                  ),
                  // Só a próxima diz o que fazer: repetir o convite em cinco
                  // vagas transformaria a parede vazia num cartaz.
                  if (isNext)
                    Expanded(
                      child: Center(
                        child: Text(
                          'enter pra criar',
                          style: eg.text.footnote.copyWith(
                            color: isLit
                                ? eg.colors.textTertiary
                                : eg.colors.textQuaternary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// O contorno interrompido da vaga vazia.
///
/// Desenhado à mão porque o Flutter não tem borda tracejada: `Border` só sabe
/// linha cheia, e um pacote a mais para dez linhas de `Path` seria uma
/// dependência para o resto da vida do projeto.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  /// O traço e o vão, em pixels. Curtos: o tracejado é para ser lido como
  /// "provisório", não como carimbo de cupom.
  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// A caixa do cartão: tamanho, superfície, borda e estados.
///
/// Compartilhada pelo cartão com anotação, pela vaga vazia e pelo cartão em
/// edição, para que os três tenham exatamente a mesma silhueta — trocar de
/// estado não pode mexer no tamanho de nada.
///
/// Os estados saem da matriz do design system ([EgSurfaceStyle]); o que este
/// módulo acrescenta são duas colunas próprias: a vaga livre, que em repouso é
/// só um contorno, e o cartão em edição, cuja borda accent é o único sinal de
/// que o teclado agora pertence a ele.
class _LeafCardSurface extends StatelessWidget {
  const _LeafCardSurface({
    required this.child,
    required this.isSelected,
    this.state = const EgInteraction(),
    this.isEditing = false,
  });

  final Widget child;
  final bool isSelected;
  final EgInteraction state;
  final bool isEditing;

  /// O cartão sendo escrito: borda accent cheia, em vez do `accentDeep` do
  /// apenas-selecionado. É um degrau a mais na mesma cor, não uma cor nova.
  EgSurfaceStyle _editingStyle(BuildContext context) {
    final eg = context.eg;

    return eg.surfaces.card.copyWith(
      border: eg.colors.accent,
      selectedBorder: eg.colors.accent,
    );
  }

  EgSurfaceStyle _styleOf(BuildContext context) =>
      isEditing ? _editingStyle(context) : context.eg.surfaces.card;

  @override
  Widget build(BuildContext context) {
    // Seleção vence hover: uma é onde o teclado está, a outra é onde o mouse
    // passou, e quando coincidem a que importa é a do teclado. Quem garante
    // essa ordem é a matriz, não este arquivo.
    return EgSurface(
      state: state,
      style: _styleOf(context),
      isSelected: isSelected,
      width: LeafCardMetrics.width,
      height: LeafCardMetrics.height,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: context.eg.shapes.cardAll,
      child: child,
    );
  }
}

/// O lembrete marcado, no pé do cartão: o sino e a hora.
///
/// O sino vem no verde claro: um lembrete marcado é algo **ligado** naquele
/// cartão, e é isso que o verde quer dizer no resto do aplicativo. A hora fica
/// neutra — o verde marca o estado, não o texto.
class _ReminderTag extends StatelessWidget {
  const _ReminderTag({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgHoverable(
      onTap: onTap,
      semanticLabel: 'Lembrete $label',
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EgIcon(
            EgIconData.bell,
            size: AppIconSizes.xs,
            color: eg.colors.accentLight,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: eg.text.monoSmall.copyWith(
              color: state.isHovered
                  ? eg.colors.textPrimary
                  : eg.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Um ícone que só aparece sob o mouse e acende quando o mouse chega nele.
class _IconAffordance extends StatelessWidget {
  const _IconAffordance({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.color,
  });

  final EgIconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Cor fixa, para quando o ícone mostra um estado ligado.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, state) => EgIcon(
        icon,
        size: AppIconSizes.xs,
        color:
            color ??
            (state.isHovered || state.isPressed
                ? context.eg.colors.textPrimary
                : context.eg.colors.textTertiary),
      ),
    );
  }
}

/// O vidro fosco sobre o texto de um cartão oculto.
///
/// Um desfoque **do próprio texto**, e não um `BackdropFilter` por cima: o
/// filtro de fundo recompõe tudo o que está atrás dele a cada quadro, e a
/// parede pode ter nove destes. Desfocar o texto dá a mesma imagem — linhas
/// que se sabe que existem e não se consegue ler — pelo custo de uma camada.
///
/// A entrada e a saída correm em [AppDurations.fast]: o bastante para o texto
/// aparecer "se desembaçando" sob o mouse, e não piscar.
class _FrostedGlass extends StatelessWidget {
  const _FrostedGlass({required this.frosted, required this.child});

  final bool frosted;
  final Widget child;

  /// Forte o bastante para uma senha de doze caracteres virar uma mancha, e
  /// fraco o bastante para ainda se ver quantas linhas o cartão tem.
  static const _sigma = 6.0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: frosted ? 1 : 0),
      duration: AppDurations.fast,
      curve: AppDurations.curve,
      child: child,
      builder: (context, t, child) {
        // Sem vidro, sem camada: o cartão comum não paga pelo recurso.
        if (t == 0) return child!;

        return ExcludeSemantics(
          excluding: frosted,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _sigma * t,
              sigmaY: _sigma * t,
              tileMode: TileMode.decal,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// A lixeira que aparece no rodapé do cartão sob o mouse.
class _DeleteAffordance extends StatelessWidget {
  const _DeleteAffordance({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      semanticLabel: 'Apagar anotação',
      builder: (context, state) => EgIcon(
        EgIconData.trash,
        size: AppIconSizes.xs,
        // Vermelho já sob o mouse, e não só no clique: é a única ação
        // destrutiva do cartão, e ela precisa se anunciar antes de acontecer.
        color: state.isHovered || state.isPressed
            ? context.eg.colors.error
            : context.eg.colors.textTertiary,
      ),
    );
  }
}

/// O cartão enquanto está sendo escrito.
///
/// É o mesmo cartão, com o texto virando campo no lugar onde ele já estava —
/// nada abre, nada cresce, nada muda de posição. A borda accent é o único sinal
/// de que o teclado agora pertence a este cartão, seguindo o `EgTextField`.
class LeafNoteEditor extends StatelessWidget {
  const LeafNoteEditor({
    super.key,
    required this.slot,
    required this.controller,
    required this.focusNode,
  });

  final int slot;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// A partir de quantos caracteres restantes o contador aparece.
  ///
  /// Só perto do fim: um contador permanente ensinaria a pessoa a escrever
  /// olhando para o número, e o limite existe para caber no cartão, não para
  /// ser administrado.
  static const _counterThreshold = 15;

  @override
  Widget build(BuildContext context) {
    return _LeafCardSurface(
      isSelected: true,
      isEditing: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A mesma etiqueta do cartão pronto, no mesmo canto: escrever não
          // pode mudar de lugar o número da vaga, senão o cartão em edição
          // parece outro componente.
          _header(context),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _field(context)),
        ],
      ),
    );
  }

  Widget _field(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: context.eg.text.bodyCompact,
      cursorColor: context.eg.colors.accent,
      cursorWidth: 1.5,
      maxLines: LeafCardMetrics.contentLines,
      // O campo trata o Enter como quebra de linha, e é assim que o `⇧⏎`
      // funciona. O Enter puro nunca chega aqui: o `Shortcuts` do painel o
      // consome antes, para guardar a anotação (ver `LeafOverlayIntents`).
      textInputAction: TextInputAction.newline,
      inputFormatters: [LengthLimitingTextInputFormatter(LeafNote.maxLength)],
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: 'O que não pode escapar',
        hintStyle: context.eg.text.bodyCompact.copyWith(
          color: context.eg.colors.textTertiary,
        ),
      ),
    );
  }

  /// A vaga à esquerda e, quando o texto se aproxima do teto, quanto falta à
  /// direita — no lugar em que o cartão pronto mostra o "copiado".
  Widget _header(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remaining =
            LeafNote.maxLength - controller.text.characters.length;

        return Row(
          children: [
            _SlotBadge(slot: slot),
            const Spacer(),
            if (remaining <= _counterThreshold)
              Text(
                '$remaining',
                style: context.eg.text.monoSmall.copyWith(
                  color: remaining <= 0
                      ? context.eg.colors.warning
                      : context.eg.colors.textTertiary,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// O cartão virado para marcar um lembrete.
///
/// Mesma silhueta, mesmo lugar, a mesma borda accent da edição — o teclado é
/// deste cartão agora. Em cima, quatro respostas prontas que se resolvem num
/// clique; embaixo, um campo para o resto ("16:30", "sexta 14h", "em 45
/// min"), com a leitura dele ao vivo logo abaixo. A prévia é o que torna o
/// campo confiável: ninguém confirma um horário sem ver o que foi entendido.
class LeafReminderPicker extends StatelessWidget {
  const LeafReminderPicker({
    super.key,
    required this.note,
    required this.controller,
    required this.focusNode,
    required this.onPick,
    required this.onRemove,
    this.now,
  });

  final LeafNote note;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onRemove;

  /// Injetável para o teste não depender do relógio real.
  final DateTime? now;

  DateTime get _now => now ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    final current = note.reminderAfter(_now);

    return _LeafCardSurface(
      isSelected: true,
      isEditing: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SlotBadge(slot: note.slot),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Lembrar',
                style: eg.text.footnote.copyWith(
                  color: eg.colors.textSecondary,
                ),
              ),
              const Spacer(),
              // Só quando há o que tirar: um "remover" num cartão sem lembrete
              // seria um botão que não faz nada.
              if (current != null) _RemoveReminder(onTap: onRemove),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _presets(),
          const Spacer(),
          _field(context),
          const SizedBox(height: AppSpacing.xxs),
          _preview(context, current),
        ],
      ),
    );
  }

  /// As quatro respostas prontas, em duas linhas de duas — a largura do
  /// cartão não comporta quatro lado a lado sem cortar "Amanhã 9h".
  Widget _presets() {
    const presets = LeafReminderPreset.values;

    Widget row(int first) => Row(
      children: [
        Expanded(child: _PresetButton(presets[first], onPick: _pick)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _PresetButton(presets[first + 1], onPick: _pick)),
      ],
    );

    return Column(
      children: [
        row(0),
        const SizedBox(height: AppSpacing.xs),
        row(2),
      ],
    );
  }

  void _pick(LeafReminderPreset preset) => onPick(preset.at(_now));

  Widget _field(BuildContext context) {
    final eg = context.eg;

    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      decoration: BoxDecoration(border: Border(bottom: eg.hairline)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: eg.text.bodyCompact,
        cursorColor: eg.colors.accent,
        cursorWidth: 1.5,
        maxLines: 1,
        // O Enter nunca chega aqui: o `Shortcuts` do painel o consome antes,
        // para confirmar (ver `LeafOverlayIntents.reminding`).
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'ou digite: 16:30, sexta 14h',
          hintStyle: eg.text.bodyCompact.copyWith(
            color: eg.colors.textTertiary,
          ),
        ),
      ),
    );
  }

  /// O que o campo entendeu — ou, com ele vazio, o que já está marcado.
  Widget _preview(BuildContext context, DateTime? current) {
    final eg = context.eg;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final text = controller.text.trim();
        final parsed = LeafReminder.parse(text, _now);

        final (label, color) = switch ((text.isEmpty, parsed, current)) {
          (true, _, final current?) => (
            'Marcado: ${LeafReminder.preview(current, _now)}',
            eg.colors.textTertiary,
          ),
          (true, _, null) => ('', eg.colors.textTertiary),
          (false, final parsed?, _) => (
            LeafReminder.preview(parsed, _now),
            eg.colors.accentLight,
          ),
          (false, null, _) => (
            'Não reconheci esse horário',
            eg.colors.textTertiary,
          ),
        };

        return Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: eg.text.footnote.copyWith(color: color),
        );
      },
    );
  }
}

/// Uma das respostas prontas do seletor.
class _PresetButton extends StatelessWidget {
  const _PresetButton(this.preset, {required this.onPick});

  final LeafReminderPreset preset;
  final ValueChanged<LeafReminderPreset> onPick;

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgInteractiveSurface(
      onTap: () => onPick(preset),
      // Fora da navegação por Tab: o teclado deste cartão é o campo, e
      // tudo o que estes botões fazem também se digita nele ("30 min",
      // "amanhã").
      focusable: false,
      height: _height,
      alignment: Alignment.center,
      borderRadius: eg.shapes.controlAll,
      // Um degrau acima da superfície do cartão em repouso, para o botão
      // existir sem o mouse; o resto da matriz é a do segmented control.
      style: EgSurfaceStyle(
        rest: eg.colors.control,
        hover: eg.colors.hover,
        pressed: eg.colors.raised,
        foreground: eg.colors.textSecondary,
        hoverForeground: eg.colors.textPrimary,
      ),
      builder: (context, state) => Text(
        preset.label,
        style: eg.text.bodyCompact.copyWith(
          color: state.isHovered
              ? eg.colors.textPrimary
              : eg.colors.textSecondary,
        ),
      ),
    );
  }
}

/// "remover", no canto do seletor — vermelho só sob o mouse, como a lixeira.
class _RemoveReminder extends StatelessWidget {
  const _RemoveReminder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return EgHoverable(
      onTap: onTap,
      semanticLabel: 'Remover lembrete',
      builder: (context, state) => Text(
        'remover',
        style: eg.text.footnote.copyWith(
          color: state.isHovered ? eg.colors.error : eg.colors.textTertiary,
        ),
      ),
    );
  }
}

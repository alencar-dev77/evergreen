import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_icon.dart';
import 'eg_spinner.dart';
import 'eg_surface.dart';
import '../../core/design/eg_tokens.dart';

/// Variantes de botão previstas no design system.
enum EgButtonVariant {
  /// Ação primária: o accent chapado, texto escuro.
  primary,

  /// Ação de sistema: branca, texto escuro.
  ///
  /// Existe porque **verde quer dizer ligado ou ação primária**, e "Pausar" ou
  /// "Parar e resumir" não é nem uma coisa nem outra — é a ação mais
  /// importante da tela sem ser uma afirmação. O branco a põe no topo do
  /// contraste sem pedir o accent emprestado.
  neutralStrong,

  /// Ação secundária: superfície de controle com a aresta de luz.
  secondary,

  /// Ação destrutiva: contorno vermelho sobre fundo transparente.
  destructive;

  /// A coluna desta variante na matriz de estado do tema em vigor.
  ///
  /// Função do contexto, e não um `get`: as colunas passaram a depender do
  /// tema, e um enum não tem de onde tirar um. Quem chama já está dentro de um
  /// `build`, então o contexto está sempre à mão.
  EgSurfaceStyle styleOf(BuildContext context) => switch (this) {
    EgButtonVariant.primary => context.eg.surfaces.primary,
    EgButtonVariant.neutralStrong => context.eg.surfaces.neutralStrong,
    EgButtonVariant.secondary => context.eg.surfaces.secondary,
    EgButtonVariant.destructive => context.eg.surfaces.destructive,
  };
}

/// Botão padrão do Evergreen.
///
/// As quatro variantes compartilham geometria e só divergem na coluna da matriz
/// de estado ([EgSurfaceStyle]). Todas cobrem os cinco estados obrigatórios:
/// repouso, hover, pressed, foco e disabled — mais [isLoading], que é o sexto e
/// não se confunde com nenhum deles: o botão está trabalhando, não
/// indisponível.
///
/// **A altura é fixa** (`controlHeight`, ou 26 no [compact]), e não a soma de
/// um padding com o que estiver dentro. Era o que fazia o botão crescer um
/// pixel ao trocar o rótulo pelo spinner — e um botão que muda de tamanho ao
/// ser apertado empurra o que está ao lado justamente no instante em que a
/// pessoa olha para ele.
class EgButton extends StatelessWidget {
  const EgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EgButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
    this.keycap,
    this.compact = false,
  });

  const EgButton.neutralStrong({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
    this.keycap,
    this.compact = false,
  }) : variant = EgButtonVariant.neutralStrong;

  const EgButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
    this.keycap,
    this.compact = false,
  }) : variant = EgButtonVariant.secondary;

  const EgButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
    this.keycap,
    this.compact = true,
  }) : variant = EgButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final EgButtonVariant variant;
  final EgIconData? icon;

  /// Ocupa toda a largura disponível — usado no botão "Copiar" do preview.
  final bool expand;

  /// Recebe o foco ao aparecer. Só faz sentido no botão seguro de um diálogo.
  final bool autofocus;

  /// O botão está executando a própria ação.
  ///
  /// O rótulo dá lugar a um spinner **sem o botão mudar de tamanho** — o
  /// rótulo continua ocupando o lugar dele, invisível, porque um botão que
  /// encolhe ao ser apertado empurra o que está ao lado e faz a tela pular
  /// justamente no instante em que a pessoa olha para ela.
  ///
  /// Enquanto carrega, o toque não passa: a ação já está em curso, e um
  /// segundo disparo faria o mesmo trabalho duas vezes. Isso é diferente de
  /// desabilitar — o botão **não** esmaece, porque ele não está indisponível.
  ///
  /// Quem chama continua responsável por não sumir com o botão: trocar
  /// `if (podeAgir)` por este sinalizador é o que faz a espera ter onde
  /// aparecer. Ver `EchoMeetingDetail`, que era exatamente esse caso.
  final bool isLoading;

  /// A tecla que dispara a mesma ação, impressa dentro do botão.
  ///
  /// A meia opacidade não é enfeite: ela é o que impede a tecla de disputar
  /// com o rótulo. O botão diz o que faz; a tecla diz que existe um caminho
  /// mais rápido, e quem não estiver procurando por ele não a lê.
  final String? keycap;

  /// A altura menor, de 26.
  ///
  /// É a do botão que mora **dentro** de um cartão — o "Apagar" do cartão
  /// destrutivo. Um botão de 32 ali empurraria a linha do cartão para 48 e o
  /// tornaria mais alto que a seção que o contém.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Só o desabilitado de verdade esmaece; carregando, o botão segue inteiro.
    final isDisabled = onPressed == null;
    final style = variant.styleOf(context);

    final button = EgInteractiveSurface(
      onTap: isLoading ? null : onPressed,
      style: style,
      borderRadius: compact
          ? context.eg.shapes.segmentAll
          : context.eg.shapes.controlAll,
      height: compact ? _compactHeight : context.eg.shapes.controlHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.lg,
      ),
      alignment: Alignment.center,
      builder: (context, state) => Opacity(
        opacity: isDisabled ? style.disabledOpacity : 1,
        child: _content(context, style),
      ),
      autofocus: autofocus,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  /// O miolo do botão. Carregando, o rótulo vira o molde que segura a largura
  /// e o spinner ocupa o centro dele.
  Widget _content(BuildContext context, EgSurfaceStyle style) {
    final label = _label(context, style);

    if (!isLoading) return label;

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: label),
        EgSpinner(size: AppIconSizes.sm, color: style.foreground),
      ],
    );
  }

  Widget _label(BuildContext context, EgSurfaceStyle style) => Row(
    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        EgIcon(icon!, size: AppIconSizes.sm, color: style.foreground),
        const SizedBox(width: AppSpacing.sm),
      ],
      // Sob largura apertada o rótulo trunca em vez de estourar o
      // layout do painel que contém o botão.
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: context.eg.text.button.copyWith(color: style.foreground),
        ),
      ),
      if (keycap != null) ...[
        const SizedBox(width: AppSpacing.sm),
        Text(
          keycap!,
          maxLines: 1,
          style: context.eg.text.keycap.copyWith(
            color: style.foreground.withValues(alpha: 0.5),
          ),
        ),
      ],
    ],
  );

  /// A altura do botão que mora dentro de um cartão.
  static const _compactHeight = 26.0;
}

/// Botão apenas de ícone: 36x36, transparente, com hover discreto.
class EgIconButton extends StatelessWidget {
  const EgIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = AppBadgeSizes.md,
    this.iconSize = AppIconSizes.lg,
    this.color,
    this.hoverColor,
  });

  final EgIconData icon;
  final VoidCallback? onPressed;

  /// Legenda de ajuda ao repousar o mouse. Um botão só de ícone sem rótulo
  /// visível depende dela para ser descoberto — e é ela que vira o nome do
  /// botão para o leitor de tela, já que não há texto na tela para virar.
  ///
  /// Um `EgIconButton` sem `tooltip` é, para quem não vê a tela, um botão sem
  /// nome: só passe nulo quando o que ele faz estiver dito em outro lugar do
  /// mesmo grupo.
  final String? tooltip;

  final double size;
  final double iconSize;

  /// A cor do glifo, e a dela sob o mouse. `null` nas duas quer dizer "as do
  /// tema" — o padrão, e o que faz o botão trocar de pele junto com o resto.
  final Color? color;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    // O foco precisa de superfície opaca sob o anel — um botão de ícone em
    // repouso é transparente, então focar já revela o fundo de hover, que é
    // exatamente o que a coluna `ghost` da matriz faz.
    final button = EgInteractiveSurface(
      onTap: onPressed,
      style: context.eg.surfaces.ghost,
      borderRadius: context.eg.shapes.rowAll,
      width: size,
      height: size,
      alignment: Alignment.center,
      semanticLabel: tooltip,
      builder: (context, state) => EgIcon(
        icon,
        size: iconSize,
        color: (state.isHovered || state.isFocused) && isEnabled
            ? hoverColor ?? context.eg.colors.textPrimary
            : color ?? context.eg.colors.textSecondary,
        strokeWidth: 1.6,
      ),
    );

    if (tooltip == null) return button;

    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 500),
      verticalOffset: size / 2 + AppSpacing.xxs,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: context.eg.colors.surface,
        borderRadius: context.eg.shapes.segmentAll,
        border: context.eg.borderAll,
        boxShadow: context.eg.elevations.dropdown,
      ),
      textStyle: context.eg.text.footnote,
      child: button,
    );
  }
}

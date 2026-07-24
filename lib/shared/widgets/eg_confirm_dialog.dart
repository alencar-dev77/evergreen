import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_button.dart';
import 'eg_panel.dart';

/// Diálogo de confirmação do Evergreen.
///
/// Reservado para decisões irreversíveis — é o único motivo pelo qual o app
/// interrompe o fluxo com um modal. Segue a convenção nativa do macOS: título
/// curto sem ponto final, consequência explícita no corpo, ações à direita com
/// a confirmação mais à direita e o cancelar à esquerda dela.
///
/// O botão destrutivo é secundário (borda + texto em vermelho), não vermelho
/// chapado: o preenchimento saturado ficaria mais chamativo que qualquer ação
/// primária real do app.
class EgConfirmDialog extends StatelessWidget {
  const EgConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancelar',
    this.isDestructive = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Pinta a confirmação com a cor semântica de erro.
  final bool isDestructive;

  /// Largura fixa de diálogo de confirmação (`components.md`: 320–400px).
  static const _width = 360.0;

  /// Abre o diálogo e resolve para `true` só se a pessoa confirmar.
  ///
  /// Fechar pelo Esc, clicar fora ou cancelar resultam em `false` — nunca em
  /// `null` para o chamador tratar.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancelar',
    bool isDestructive = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) => EgConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final confirm = isDestructive
        ? EgButton.destructive(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
          )
        : EgButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
          );

    return Center(
      child: CallbackShortcuts(
        // Esc sempre fecha sem confirmar. Declarado aqui — e não deixado para o
        // comportamento padrão da rota — porque o resultado precisa ser `false`
        // explícito, não um pop sem valor.
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(false),
        },
        child: EgPanel(
          width: _width,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.panelTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: AppTypography.bodyCompact),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // O caminho seguro nasce focado: numa ação irreversível, o
                  // Enter reflexo não pode ser o que apaga os dados.
                  EgButton.secondary(
                    label: cancelLabel,
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  confirm,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

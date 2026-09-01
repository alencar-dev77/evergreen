import 'package:flutter/material.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../models/echo_capabilities.dart';
import '../../../../core/design/eg_tokens.dart';

/// Uma permissão do macOS: o que ela traz, como está, e o botão que resolve.
///
/// Compartilhada entre o painel flutuante e a tela do Hub. As duas precisam
/// dizer exatamente a mesma coisa: a pessoa que não conseguiu gravar vai
/// procurar a resposta nas preferências, e encontrar ali um texto diferente do
/// que o painel disse seria pior que não encontrar nada.
///
/// O verbo do botão muda com o estado — "Permitir" enquanto o sistema ainda vai
/// perguntar, "Abrir Ajustes" depois de um "não", porque aí pedir de novo não
/// faz absolutamente nada.
class EchoPermissionRow extends StatelessWidget {
  const EchoPermissionRow({
    super.key,
    required this.title,
    required this.detail,
    required this.status,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final PermissionStatus status;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.eg.text.bodyEmphasis),
              const SizedBox(height: AppSpacing.xxs),
              Text(detail, style: context.eg.text.footnote),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (status.isGranted)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'liberado',
              style: context.eg.text.footnote.copyWith(
                color: context.eg.colors.accent,
              ),
            ),
          )
        else
          EgButton.secondary(label: status.actionLabel, onPressed: onPressed),
      ],
    );
  }
}

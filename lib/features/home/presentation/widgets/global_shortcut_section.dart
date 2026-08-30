import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/system/global_shortcut_slot.dart';
import '../../../../core/system/shortcut_binding.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../../../shared/widgets/eg_shortcut_recorder.dart';
import '../viewmodels/module_settings_view_model.dart';

/// O tópico "Atalho global" — o mesmo nas sete telas que têm um.
///
/// Era escrito à mão em cada tela de módulo, sete vezes o mesmo bloco com uma
/// constante diferente. Virou um widget quando o atalho deixou de ser constante:
/// gravar uma combinação envolve suspender os atalhos do sistema, conferir
/// conflito com os outros seis, gravar no disco e avisar a janela 0 — e essa
/// sequência não pode existir em sete cópias.
///
/// O tópico continua sendo o penúltimo de toda tela de preferência, antes só de
/// permissões. Ver a ordem fixa em `components.md`.
class GlobalShortcutSection extends ConsumerStatefulWidget {
  const GlobalShortcutSection({super.key, required this.slot});

  final GlobalShortcutSlot slot;

  @override
  ConsumerState<GlobalShortcutSection> createState() =>
      _GlobalShortcutSectionState();
}

class _GlobalShortcutSectionState extends ConsumerState<GlobalShortcutSection> {
  bool _isRecording = false;

  /// O motivo da última recusa, enquanto a gravação continua.
  String? _refusal;

  Future<void> _start() async {
    // Os atalhos saem do sistema **antes** de a tela dizer que está à escuta: o
    // Hub é um aplicativo comum e um atalho global dispara com ele na frente,
    // então gravar `⌘⇧C` sem suspender abriria o painel do Pin por cima desta
    // tela.
    await ref
        .read(moduleSettingsViewModelProvider.notifier)
        .setRecording(recording: true);

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _refusal = null;
    });
  }

  Future<void> _stop() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _refusal = null;
    });

    await ref
        .read(moduleSettingsViewModelProvider.notifier)
        .setRecording(recording: false);
  }

  Future<void> _record(ShortcutBinding binding) async {
    final refusal = await ref
        .read(moduleSettingsViewModelProvider.notifier)
        .record(widget.slot, binding);

    if (!mounted) return;

    // Recusada, a tela continua à escuta: quem apertou `⌘C` sem pensar acerta na
    // tentativa seguinte, e fechar a gravação obrigaria a apertar "Alterar" de
    // novo para consertar um engano de meio segundo.
    if (refusal != null) {
      setState(() => _refusal = refusal);
      return;
    }

    await _stop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(moduleSettingsViewModelProvider);
    final binding = settings.bindingFor(widget.slot);
    final isCustom = settings.isCustom(widget.slot);

    return EgSettingsSection(
      title: 'Atalho global',
      children: [
        EgSettingsRow(
          label: widget.slot.openLabel,
          description: _isRecording
              ? 'Segure as modificadoras e aperte a tecla. Esc cancela.'
              : 'Funciona com qualquer aplicativo em foco.',
          showDivider: isCustom,
          trailing: EgShortcutRecorder(
            binding: binding,
            isRecording: _isRecording,
            onStart: _start,
            onCancel: _stop,
            onRecorded: _record,
          ),
        ),
        // A recusa fica embaixo do tópico, e não no lugar da descrição: ela é
        // mais longa que uma linha e precisa da cor de aviso, que a descrição
        // não tem. É a mesma forma que a mensagem do "Restaurar" da tela do
        // aplicativo já usa.
        if (_refusal != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _refusal!,
            style: context.eg.text.captionSmall.copyWith(
              color: context.eg.colors.warning,
            ),
          ),
        ],
        if (isCustom)
          EgSettingsRow(
            label: 'Restaurar padrão',
            description:
                'Volta para ${widget.slot.fallback.compact}, a combinação de '
                'fábrica.',
            showDivider: false,
            trailing: EgButton.secondary(
              label: 'Restaurar',
              onPressed: () => ref
                  .read(moduleSettingsViewModelProvider.notifier)
                  .restoreDefault(widget.slot),
            ),
          ),
      ],
    );
  }
}

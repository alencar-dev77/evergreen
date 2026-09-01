import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../core/system/global_shortcut_slot.dart';
import '../../../../core/system/shortcut_binding.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
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
/// A seção "Atalho global", ou as linhas dela soltas.
///
/// Com [bare], ela devolve as linhas sem o cartão em volta: é o que permite
/// "Abrir o Hub com" morar dentro de "Sistema", na tela do aplicativo, em vez
/// de ganhar uma seção inteira para uma pergunta só.
class GlobalShortcutSection extends ConsumerStatefulWidget {
  const GlobalShortcutSection({
    super.key,
    required this.slot,
    this.bare = false,
  });

  final GlobalShortcutSlot slot;

  /// Devolve só as linhas, sem o cartão em volta.
  final bool bare;

  @override
  ConsumerState<GlobalShortcutSection> createState() =>
      _GlobalShortcutSectionState();
}

class _GlobalShortcutSectionState extends ConsumerState<GlobalShortcutSection> {
  /// Guardada no [initState], e não lida a cada uso.
  ///
  /// O `dispose` precisa dela — é ele que devolve os atalhos ao sistema quando
  /// a tela sai no meio de uma gravação — e o Riverpod recusa `ref` em widget
  /// que está sendo desmontado, porque `ref` depende do `BuildContext`.
  late final ModuleSettingsViewModel _model;

  bool _isRecording = false;

  /// O motivo da última recusa, enquanto a gravação continua.
  String? _refusal;

  @override
  void initState() {
    super.initState();
    _model = ref.read(moduleSettingsViewModelProvider.notifier);
  }

  Future<void> _start() async {
    // Os atalhos saem do sistema **antes** de a tela dizer que está à escuta: o
    // Hub é um aplicativo comum e um atalho global dispara com ele na frente,
    // então gravar `⌘⇧C` sem suspender abriria o painel do Pin por cima desta
    // tela.
    await _model.setRecording(recording: true);

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

    await _model.setRecording(recording: false);
  }

  Future<void> _record(ShortcutBinding binding) async {
    final refusal = await _model.record(widget.slot, binding);

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

  /// Trocar de módulo (ou fechar o Hub) no meio de uma gravação devolve os
  /// atalhos ao sistema.
  ///
  /// Sem isto, sair desta tela pelo caminho normal deixaria o Evergreen sem
  /// atalho nenhum. Existe uma segunda rede na janela 0, que desfaz a suspensão
  /// sozinha depois de um minuto — mas ela é para o caso em que este engine
  /// morreu antes de conseguir avisar, não para o caminho comum.
  @override
  void dispose() {
    if (_isRecording) {
      unawaited(_model.setRecording(recording: false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(moduleSettingsViewModelProvider);
    final binding = settings.bindingFor(widget.slot);
    final isCustom = settings.isCustom(widget.slot);

    final rows = <Widget>[
      EgSettingsRow(
        label: widget.slot.openLabel,
        description: _isRecording
            ? 'Aperte a combinação. Esc cancela.'
            : 'Funciona com qualquer aplicativo em foco.',
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
          style: context.eg.text.caption.copyWith(
            color: context.eg.colors.warning,
          ),
        ),
      ],
      if (isCustom)
        EgSettingsRow(
          label: 'Restaurar padrão',
          description: 'Volta para ${widget.slot.fallback.compact}.',
          trailing: EgButton.secondary(
            label: 'Restaurar',
            onPressed: () => _model.restoreDefault(widget.slot),
          ),
        ),
    ];

    if (widget.bare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }

    return EgSettingsCard(title: 'Atalho global', children: rows);
  }
}

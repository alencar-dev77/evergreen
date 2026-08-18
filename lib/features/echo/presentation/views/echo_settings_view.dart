import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/system/global_shortcut_service.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../../models/echo_settings.dart';
import '../../models/echo_capabilities.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../models/transcription_language.dart';
import '../viewmodels/echo_library_view_model.dart';
import '../viewmodels/echo_recorder_view_model.dart';
import '../viewmodels/echo_settings_view_model.dart';
import '../widgets/echo_library.dart';
import '../widgets/echo_permission_row.dart';

/// Tela do Echo dentro do Hub.
class EchoSettingsView extends ConsumerStatefulWidget {
  const EchoSettingsView({super.key});

  @override
  ConsumerState<EchoSettingsView> createState() => _EchoSettingsViewState();
}

class _EchoSettingsViewState extends ConsumerState<EchoSettingsView> {
  late final TextEditingController _instructions;
  final _instructionsFocus = FocusNode(debugLabel: 'echo-instructions');

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(
      text: ref.read(echoSettingsViewModelProvider).summaryInstructions,
    );

    // Sair do campo guarda, por qualquer caminho — a mesma regra do apelido do
    // Pin. Uma tela de preferências que só salva no Enter perde o que a pessoa
    // escreveu quando ela clica em outra coisa.
    _instructionsFocus.addListener(() {
      if (_instructionsFocus.hasFocus) return;
      _save();
    });

    // As reuniões são gravadas no engine da janela flutuante; este é o do Hub,
    // que só descobre o que existe indo ao banco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(echoLibraryViewModelProvider.notifier).load());
      // As permissões podem ter mudado nos Ajustes desde a última vez.
      unawaited(ref.read(echoRecorderViewModelProvider.notifier).prepareForOpen());
    });
  }

  @override
  void dispose() {
    _instructions.dispose();
    _instructionsFocus.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(echoSettingsViewModelProvider.notifier)
      .setSummaryInstructions(_instructions.text);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(echoSettingsViewModelProvider);
    final viewModel = ref.read(echoSettingsViewModelProvider.notifier);
    final summaries = ref.watch(
      echoLibraryViewModelProvider.select((state) => state.summaries),
    );

    final capabilities = ref.watch(
      echoRecorderViewModelProvider.select((state) => state.capabilities),
    );
    final recorder = ref.read(echoRecorderViewModelProvider.notifier);

    final library = ref.watch(echoLibraryViewModelProvider);
    final libraryViewModel = ref.read(echoLibraryViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgSettingsSection(
          title: 'Reuniões',
          children: [
            EchoLibrary(
              state: library,
              onOpen: (id) {
                libraryViewModel.select(id);
                // Escolher e abrir são o mesmo gesto: quem clica numa reunião
                // quer lê-la, e a região ao lado é onde ela se lê.
                ref.read(hubDetailProvider.notifier).open(EvergreenModule.echo);
              },
              onToggleKept: libraryViewModel.toggleKept,
            ),
            if (library.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  library.errorMessage!,
                  style: AppTypography.captionSmall,
                ),
              ),
          ],
        ),
        EgSettingsSection(
          title: 'Permissões',
          children: [
            EchoPermissionRow(
              title: 'Microfone',
              detail: 'Grava a sua voz.',
              status: capabilities.microphone,
              onPressed: recorder.requestMicrophone,
            ),
            const SizedBox(height: AppSpacing.lg),
            EchoPermissionRow(
              title: 'Gravação de Tela',
              detail:
                  'Dá acesso ao áudio da reunião — a fala das outras pessoas. '
                  'O Echo não grava imagem nenhuma; é só por aqui que o macOS '
                  'entrega o som que sai do computador.',
              status: capabilities.screenRecording,
              onPressed: recorder.requestScreenRecording,
            ),
            if (capabilities.screenRecording == PermissionStatus.denied)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'Depois de ligar a Gravação de Tela nos Ajustes, encerre e '
                  'abra o Evergreen de novo — o macOS só libera a captura para '
                  'um app que iniciou depois da permissão.',
                  style: AppTypography.captionSmall,
                ),
              ),
            if (capabilities.canRecord)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'Tudo liberado. Com fone de ouvido a separação fica melhor: '
                  'no alto-falante, o microfone escuta a reunião de volta e o '
                  'Echo precisa filtrar o eco para saber quem falou.',
                  style: AppTypography.captionSmall,
                ),
              ),
          ],
        ),
        EgSettingsSection(
          title: 'Gravação',
          children: [
            EgSettingsRow(
              label: 'Idioma da transcrição',
              description:
                  'Transcrição no idioma errado não sai pior, sai inútil. O '
                  'modelo do idioma é baixado uma vez, na troca.',
              trailing: EgSegmentedControl<TranscriptionLanguage>(
                value: settings.language,
                options: TranscriptionLanguage.values,
                labelOf: (option) => option.shortLabel,
                onChanged: viewModel.setLanguage,
              ),
            ),
            EgSettingsRow.toggle(
              label: 'Transcrever ao vivo',
              description:
                  'O texto aparece enquanto a reunião acontece. Custa '
                  'processador — em Mac com pouca memória, pode fazer a '
                  'chamada engasgar. O áudio é gravado dos dois jeitos, então '
                  'a transcrição final sai igual.',
              value: settings.liveTranscription,
              onChanged: viewModel.setLiveTranscription,
              showDivider: false,
            ),
          ],
        ),
        EgSettingsSection(
          title: 'Resumo',
          children: [
            // O campo desce para baixo do rótulo em vez de ficar na coluna da
            // direita, onde todas as outras preferências põem o seu controle.
            // A regra que decide é o tamanho da resposta: um seletor cabe ao
            // lado do rótulo, um texto de três linhas não — espremido em 260px
            // ele mostraria meia frase por vez e faria a pessoa escrever numa
            // fresta.
            EgSettingsRow(
              label: 'Como você quer o resumo',
              description:
                  'Vale para todas as reuniões, e é aplicada quando você '
                  'aperta Resumir. Curta e direta funciona melhor: o modelo é '
                  'local e pequeno, e ignora instrução longa demais.',
              showDivider: false,
              trailing: const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: EgTextField(
                controller: _instructions,
                focusNode: _instructionsFocus,
                hintText: EchoSettings.defaultInstructionsHint,
                minLines: 3,
                maxLines: 6,
                // Sem `onSubmitted`: com várias linhas o Enter quebra a linha,
                // que é o que se espera de um campo desse tamanho. Quem guarda
                // é sair do campo — a mesma regra do apelido do Pin.
              ),
            ),
            if (summaries.explanation != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  summaries.explanation!,
                  style: AppTypography.captionSmall,
                ),
              ),
          ],
        ),
        EgSettingsSection(
          title: 'Histórico',
          children: [
            EgSettingsRow(
              label: 'Reuniões guardadas',
              description:
                  'Passando disso, a mais antiga sai para a nova entrar. '
                  'Reunião marcada com "guardar" não entra nessa conta.',
              showDivider: false,
              trailing: EgSegmentedControl<int>(
                value: settings.historyLimit,
                options: EchoSettings.historyLimitOptions,
                labelOf: (option) => '$option',
                onChanged: viewModel.setHistoryLimit,
              ),
            ),
          ],
        ),
        const EgSettingsSection(
          title: 'Atalho global',
          children: [
            EgSettingsRow(
              label: 'Abrir Echo',
              description: 'Funciona com qualquer aplicativo em foco.',
              showDivider: false,
              trailing: EgShortcutDisplay(
                keys: GlobalShortcutService.echoShortcutKeys,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

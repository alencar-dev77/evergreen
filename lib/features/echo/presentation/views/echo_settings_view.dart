import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
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
import '../../../../core/design/eg_tokens.dart';

/// Tela do Echo dentro do Hub.
class EchoSettingsView extends ConsumerStatefulWidget {
  const EchoSettingsView({super.key, this.tab});

  /// A aba aberta. `null` mostra tudo — o caminho de quem monta esta tela fora
  /// do Hub.
  final String? tab;

  @override
  ConsumerState<EchoSettingsView> createState() => _EchoSettingsViewState();
}

class _EchoSettingsViewState extends ConsumerState<EchoSettingsView> {
  late final TextEditingController _instructions;
  final _instructionsFocus = FocusNode(debugLabel: 'echo-instructions');

  late final TextEditingController _vocabulary;
  final _vocabularyFocus = FocusNode(debugLabel: 'echo-vocabulary');

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(
      text: ref.read(echoSettingsViewModelProvider).summaryInstructions,
    );
    _vocabulary = TextEditingController(
      text: ref.read(echoSettingsViewModelProvider).vocabulary,
    );

    _vocabularyFocus.addListener(() {
      if (_vocabularyFocus.hasFocus) return;
      _saveVocabulary();
    });

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
      unawaited(
        ref.read(echoRecorderViewModelProvider.notifier).prepareForOpen(),
      );
    });
  }

  @override
  void dispose() {
    _instructions.dispose();
    _instructionsFocus.dispose();
    _vocabulary.dispose();
    _vocabularyFocus.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(echoSettingsViewModelProvider.notifier)
      .setSummaryInstructions(_instructions.text);

  void _saveVocabulary() => ref
      .read(echoSettingsViewModelProvider.notifier)
      .setVocabulary(_vocabulary.text);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(echoSettingsViewModelProvider);
    final viewModel = ref.read(echoSettingsViewModelProvider.notifier);
    final summaries = ref.watch(
      echoLibraryViewModelProvider.select((state) => state.summaries),
    );

    // Vazio é "não deu para perguntar", não "nenhum idioma existe" — nesse
    // caso a tela cala a boca em vez de acusar falta de um modelo que talvez
    // esteja lá.
    final resolvedLocales =
        ref.watch(echoSupportedLocalesProvider).value ??
        const <String, String>{};
    final resolvedLanguage = resolvedLocales[settings.language.locale];
    final unsupportedLanguage =
        resolvedLocales.isNotEmpty && resolvedLanguage == null;
    // O sistema atende a variante pedida com o modelo de outra. Funciona, e
    // ainda assim precisa ser dito: senão a pessoa passa meses achando que
    // transcreve em PT-PT e culpando o app pelo sotaque errado.
    final substitutedLanguage =
        resolvedLanguage != null && resolvedLanguage != settings.language.locale
        ? resolvedLanguage
        : null;

    final capabilities = ref.watch(
      echoRecorderViewModelProvider.select((state) => state.capabilities),
    );
    final recorder = ref.read(echoRecorderViewModelProvider.notifier);

    final library = ref.watch(echoLibraryViewModelProvider);
    final libraryViewModel = ref.read(echoLibraryViewModelProvider.notifier);

    final tab = widget.tab;
    // O que já foi gravado, e o que a próxima gravação vai fazer. A lista vem
    // primeiro porque é o que se vem buscar: trocar o idioma da transcrição
    // acontece uma vez, reler a reunião de ontem acontece toda semana.
    final showLibrary = tab == null || tab == 'Reuniões';
    final showSettings = tab == null || tab == 'Ajustes';

    return EgSettingsPage(
      children: [
        if (showLibrary)
          EgSettingsCard(
            title: 'Reuniões',
            children: [
              EchoLibrary(
                state: library,
                onOpen: (id) {
                  libraryViewModel.select(id);
                  // Escolher e abrir são o mesmo gesto: quem clica numa reunião
                  // quer lê-la, e a região ao lado é onde ela se lê.
                  ref
                      .read(hubDetailProvider.notifier)
                      .open(EvergreenModule.echo);
                },
                onToggleKept: libraryViewModel.toggleKept,
              ),
              if (library.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    library.errorMessage!,
                    style: context.eg.text.caption,
                  ),
                ),
            ],
          ),
        if (showSettings) ...[
          // O limite da biblioteca é ajuste, e por isso mora com os ajustes:
          // na aba das reuniões ele era a última linha de uma lista, com a
          // mesma cara de mais uma reunião.
          EgSettingsCard(
            title: 'Biblioteca',
            children: [
              EgSettingsRow(
                label: 'Reuniões guardadas',
                description:
                    'A mais antiga sai para a nova entrar. Reunião marcada '
                    'com "guardar" não conta.',
                trailing: EgSegmentedControl<int>(
                  value: settings.historyLimit,
                  options: EchoSettings.historyLimitOptions,
                  labelOf: (option) => '$option',
                  onChanged: viewModel.setHistoryLimit,
                ),
              ),
            ],
          ),
          EgSettingsCard(
            title: 'Gravação',
            children: [
              // O interruptor primeiro: é a única pergunta do tópico que se
              // responde com sim ou não, e ela diz o que o módulo vai fazer
              // enquanto grava. Os ajustes de como vêm depois.
              EgSettingsRow.toggle(
                label: 'Transcrever ao vivo',
                description:
                    'O texto aparece durante a reunião. Custa processador e '
                    'pode engasgar a chamada. A final sai igual dos dois '
                    'jeitos.',
                value: settings.liveTranscription,
                onChanged: viewModel.setLiveTranscription,
              ),
              EgSettingsRow(
                label: 'Idioma da transcrição',
                description:
                    'No idioma errado, a transcrição não sai pior: sai '
                    'inútil. O modelo é baixado uma vez, na troca.',
                trailing: EgSegmentedControl<TranscriptionLanguage>(
                  value: settings.language,
                  options: TranscriptionLanguage.values,
                  labelOf: (option) => option.shortLabel,
                  onChanged: viewModel.setLanguage,
                ),
              ),
              // Em cor de aviso, e não no cinza das outras legendas desta tela:
              // as demais são ressalvas ("com fone fica melhor"), esta é um
              // impedimento — com ela na tela, a gravação recusa começar.
              if (unsupportedLanguage)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Este Mac não tem modelo para '
                    '${settings.language.label}. Assim, a gravação sairia em '
                    'palavras trocadas.',
                    style: context.eg.text.caption.copyWith(
                      color: context.eg.colors.warning,
                    ),
                  ),
                ),
              if (substitutedLanguage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'O macOS atende ${settings.language.label} com o modelo '
                    'de $substitutedLanguage.',
                    style: context.eg.text.caption,
                  ),
                ),
              // Último do tópico, encostado no campo de instrução do resumo, que
              // abre o tópico seguinte: os dois campos de escrever desta tela
              // ficam um debaixo do outro, e não um em cada ponta dela.
              EgSettingsRow.field(
                label: 'Palavras que costumam aparecer',
                description:
                    'Nomes, produtos, jargão, separados por vírgula. É o '
                    'que o reconhecimento mais erra.',
                field: EgTextField(
                  controller: _vocabulary,
                  focusNode: _vocabularyFocus,
                  hintText: EchoSettings.vocabularyHint,
                  minLines: 2,
                  maxLines: 5,
                ),
              ),
            ],
          ),
          EgSettingsCard(
            title: 'Resumo',
            children: [
              EgSettingsRow.field(
                label: 'Como você quer o resumo',
                description:
                    'Vale para todas as reuniões, ao apertar Resumir. Curta '
                    'funciona melhor: o modelo é local e ignora instrução '
                    'longa.',
                field: EgTextField(
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
                    style: context.eg.text.caption,
                  ),
                ),
            ],
          ),
          const GlobalShortcutSection(slot: GlobalShortcutSlot.echo),
          // No fim da tela, e não no começo: a liberação é coisa de uma vez só —
          // dois botões que se apertam no primeiro dia e nunca mais. Em cima,
          // eles empurravam para baixo tudo o que se ajusta no dia a dia, e a
          // tela abria pedindo permissão em vez de mostrar as reuniões.
          EgSettingsCard(
            title: 'Permissões',
            children: [
              EchoPermissionRow(
                title: 'Microfone',
                detail: 'Grava a sua voz.',
                status: capabilities.microphone,
                onPressed: recorder.requestMicrophone,
              ),
              EchoPermissionRow(
                title: 'Gravação de Tela',
                detail:
                    'Dá acesso à fala das outras pessoas. O Echo não grava '
                    'imagem: é só por aqui que o macOS entrega o som.',
                status: capabilities.screenRecording,
                onPressed: recorder.requestScreenRecording,
              ),
              if (capabilities.screenRecording == PermissionStatus.denied)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'Depois de liberar nos Ajustes, encerre e abra o '
                    'Evergreen: o macOS só entrega a captura a quem iniciou '
                    'depois.',
                    style: context.eg.text.caption,
                  ),
                ),
              if (capabilities.canRecord)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'Tudo liberado. Com fone a separação fica melhor: no '
                    'alto-falante, o Echo tem de filtrar o eco.',
                    style: context.eg.text.caption,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

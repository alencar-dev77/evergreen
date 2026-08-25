import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/hub_window_channel.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../awake/presentation/views/awake_settings_view.dart';
import '../../../echo/presentation/views/echo_settings_view.dart';
import '../../../echo/presentation/widgets/echo_reader.dart';
import '../../../focus/presentation/views/focus_settings_view.dart';
import '../../../focus/presentation/widgets/focus_reader.dart';
import '../../../leaf/presentation/views/leaf_settings_view.dart';
import '../../../pin/presentation/views/pin_settings_view.dart';
import '../../../trail/presentation/views/trail_view.dart';
import '../../../trail/presentation/widgets/trail_reader.dart';
import '../../models/evergreen_module.dart';
import '../viewmodels/hub_detail_view_model.dart';
import '../widgets/hub_detail_region.dart';
import '../widgets/module_placeholder.dart';
import '../widgets/module_sidebar.dart';
import 'app_settings_view.dart';

/// Painel principal do Evergreen.
///
/// Lista os módulos da suíte à esquerda e mostra as configurações do módulo
/// selecionado à direita. É uma janela independente do overlay do Pin: fechar
/// uma não afeta a outra.
///
/// Um módulo pode abrir uma **terceira região**, dedicada ao item que se está
/// lendo (o Echo, com a reunião; o Focus, com a sessão do histórico). Quando
/// isso acontece a janela cresce em torno do próprio centro, em vez de dividir
/// o que já existe — ver [HubDetailRegion]. É por aqui que qualquer módulo
/// mostra conteúdo longo: no Evergreen não se abre janela nova nem diálogo
/// modal para ler.
class HubView extends ConsumerStatefulWidget {
  const HubView({super.key});

  @override
  ConsumerState<HubView> createState() => _HubViewState();
}

class _HubViewState extends ConsumerState<HubView> {
  /// Módulo aberto, ou `null` para a tela do próprio aplicativo.
  EvergreenModule? _selected = EvergreenModule.pin;

  void _select(EvergreenModule? module) {
    // Trocar de módulo fecha a região: uma reunião aberta ao lado das
    // preferências do Pin seria a leitura de um módulo dentro de outro.
    ref.read(hubDetailProvider.notifier).close();
    setState(() => _selected = module);
  }

  /// O Esc do Hub, do mais interno para o mais externo: sai do campo de texto,
  /// fecha a região de leitura e, sem nada disso aberto, esconde a janela.
  ///
  /// Esconder a janela é o degrau final porque o Hub é chamado por atalho e
  /// dispensado como qualquer painel do Evergreen — sair dele pelo teclado não
  /// pode exigir o mouse na bolinha vermelha.
  ///
  /// Sair do campo antes de tudo tem a mesma razão do apelido do Pin: a tecla
  /// que cancela uma edição não pode levar a janela junto. E sair do campo é o
  /// que **guarda** o que foi escrito, porque toda preferência do Evergreen se
  /// grava ao perder o foco.
  void _handleEscape() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null &&
        focus.context?.findAncestorStateOfType<EditableTextState>() != null) {
      focus.unfocus();
      return;
    }

    if (ref.read(hubDetailProvider) != null) {
      ref.read(hubDetailProvider.notifier).close();
      return;
    }

    unawaited(HubWindow.hideSelf());
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(hubDetailProvider);
    // A janela acompanha a região: cresce ao abrir, volta ao fechar. Fora do
    // `build` (num `listen`) porque isto é efeito, não desenho.
    ref.listen<EvergreenModule?>(hubDetailProvider, (previous, next) {
      HubWindowChannel.setDetailWidth(
        next == null ? 0 : HubDetailRegion.preferredWidth,
      );
    });

    final isDetailOpen = detail != null && detail == _selected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        },
        // O escopo é o chão do teclado do Hub: no macOS o campo de texto de uma
        // tela de preferências larga o foco a cada clique fora dele, e sem um
        // escopo aqui esse foco cai na rota — acima do `CallbackShortcuts`, de
        // onde nenhuma tecla volta a descer. Era o que deixava o Hub sem Esc
        // depois de um clique num campo, e é a mesma falha do painel flutuante
        // (ver `EgOverlayShell`).
        child: FocusScope(
          child: Focus(
            autofocus: true,
            child: EgBackground(
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  // Estica: a área de detalhe rola, e um `SingleChildScrollView`
                  // se encolhe até a altura do conteúdo quando ele cabe na tela.
                  // Com o alinhamento padrão do `Row` (center), a tela de um
                  // módulo curto — o Awake — nascia centralizada verticalmente,
                  // enquanto Pin e Focus, que enchem a janela, começavam no topo.
                  // Toda tela do Hub começa no mesmo lugar.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ModuleSidebar(selected: _selected, onSelect: _select),
                    Expanded(child: _detail()),
                    if (isDetailOpen)
                      _region(detail, _regionWidth(constraints.maxWidth)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Piso da área de conteúdo.
  ///
  /// Abaixo disto as linhas de configuração estouram: um `EgSettingsRow` tem
  /// rótulo que quebra linha e um controle de largura fixa ao lado, e o
  /// controle não encolhe. É o número que manda na conta da região.
  static const _contentFloor = 560.0;

  /// Quanto a região pode ocupar sem espremer o conteúdo.
  ///
  /// A janela cresce para caber a região, mas a resposta do lado nativo é
  /// **animada** (220ms) e pode ser limitada pela tela: durante esses quadros —
  /// e para sempre, num monitor pequeno — a janela é mais estreita do que a
  /// região gostaria. Quem cede é a região, nunca o conteúdo: uma região
  /// estreita só fica estreita, enquanto uma tela de preferências espremida
  /// estoura o layout.
  ///
  /// O efeito colateral é bem-vindo: com a largura seguindo o que existe, a
  /// região *abre deslizando* junto com a janela em vez de aparecer inteira
  /// sobre um conteúdo espremido.
  double _regionWidth(double available) {
    final free = available - ModuleSidebar.width - _contentFloor;
    return free.clamp(0.0, HubDetailRegion.preferredWidth);
  }

  /// A região dedicada do módulo que a abriu.
  Widget _region(EvergreenModule module, double width) => switch (module) {
        EvergreenModule.echo => EchoReader(width: width),
        EvergreenModule.focus => FocusReader(width: width),
        EvergreenModule.trail => TrailReader(width: width),
        // Os outros módulos ainda não têm nada longo para ler; o `switch`
        // existe para que o próximo entre aqui, e não num `if` espalhado pela
        // tela.
        _ => const SizedBox.shrink(),
      };

  Widget _detail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.huge,
        AppSpacing.huge,
        AppSpacing.huge,
        AppSpacing.giant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.xxxl),
          _content(),
        ],
      ),
    );
  }

  /// Cabeçalho de painel, não hero: título no maior estilo do app (17px) com a
  /// tagline logo abaixo, colada nele — os dois são um bloco só.
  Widget _header() {
    final module = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          module?.name ?? 'Evergreen',
          style: AppTypography.screenTitle,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          module?.tagline ?? 'Preferências do aplicativo',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _content() {
    final module = _selected;
    if (module == null) return const AppSettingsView();

    return module.isAvailable
        ? _settingsFor(module)
        : ModulePlaceholder(module: module);
  }

  Widget _settingsFor(EvergreenModule module) => switch (module) {
        EvergreenModule.pin => const PinSettingsView(),
        EvergreenModule.focus => const FocusSettingsView(),
        EvergreenModule.leaf => const LeafSettingsView(),
        EvergreenModule.awake => const AwakeSettingsView(),
        EvergreenModule.echo => const EchoSettingsView(),
        EvergreenModule.trail => const TrailView(),
      };
}

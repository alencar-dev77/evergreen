import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/hub_window_channel.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../awake/presentation/views/awake_settings_view.dart';
import '../../../echo/presentation/views/echo_settings_view.dart';
import '../../../echo/presentation/viewmodels/echo_playback_view_model.dart';
import '../../../echo/presentation/viewmodels/echo_rename_request.dart';
import '../../../echo/presentation/viewmodels/echo_search_focus.dart';
import '../../../echo/presentation/widgets/echo_reader.dart';
import '../../../focus/presentation/views/focus_settings_view.dart';
import '../../../focus/presentation/widgets/focus_reader.dart';
import '../../../leaf/presentation/views/leaf_settings_view.dart';
import '../../../nest/presentation/views/nest_settings_view.dart';
import '../../../pin/presentation/views/pin_settings_view.dart';
import '../../../track/presentation/views/track_view.dart';
import '../../../track/presentation/widgets/track_reader.dart';
import '../../../../core/window/hub_destination.dart';
import '../../models/evergreen_module.dart';
import '../viewmodels/hub_detail_view_model.dart';
import '../viewmodels/app_settings_view_model.dart';
import '../viewmodels/hub_intro_view_model.dart';
import '../viewmodels/module_settings_view_model.dart';
import '../viewmodels/onboarding_view_model.dart';
import '../widgets/hub_detail_region.dart';
import '../widgets/hub_intro.dart';
import '../widgets/hub_onboarding.dart';
import '../widgets/module_placeholder.dart';
import '../widgets/module_sidebar.dart';
import '../widgets/module_switch.dart';
import '../widgets/uninstall_section.dart';
import '../../../../core/app_info.dart';
import '../../../../shared/widgets/eg_pill.dart';
import '../../../../shared/widgets/eg_screen_header.dart';
import 'app_settings_view.dart';
import '../../../../core/design/eg_tokens.dart';

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

  /// A aba aberta de cada módulo, guardada por módulo.
  ///
  /// Por módulo, e não uma só para o Hub: quem estava no histórico do Focus,
  /// foi ver um ajuste do Pin e voltou, quer o histórico de novo. Uma aba
  /// única faria cada ida ao vizinho apagar onde a pessoa estava.
  ///
  /// No estado da tela, e não numa preferência: onde se estava é memória da
  /// sessão, não uma escolha a guardar no disco — reabrir o Hub amanhã na aba
  /// "Gerador" seria o app lembrando de algo que ninguém pediu para lembrar.
  final Map<EvergreenModule, String> _tabs = {};

  @override
  void initState() {
    super.initState();

    // Quem abriu o Hub pode ter pedido um lugar dentro dele. O aviso pelo canal
    // é para quando ele já estava de pé; esta leitura é para quando ele acabou
    // de nascer, que é o caso de quem fecha uma reunião e vai ver a gravação.
    unawaited(HubDestination.listen(_goToRequested));
    unawaited(_goToRequested());
  }

  /// O que acontece quando a abertura animada termina.
  ///
  /// Além de carimbar a build, ela decide onde o Hub cai: no Pin, como sempre,
  /// ou na tela do aplicativo, quando ainda não se sabe o nome de quem está do
  /// outro lado. A pergunta do nome mora lá, no topo, com o cursor dentro.
  ///
  /// Amarrada à cena, e não à abertura da janela: a cena roda **uma vez por
  /// instalação**, então a pergunta aparece uma vez e nunca mais — mesmo de
  /// quem deixar o campo em branco. Uma pergunta que reabre a cada Hub deixa de
  /// ser pergunta e vira cobrança. E é o lugar certo também pelo tempo: ela
  /// chega logo depois da marca, como a primeira coisa que o app diz.
  void _introDone() {
    ref.read(hubIntroViewModelProvider.notifier).complete();

    if (ref.read(appSettingsViewModelProvider).userName.isNotEmpty) return;
    setState(() => _selected = null);
  }

  /// Vai para onde quem abriu o Hub pediu — se alguém pediu.
  ///
  /// Roda ao nascer (o Hub estava fechado) e a cada aviso pelo canal (o Hub
  /// estava aberto, escondido atrás de tudo). Ver [HubDestination].
  Future<void> _goToRequested() async {
    final moduleId = await HubDestination.take();
    if (moduleId == null || !mounted) return;

    if (moduleId == HubDestination.uninstall) {
      _select(null);
      // Depois do quadro: a pergunta abre por cima da tela do aplicativo, e
      // não da tela em que o Hub estava antes de trocar. Pergunta repetida é
      // barrada dentro do `confirmUninstall`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(confirmUninstall(context, ref));
      });
      return;
    }

    final module = EvergreenModule.values
        .where((candidate) => candidate.id == moduleId)
        .firstOrNull;
    if (module == null) return;

    _select(module);
  }

  void _select(EvergreenModule? module) {
    // Trocar de módulo fecha a região: uma reunião aberta ao lado das
    // preferências do Pin seria a leitura de um módulo dentro de outro.
    ref.read(hubDetailProvider.notifier).close();
    setState(() => _selected = module);
  }

  /// `⌘F` no Echo: leva o teclado à busca das reuniões, de qualquer aba.
  ///
  /// Da aba de ajustes, troca para a das reuniões antes — e o pedido de foco
  /// vai depois do quadro, quando o campo já nasceu e está escutando.
  ///
  /// O campo que estava sendo editado sai do foco **antes** de a aba trocar:
  /// trocada a aba, ele sai da árvore com o foco na mão, e o "perder o foco"
  /// que guarda a preferência nunca aconteceria — o vocabulário digitado
  /// sumiria sem aviso.
  void _focusEchoSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tabs[EvergreenModule.echo] = 'Reuniões');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(echoSearchFocusProvider.notifier).request();
    });
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
    // A janela acompanha a região: cresce ao abrir, volta ao fechar. Fora do
    // `build` (num `listen`) porque isto é efeito, não desenho.
    ref.listen<EvergreenModule?>(hubDetailProvider, (previous, next) {
      HubWindowChannel.setDetailWidth(
        next == null ? 0 : HubDetailRegion.preferredWidth,
      );
    });

    return Scaffold(
      backgroundColor: context.eg.colors.canvas,
      // A abertura fica por cima, e não no lugar do Hub: a tela de baixo monta
      // e resolve o que tem para resolver enquanto a marca está na frente, de
      // modo que a cena não some para revelar um Hub ainda em branco.
      body: Stack(
        fit: StackFit.expand,
        children: [
          _hub(),
          // A apresentação vem antes da abertura animada na pilha porque a
          // abertura é quem cobre tudo: a marca entra, a marca sai, e o que
          // estava embaixo dela é a primeira coisa que a pessoa vê.
          if (ref.watch(onboardingViewModelProvider).visible) _onboarding(),
          if (ref.watch(hubIntroViewModelProvider))
            HubIntro(onDone: _introDone),
        ],
      ),
    );
  }

  /// A apresentação de boas-vindas, com o teclado dela.
  ///
  /// Os atalhos ficam aqui, e não dentro do `HubOnboarding`: enquanto ela está
  /// na tela, o Esc não pode chegar ao `_handleEscape` do Hub — ali ele
  /// esconderia a janela, e sair pela janela em vez de pela apresentação
  /// deixaria a preferência por gravar e a apresentação voltaria na próxima
  /// abertura.
  Widget _onboarding() {
    final state = ref.watch(onboardingViewModelProvider);
    final model = ref.read(onboardingViewModelProvider.notifier);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): model.next,
        const SingleActivator(LogicalKeyboardKey.arrowRight): model.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): model.previous,
        const SingleActivator(LogicalKeyboardKey.escape): model.finish,
      },
      child: FocusScope(
        child: Focus(
          autofocus: true,
          child: HubOnboarding(
            step: state.step,
            index: state.index,
            total: state.total,
            onNext: model.next,
            onPrevious: model.previous,
            onSkip: model.finish,
          ),
        ),
      ),
    );
  }

  Widget _hub() {
    final detail = ref.watch(hubDetailProvider);
    final isDetailOpen = detail != null && detail == _selected;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        // Só com o Echo ligado: desligado, a tela dele não recebe foco, e o
        // atalho trocaria de aba sem levar o cursor a lugar nenhum.
        if (_selected == EvergreenModule.echo &&
            ref
                .watch(moduleSettingsViewModelProvider)
                .isEnabled(EvergreenModule.echo))
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              _focusEchoSearch,
        // Com uma reunião aberta: o nome dela vira campo. O mesmo `⌘R` do
        // apelido do Pin.
        if (isDetailOpen && detail == EvergreenModule.echo)
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
              ref.read(echoRenameRequestProvider.notifier).request(),
      },
      // As teclas da região num mapa à parte, porque elas **cedem a quem
      // digita**: espaço e letra são texto. Um `CallbackShortcuts` consome
      // tudo o que casa, e consumir no macOS impede a tecla de virar
      // caractere — com uma reunião aberta, o espaço tocava o áudio em vez
      // de entrar no campo de vocabulário ou na instrução do resumo.
      child: Shortcuts(
        shortcuts: {
          if (isDetailOpen)
            for (final MapEntry(:key, :value) in _regionBindings(
              detail,
            ).entries)
              key: _RegionKeyIntent(value),
        },
        child: Actions(
          actions: {_RegionKeyIntent: _RegionKeyAction()},
          // O escopo é o chão do teclado do Hub: no macOS o campo de texto de
          // uma tela de preferências larga o foco a cada clique fora dele, e
          // sem um escopo aqui esse foco cai na rota — acima do
          // `CallbackShortcuts`, de onde nenhuma tecla volta a descer. Era o
          // que deixava o Hub sem Esc depois de um clique num campo, e é a
          // mesma falha do painel flutuante (ver `EgOverlayShell`).
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

  /// As teclas da região aberta, quando ela tem alguma.
  ///
  /// No mapa do Hub, e não num `Shortcuts` dentro da região: o foco do Hub
  /// mora acima dela, e um mapa lá dentro nunca seria consultado. Um campo de
  /// texto com o foco continua recebendo o espaço e as setas — o mapa de
  /// edição dele para a tecla antes de ela subir até aqui.
  Map<ShortcutActivator, VoidCallback> _regionBindings(EvergreenModule module) {
    if (module != EvergreenModule.echo) return const {};
    if (!ref.watch(echoPlaybackViewModelProvider).isReady) return const {};

    final player = ref.read(echoPlaybackViewModelProvider.notifier);
    const skip = EchoPlaybackViewModel.skip;

    return {
      const SingleActivator(LogicalKeyboardKey.space): () =>
          unawaited(player.toggle()),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          unawaited(player.skipBy(-skip)),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          unawaited(player.skipBy(skip)),
      const SingleActivator(LogicalKeyboardKey.keyS): () =>
          unawaited(player.cycleRate()),
    };
  }

  /// A região dedicada do módulo que a abriu.
  Widget _region(EvergreenModule module, double width) => switch (module) {
    EvergreenModule.echo => EchoReader(width: width),
    EvergreenModule.focus => FocusReader(width: width),
    EvergreenModule.track => TrackReader(width: width),
    // Os outros módulos ainda não têm nada longo para ler; o `switch`
    // existe para que o próximo entre aqui, e não num `if` espalhado pela
    // tela.
    _ => const SizedBox.shrink(),
  };

  /// O cabeçalho fica **fora** do scroll, e o conteúdo rola por baixo dele.
  ///
  /// É o que faz o nome do módulo e o interruptor mestre continuarem à vista
  /// numa tela longa: sem isso, rolar até o fim das preferências do Echo tira
  /// da tela a única coisa que diz de qual módulo elas são.
  Widget _detail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.huge - AppSpacing.xxs,
              AppSpacing.xxl,
              AppSpacing.huge - AppSpacing.xxs,
              AppSpacing.giant,
            ),
            child: _content(),
          ),
        ),
      ],
    );
  }

  /// O cabeçalho da tela: o nome do módulo no maior tipo do app e o
  /// interruptor mestre como pílula.
  ///
  /// A tecla que abre o painel **não fica aqui**. Ela é dita na barra lateral,
  /// que é o mapa do teclado, e trocada na seção "Atalho global" da própria
  /// tela — impressa também no topo, ela era a terceira das quatro cópias que
  /// a tela do Leaf mostrava de uma vez.
  ///
  /// O interruptor **saiu da lista de seções**. Ele é igual nos sete módulos e
  /// não é um ajuste como os outros — é a chave que decide se os outros valem
  /// alguma coisa; como primeira seção, ele empurrava o assunto de cada tela
  /// para baixo da dobra.
  Widget _header() {
    final module = _selected;

    if (module == null) {
      return EgScreenHeader(
        title: 'Aplicativo',
        subtitle: Text(
          'Evergreen ${AppInfo.versionLabel} · '
          '${EvergreenModule.values.length} módulos',
        ),
      );
    }

    final settings = ref.watch(moduleSettingsViewModelProvider);
    final hasSwitch = module != EvergreenModule.track;

    return EgScreenHeader(
      title: module.name,
      subtitle: Text(module.description),
      isEnabled: hasSwitch ? settings.isEnabled(module) : null,
      onEnabledChanged: (value) => ref
          .read(moduleSettingsViewModelProvider.notifier)
          .setEnabled(module, enabled: value),
      // O Track não liga nem desliga: ele se apaga quando os módulos que o
      // alimentam se apagam. No lugar do interruptor, o que ele tem a dizer.
      badge: hasSwitch
          ? null
          : const EgPill(
              label: 'nada é gravado aqui',
              tone: EgPillTone.tide,
              showDot: false,
            ),
      tabs: _tabsFor(module),
      selectedTab: _tabOf(module),
      onTabSelected: (tab) => setState(() => _tabs[module] = tab),
    );
  }

  Widget _content() {
    final module = _selected;
    if (module == null) return const AppSettingsView();
    if (!module.isAvailable) return ModulePlaceholder(module: module);

    final isEnabled = ref
        .watch(moduleSettingsViewModelProvider)
        .isEnabled(module);

    // O interruptor mestre não está mais aqui: ele vive no cabeçalho, fora do
    // scroll. O que fica é o portão, que apaga a tela do módulo desligado sem
    // que ela precise saber disso.
    return ModuleGate(enabled: isEnabled, child: _settingsFor(module));
  }

  /// As abas de cada módulo, e a ordem delas.
  ///
  /// **Vazio quer dizer "sem abas", e é o caso de quem tem um assunto só.**
  /// Uma aba sozinha é a promessa de que existe outra: ela ocupa a linha, pede
  /// um clique que não leva a lugar nenhum e ensina que ali há mais do que há.
  ///
  /// **"Ajustes" é sempre a primeira, e é onde a tela abre.**
  ///
  /// Ela é a única aba que todo módulo tem, e por isso é a única que pode ter
  /// lugar fixo: mudando de posição entre um módulo e o vizinho, o olho teria
  /// de reencontrá-la a cada troca de tela. E é a que se procura — as outras
  /// são conteúdo, em que se cai.
  ///
  /// **Módulo que só tem ajustes mostra a aba mesmo assim.** Sem ela, o Awake
  /// e o Leaf tinham ajustes que não estavam "na aba de ajustes", e o
  /// cabeçalho mudava de altura de um módulo para o outro. A consistência do
  /// topo entre as sete telas vale mais que a regra de não mostrar uma aba
  /// sozinha.
  ///
  /// O custo, dito para não se perder: quem abre o Echo cai nos ajustes, não
  /// na reunião de ontem. Trocar de ideia é reordenar esta lista.
  static List<String> _tabsFor(EvergreenModule module) => switch (module) {
    EvergreenModule.pin => const ['Ajustes', 'Tipos', 'Gerador'],
    EvergreenModule.focus => const ['Ajustes', 'Histórico'],
    EvergreenModule.echo => const ['Ajustes', 'Reuniões'],
    EvergreenModule.nest => const ['Ajustes', 'Destinos'],
    EvergreenModule.leaf => const ['Ajustes'],
    EvergreenModule.awake => const ['Ajustes'],
    // O Track não tem ajuste nenhum: ele é leitura do que os outros gravaram.
    EvergreenModule.track => const [],
  };

  /// A aba aberta do módulo — a primeira, enquanto ninguém tiver escolhido.
  String? _tabOf(EvergreenModule module) {
    final tabs = _tabsFor(module);
    if (tabs.isEmpty) return null;

    final chosen = _tabs[module];
    return chosen != null && tabs.contains(chosen) ? chosen : tabs.first;
  }

  Widget _settingsFor(EvergreenModule module) {
    final tab = _tabOf(module);

    return switch (module) {
      EvergreenModule.pin => PinSettingsView(tab: tab),
      EvergreenModule.focus => FocusSettingsView(tab: tab),
      EvergreenModule.leaf => const LeafSettingsView(),
      EvergreenModule.awake => const AwakeSettingsView(),
      EvergreenModule.echo => EchoSettingsView(tab: tab),
      EvergreenModule.nest => NestSettingsView(tab: tab),
      EvergreenModule.track => const TrackView(),
    };
  }
}

/// Uma tecla da região aberta — o espaço, as setas e o S do player do Echo.
class _RegionKeyIntent extends Intent {
  const _RegionKeyIntent(this.callback);

  final VoidCallback callback;
}

/// Roda a tecla da região, menos quando o foco está num campo de texto.
///
/// Desabilitada, a ação devolve a tecla sem consumi-la, e o campo a recebe
/// como texto. As setas não precisam disto — o campo as trata no mapa de
/// edição dele, abaixo deste —, mas o espaço e as letras chegam ao campo
/// pelo sistema de entrada de texto, que só os entrega se ninguém os
/// consumiu antes.
class _RegionKeyAction extends Action<_RegionKeyIntent> {
  @override
  bool isEnabled(_RegionKeyIntent intent) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return true;

    return focused.findAncestorStateOfType<EditableTextState>() == null;
  }

  @override
  void invoke(_RegionKeyIntent intent) => intent.callback();
}

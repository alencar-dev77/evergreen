import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../features/home/presentation/viewmodels/app_settings_view_model.dart';
import '../core/window/window_kind.dart';
import '../features/home/presentation/views/hub_view.dart';
import 'overlay_host.dart';

/// Raiz de qualquer janela do Evergreen.
///
/// Todas compartilham o mesmo tema e comportamento de scroll — é o que faz o
/// Hub e o overlay parecerem o mesmo aplicativo, apesar de rodarem em engines
/// independentes.
///
/// A aparência é observada, não lida uma vez: trocar de tema nas preferências
/// reconstrói esta raiz, e o `MaterialApp` atravessa do tema antigo para o novo
/// com o cross-fade que ele já sabe fazer. Nenhuma tela precisa saber que isso
/// aconteceu.
class EvergreenApp extends ConsumerWidget {
  const EvergreenApp({super.key, required this.kind});

  final WindowKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(
      appSettingsViewModelProvider.select((settings) => settings.theme),
    );

    return MaterialApp(
      title: 'Evergreen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(theme),
      scrollBehavior: const AppScrollBehavior(),
      home: switch (kind) {
        WindowKind.overlay => const OverlayHost(),
        WindowKind.hub => const HubView(),
      },
    );
  }
}

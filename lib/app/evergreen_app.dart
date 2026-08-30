import 'package:flutter/material.dart';

import '../core/design/app_theme.dart';
import '../core/window/window_kind.dart';
import '../features/home/presentation/views/hub_view.dart';
import 'overlay_host.dart';

/// Raiz de qualquer janela do Evergreen.
///
/// Todas compartilham o mesmo tema e comportamento de scroll — é o que faz o
/// Hub e o overlay parecerem o mesmo aplicativo, apesar de rodarem em engines
/// independentes.
class EvergreenApp extends StatelessWidget {
  const EvergreenApp({super.key, required this.kind});

  final WindowKind kind;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evergreen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      scrollBehavior: const AppScrollBehavior(),
      home: switch (kind) {
        WindowKind.overlay => const OverlayHost(),
        WindowKind.hub => const HubView(),
      },
    );
  }
}

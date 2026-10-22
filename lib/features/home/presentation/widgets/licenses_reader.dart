import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_spinner.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/package_license.dart';
import '../viewmodels/hub_detail_view_model.dart';
import '../viewmodels/licenses_view_model.dart';
import 'hub_detail_region.dart';

/// As licenças, na região de leitura da tela do aplicativo.
///
/// Na região, e não no `showLicensePage` do Flutter: aquela é uma página do
/// Material que tomaria o Hub inteiro, com outra cara e outro jeito de voltar.
/// Texto longo para ler, no Evergreen, abre aqui.
class LicensesReader extends ConsumerWidget {
  const LicensesReader({
    super.key,
    this.width = HubDetailRegion.preferredWidth,
  });

  /// Largura concedida pelo Hub — ver [HubDetailRegion.width].
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenses = ref.watch(licensesProvider);
    final components = licenses.value?.length;

    return HubDetailRegion(
      width: width,
      onClose: () => ref.read(appDetailProvider.notifier).close(),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Licenças', style: context.eg.text.panelTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            components == null
                ? 'O Evergreen é código aberto, sob a GPL-3.0.'
                // Menos um: o primeiro da lista é o próprio Evergreen.
                : 'O Evergreen é código aberto, sob a GPL-3.0, e usa '
                      '${components - 1} componentes de outras pessoas.',
            style: context.eg.text.footnote,
          ),
        ],
      ),
      child: switch (licenses) {
        AsyncData(:final value) => _LicenseList(licenses: value),
        // Não deveria acontecer — as licenças vêm de dentro do próprio app —,
        // mas se acontecer, dizer é melhor que um spinner eterno.
        AsyncError() => Text(
          'Não foi possível ler as licenças.',
          style: context.eg.text.footnote,
        ),
        _ => const Align(alignment: Alignment.topLeft, child: EgSpinner()),
      },
    );
  }
}

class _LicenseList extends ConsumerWidget {
  const _LicenseList({required this.licenses});

  final List<PackageLicense> licenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openLicenseProvider);

    return ListView.builder(
      itemCount: licenses.length,
      itemBuilder: (context, index) {
        final license = licenses[index];

        return _LicenseTile(
          license: license,
          isOpen: license.name == open,
          onTap: () =>
              ref.read(openLicenseProvider.notifier).toggle(license.name),
        );
      },
    );
  }
}

class _LicenseTile extends StatelessWidget {
  const _LicenseTile({
    required this.license,
    required this.isOpen,
    required this.onTap,
  });

  final PackageLicense license;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgInteractiveSurface(
          onTap: onTap,
          isSelected: isOpen,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          semanticLabel: license.name,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  license.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isOpen
                      ? context.eg.text.bodyStrong
                      : context.eg.text.body,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // A seta aponta para baixo quando o texto está aberto embaixo
              // dela, como um item recolhível do Finder.
              RotatedBox(
                quarterTurns: isOpen ? 1 : 0,
                child: const EgIcon(
                  EgIconData.chevronRight,
                  size: AppIconSizes.xs,
                ),
              ),
            ],
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xl,
            ),
            child: Text(
              license.texts.join('\n\n— — —\n\n'),
              style: context.eg.text.monoSmall.copyWith(
                color: context.eg.colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

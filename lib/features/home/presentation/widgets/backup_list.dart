import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/byte_size.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/backup_file.dart';

/// Os backups da pasta, para escolher qual restaurar.
///
/// Uma lista simples e não um seletor de arquivo do sistema: os backups moram
/// todos na mesma pasta, e trazer um de outra máquina é arrastá-lo para lá
/// (o botão "Mostrar no Finder" abre a pasta). A pasta é a interface — o que
/// evita um plugin de seleção de arquivo e o registro dele no callback de
/// sub-janela do Runner, que é onde esse tipo de coisa quebra no Hub.
class BackupList extends StatelessWidget {
  const BackupList({
    super.key,
    required this.backups,
    required this.onSelect,
    this.selectedPath,
    this.now,
  });

  final List<BackupFile> backups;
  final void Function(String path) onSelect;
  final String? selectedPath;

  /// Injetável para o teste não depender do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final backup in backups)
          _BackupRow(
            backup: backup,
            isSelected: backup.path == selectedPath,
            now: now,
            onTap: () => onSelect(backup.path),
          ),
      ],
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({
    required this.backup,
    required this.isSelected,
    required this.onTap,
    this.now,
  });

  final BackupFile backup;
  final bool isSelected;
  final VoidCallback onTap;
  final DateTime? now;

  /// A mesma altura das outras linhas de lista do aplicativo.
  static const _height = 34.0;

  /// Coluna da data. Cabe "Ontem · 14:32".
  static const _dateColumn = 116.0;

  /// Coluna do tamanho, à direita — a que se compara correndo o olho.
  static const _sizeColumn = 64.0;

  /// A coluna do meio: o que este arquivo é, quando isso não está na data.
  ///
  /// Numa rede de restauração o que se procura não é o nome — é saber que
  /// aquela linha é o estado de antes da troca.
  String get _label {
    if (backup.isSafetyCopy) return 'antes de restaurar';

    return backup.isOurs ? '' : backup.name;
  }

  @override
  Widget build(BuildContext context) {
    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isSelected,
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _dateColumn,
            child: Text(
              '${DayLabel.of(backup.createdAt, now: now)} · '
              '${DayLabel.time(backup.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppTypography.bodyCompactEmphasis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // O nome só aparece quando não foi o Evergreen que escreveu o
          // arquivo: nos nossos ele é a mesma data que já está à esquerda, e
          // repeti-la seria ruído. Num arquivo trazido de fora o nome é
          // justamente como a pessoa o reconhece.
          Expanded(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppTypography.captionXS.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _sizeColumn,
            child: Text(
              ByteSize.compact(backup.sizeBytes),
              textAlign: TextAlign.right,
              style: AppTypography.captionSmall,
            ),
          ),
        ],
      ),
    );
  }
}

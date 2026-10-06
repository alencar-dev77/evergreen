import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../../core/design/themes/evergreen_tokens.dart';
import '../../../shared/utils/day_label.dart';
import '../../../shared/utils/duration_format.dart';
import '../models/track_week_digest.dart';

/// Desenha a semana como as sete barras da tela do Track, num PNG que vai
/// anexado à notificação de segunda-feira.
///
/// Desenhado direto no `Canvas`, sem árvore de widgets: quem pede é o engine
/// da janela 0, e o que se quer é um arquivo, não uma tela. As cores saem dos
/// tokens da Estufa — a imagem é o Evergreen fora dele, e precisa parecer ele.
abstract final class TrackWeekChart {
  static const _width = 1440.0;
  static const _height = 800.0;
  static const _padding = 72.0;

  /// Escreve o PNG em [directory] e devolve o caminho, ou `null` se o desenho
  /// falhar — a notificação sai sem imagem, nunca deixa de sair.
  static Future<String?> render(
    TrackWeekDigest digest, {
    Directory? directory,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      _paint(ui.Canvas(recorder), digest);

      final image = await recorder.endRecording().toImage(
        _width.toInt(),
        _height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;

      final folder = directory ?? Directory.systemTemp;
      final stamp = digest.weekStart.toIso8601String().substring(0, 10);
      final file = File(p.join(folder.path, 'evergreen-semana-$stamp.png'));
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static void _paint(ui.Canvas canvas, TrackWeekDigest digest) {
    const colors = EvergreenTokens.palette;
    const bounds = ui.Rect.fromLTWH(0, 0, _width, _height);

    canvas.drawRect(bounds, ui.Paint()..color = colors.canvas);

    // A luz verde no canto é a mesma do cabeçalho do Hub: é ela que faz a
    // imagem ser reconhecida antes de ser lida.
    canvas.drawRect(
      bounds,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(_width * 0.92, 0),
          _width * 0.7,
          [
            colors.accent.withValues(alpha: 0.22),
            colors.accent.withValues(alpha: 0),
          ],
        ),
    );

    _text(
      canvas,
      digest.rangeLabel.toUpperCase(),
      const ui.Offset(_padding, _padding),
      size: 30,
      color: colors.textTertiary,
      weight: ui.FontWeight.w600,
      spacing: 3,
    );
    _text(
      canvas,
      DurationFormat.compact(digest.totals.registered),
      const ui.Offset(_padding, _padding + 48),
      size: 96,
      color: colors.textPrimary,
      weight: ui.FontWeight.w700,
    );
    _text(
      canvas,
      digest.totals.registered == Duration.zero
          ? digest.extras.join(' · ')
          : 'registradas em foco e reuniões',
      const ui.Offset(_padding, _padding + 166),
      size: 32,
      color: colors.textSecondary,
    );

    _bars(canvas, digest);
  }

  static void _bars(ui.Canvas canvas, TrackWeekDigest digest) {
    const colors = EvergreenTokens.palette;
    const top = 340.0;
    const labelHeight = 56.0;
    const bottom = _height - _padding - labelHeight;
    const gap = 36.0;
    final barWidth = (_width - 2 * _padding - 6 * gap) / 7;

    final best = digest.bestDay;
    final peak = digest.daily.fold<int>(
      0,
      (max, day) => math.max(max, day.inSeconds),
    );

    for (var i = 0; i < 7; i++) {
      final left = _padding + i * (barWidth + gap);
      final track = ui.RRect.fromLTRBR(
        left,
        top,
        left + barWidth,
        bottom,
        const ui.Radius.circular(22),
      );
      canvas.drawRRect(track, ui.Paint()..color = colors.surface);

      final seconds = digest.daily[i].inSeconds;
      if (seconds > 0 && peak > 0) {
        // Piso visível: um dia de quinze minutos ainda é um dia com registro,
        // e uma barra de dois pixels sumiria na miniatura.
        final height = math.max((bottom - top) * seconds / peak, 44.0);
        final fill = ui.RRect.fromLTRBR(
          left,
          bottom - height,
          left + barWidth,
          bottom,
          const ui.Radius.circular(22),
        );
        final isBest = i == best;
        canvas.drawRRect(
          fill,
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset(0, bottom - height),
              ui.Offset(0, bottom),
              isBest
                  ? [colors.accentLight, colors.accent]
                  : [
                      colors.accentDeep,
                      colors.accentDeep.withValues(alpha: 0.7),
                    ],
            ),
        );

        if (isBest) {
          _text(
            canvas,
            DurationFormat.compact(digest.daily[i]),
            ui.Offset(left, bottom - height - 46),
            size: 28,
            color: colors.textPrimary,
            weight: ui.FontWeight.w600,
            width: barWidth,
            center: true,
          );
        }
      }

      _text(
        canvas,
        DayLabel.weekdays[i],
        ui.Offset(left, bottom + 18),
        size: 28,
        color: i == best ? colors.accentLight : colors.textTertiary,
        weight: i == best ? ui.FontWeight.w600 : ui.FontWeight.w400,
        width: barWidth,
        center: true,
      );
    }
  }

  static void _text(
    ui.Canvas canvas,
    String text,
    ui.Offset at, {
    required double size,
    required ui.Color color,
    ui.FontWeight weight = ui.FontWeight.w400,
    double spacing = 0,
    double width = _width - 2 * _padding,
    bool center = false,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
              maxLines: 1,
              ellipsis: '…',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
              letterSpacing: spacing,
            ),
          )
          ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, at);
  }
}

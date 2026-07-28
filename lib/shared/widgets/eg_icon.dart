import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';

/// Conjunto de ícones do Evergreen.
///
/// Desenhados como paths sobre um viewBox 16x16, replicando exatamente os SVGs
/// do protótipo de design. Ícones próprios (em vez do Material) mantêm o traço
/// fino e uniforme que a identidade "Dark Premium" exige.
enum EgIconData {
  /// Documento — representa um item de texto.
  document,

  /// Elo de corrente — representa um link.
  link,

  /// Chevron de terminal — representa um comando.
  terminal,

  /// Lupa do campo de busca.
  search,

  /// Estrela preenchida — indicador de item fixado.
  star,

  /// Sinal de mais.
  plus,

  /// Engrenagem simplificada — configurações.
  gear,

  /// Lixeira — ação destrutiva.
  trash,

  /// Prancheta — identifica o módulo Pin.
  clipboard,

  /// Cronômetro — identifica o módulo Focus.
  timer,

  /// Sol — identifica o módulo Awake (a tela que não apaga).
  sun,

  /// Árvore perene — a marca do Evergreen (preenchida, como a [star]).
  evergreen,
}

/// Renderiza um [EgIconData] no tamanho e cor pedidos.
class EgIcon extends StatelessWidget {
  const EgIcon(
    this.icon, {
    super.key,
    this.size = 14,
    this.color = AppColors.textSecondary,
    this.strokeWidth = 1.3,
  });

  final EgIconData icon;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _EgIconPainter(
          icon: icon,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _EgIconPainter extends CustomPainter {
  const _EgIconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  final EgIconData icon;
  final Color color;
  final double strokeWidth;

  /// Os paths são descritos no espaço 16x16 do SVG original.
  static const _viewBox = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale);

    final isFilled = icon == EgIconData.star || icon == EgIconData.evergreen;
    if (isFilled) {
      canvas.drawPath(
        icon == EgIconData.star ? _starPath() : _evergreenPath(),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    } else {
      canvas.drawPath(
        _strokePath(),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }

    canvas.restore();
  }

  Path _strokePath() => switch (icon) {
        EgIconData.document => _documentPath(),
        EgIconData.link => _linkPath(),
        EgIconData.terminal => _terminalPath(),
        EgIconData.search => _searchPath(),
        EgIconData.plus => _plusPath(),
        EgIconData.gear => _gearPath(),
        EgIconData.trash => _trashPath(),
        EgIconData.clipboard => _clipboardPath(),
        EgIconData.timer => _timerPath(),
        EgIconData.sun => _sunPath(),
        EgIconData.star => _starPath(),
        EgIconData.evergreen => _evergreenPath(),
      };

  Path _documentPath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 2, 10, 12),
        const Radius.circular(1.5),
      ),
    )
    ..moveTo(5.5, 6)
    ..lineTo(10.5, 6)
    ..moveTo(5.5, 9)
    ..lineTo(10.5, 9);

  Path _linkPath() => Path()
    ..moveTo(6.5, 9.5)
    ..lineTo(9.5, 6.5)
    ..moveTo(8.2, 5.3)
    ..lineTo(9.2, 4.3)
    ..arcToPoint(
      const Offset(12.4, 7.5),
      radius: const Radius.circular(2.3),
      clockwise: true,
    )
    ..lineTo(11.4, 8.5)
    ..moveTo(7.8, 10.7)
    ..lineTo(6.8, 11.7)
    ..arcToPoint(
      const Offset(3.6, 8.5),
      radius: const Radius.circular(2.3),
      clockwise: true,
    )
    ..lineTo(4.6, 7.5);

  Path _terminalPath() => Path()
    ..moveTo(3, 4)
    ..lineTo(7, 8)
    ..lineTo(3, 12)
    ..moveTo(8.5, 12)
    ..lineTo(13, 12);

  Path _searchPath() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(7, 7), radius: 5))
    ..moveTo(11, 11)
    ..lineTo(14.5, 14.5);

  Path _plusPath() => Path()
    ..moveTo(4, 8)
    ..lineTo(12, 8)
    ..moveTo(8, 4)
    ..lineTo(8, 12);

  Path _gearPath() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(8, 8), radius: 2.2))
    ..addOval(Rect.fromCircle(center: const Offset(8, 8), radius: 5.4));

  Path _trashPath() => Path()
    ..moveTo(3.5, 4.5)
    ..lineTo(12.5, 4.5)
    ..moveTo(6.5, 4.5)
    ..lineTo(6.5, 3)
    ..lineTo(9.5, 3)
    ..lineTo(9.5, 4.5)
    ..moveTo(4.8, 4.5)
    ..lineTo(5.4, 13)
    ..lineTo(10.6, 13)
    ..lineTo(11.2, 4.5);

  Path _clipboardPath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.5, 3, 9, 11),
        const Radius.circular(1.6),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 1.6, 4, 2.8),
        const Radius.circular(0.9),
      ),
    );

  Path _timerPath() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(8, 9), radius: 5))
    ..moveTo(8, 6.2)
    ..lineTo(8, 9)
    ..lineTo(10, 10.2)
    ..moveTo(6.3, 2)
    ..lineTo(9.7, 2);

  /// Sol de traço: disco pequeno e oito raios curtos.
  ///
  /// Os raios param a 2,2px do disco e vão até a borda do viewBox — mais curtos
  /// desapareceriam no tamanho de 14px da sidebar, mais longos engrossariam o
  /// ícone a ponto de ele pesar mais que os vizinhos.
  Path _sunPath() {
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(8, 8), radius: 3.2));

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final dx = math.cos(angle);
      final dy = math.sin(angle);

      path
        ..moveTo(8 + dx * 5.4, 8 + dy * 5.4)
        ..lineTo(8 + dx * 7, 8 + dy * 7);
    }

    return path;
  }

  /// Árvore perene do Evergreen, centralizada no viewBox 16x16 (o mesmo
  /// desenho de `assets/icons/evergreen_menu.svg`, reescalado a partir do
  /// espaço 22 do SVG e centrado em (8, 8)).
  Path _evergreenPath() => Path()
    ..moveTo(8.0, 2.0)
    ..lineTo(11.51, 5.69)
    ..lineTo(9.75, 5.69)
    ..lineTo(13.35, 9.38)
    ..lineTo(10.58, 9.38)
    ..lineTo(14.46, 14.0)
    ..lineTo(1.54, 14.0)
    ..lineTo(5.42, 9.38)
    ..lineTo(2.65, 9.38)
    ..lineTo(6.25, 5.69)
    ..lineTo(4.49, 5.69)
    ..close();

  Path _starPath() => Path()
    ..moveTo(8, 2)
    ..lineTo(9.8, 5.7)
    ..lineTo(13.8, 6.3)
    ..lineTo(10.8, 9.2)
    ..lineTo(11.5, 13.2)
    ..lineTo(8, 11.3)
    ..lineTo(4.5, 13.2)
    ..lineTo(5.2, 9.2)
    ..lineTo(2.2, 6.3)
    ..lineTo(6.2, 5.7)
    ..close();

  @override
  bool shouldRepaint(_EgIconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}

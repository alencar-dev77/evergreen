import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'eg_brand_mark.dart';

import '../../core/design/eg_tokens.dart';

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

  /// Envelope — representa um endereço de e-mail.
  envelope,

  /// Aparelho de telefone — representa um número de telefone.
  phone,

  /// Cartão com retrato e linha — representa um documento (CPF).
  identityCard,

  /// Prédio com janelas — representa uma empresa (CNPJ).
  ///
  /// Ícone próprio, e não o [identityCard] repetido: num histórico com os dois,
  /// duas linhas idênticas de ícone que só o rótulo separa é o mesmo que não
  /// ter ícone — e pessoa e empresa são justamente a distinção que a lista
  /// precisa deixar correr o olho.
  building,

  /// Duas setas em círculo — sortear outro, refazer.
  shuffle,

  /// Lupa do campo de busca.
  search,

  /// Estrela preenchida — indicador de item fixado.
  star,

  /// Sinal de mais.
  plus,

  /// Duas barras — suspende o que está em curso.
  pause,

  /// Triângulo — retoma o que estava suspenso.
  play,

  /// Xis — fecha o que está aberto.
  close,

  /// Engrenagem simplificada — configurações.
  gear,

  /// Lixeira — ação destrutiva.
  trash,

  /// Sino — lembrete marcado (o cartão do Leaf).
  bell,

  /// Olho — mostrar o que está sob o vidro.
  eye,

  /// Olho riscado — cartão sob o vidro fosco.
  eyeOff,

  /// Prancheta — identifica o módulo Pin.
  clipboard,

  /// Cronômetro — identifica o módulo Focus.
  timer,

  /// Sol — identifica o módulo Awake (a tela que não apaga).
  sun,

  /// Papel com a ponta dobrada — identifica o módulo Leaf.
  note,

  /// Microfone — identifica o módulo Echo.
  microphone,

  /// Trilha sinuosa com o marco no fim — identifica o módulo Track.
  track,

  /// Bandeja com uma seta entrando — identifica o módulo Nest.
  tray,

  /// Pasta — o item da prateleira que não é um arquivo.
  folder,

  /// O canivete — a marca do Evergreen, o mesmo desenho da abertura do Hub e
  /// do ícone do aplicativo. Não é um path daqui: vem de `eg_brand_mark.dart`.
  evergreen,
}

/// Renderiza um [EgIconData] no tamanho e cor pedidos.
///
/// **Decorativo por padrão**, e isso é de propósito: o ícone é um `CustomPaint`
/// sem texto nenhum, então ele não põe nada na árvore de acessibilidade — e
/// quase sempre é isso o certo, porque quem nomeia é o pai. Numa linha do Pin o
/// glifo repete o tipo que o rótulo da linha já anuncia; num botão com texto
/// ele repete o texto. Nomear os dois faria o leitor de tela dizer "ícone de
/// fixar, fixar".
///
/// [semanticLabel] é para o caso em que o ícone **é** a informação e ninguém
/// mais a diz — hoje, o indicador de um estado que só o desenho comunica.
class EgIcon extends StatelessWidget {
  const EgIcon(
    this.icon, {
    super.key,
    this.size = 14,
    this.color,
    this.strokeWidth = 1.3,
    this.semanticLabel,
  });

  final EgIconData icon;
  final double size;

  /// A cor do glifo. `null` é o padrão e quer dizer "a secundária do tema" —
  /// ícone aqui é acessório de um texto, e acompanha a pele como ele.
  final Color? color;
  final double strokeWidth;

  /// O que este ícone significa, quando ele é a única coisa que diz isso.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _EgIconPainter(
          icon: this.icon,
          color: color ?? context.eg.colors.textSecondary,
          strokeWidth: strokeWidth,
        ),
      ),
    );

    if (semanticLabel == null) return icon;

    return Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _EgIconPainter extends CustomPainter {
  const _EgIconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  final EgIconData icon;

  /// Já resolvida: o `null` do widget virou a cor do tema antes de chegar aqui.
  final Color color;
  final double strokeWidth;

  /// Os paths são descritos no espaço 16x16 do SVG original.
  static const _viewBox = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale);

    // A marca não é um glifo desta lista: ela é o desenho do canivete, o mesmo
    // que a abertura do Hub anima e que o ícone do aplicativo mostra. Redesenhar
    // uma versão de 16px aqui é como o pinheiro sobreviveu à aposentadoria —
    // havia dois desenhos, e só um foi trocado.
    //
    // Numa cor só: quem separa lâmina de cabo neste tamanho é a silhueta e o
    // furo do rebite, não o contraste entre os dois verdes.
    if (icon == EgIconData.evergreen) {
      paintBrandMarkFitted(
        canvas,
        _viewBox,
        cover: 1,
        blade: color,
        handle: color,
      );
      canvas.restore();
      return;
    }

    if (icon == EgIconData.star) {
      canvas.drawPath(
        _starPath(),
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
    EgIconData.envelope => _envelopePath(),
    EgIconData.phone => _phonePath(),
    EgIconData.identityCard => _identityCardPath(),
    EgIconData.building => _buildingPath(),
    EgIconData.shuffle => _shufflePath(),
    EgIconData.search => _searchPath(),
    EgIconData.plus => _plusPath(),
    EgIconData.pause => _pausePath(),
    EgIconData.play => _playPath(),
    EgIconData.close => _closePath(),
    EgIconData.gear => _gearPath(),
    EgIconData.trash => _trashPath(),
    EgIconData.bell => _bellPath(),
    EgIconData.eye => _eyePath(),
    EgIconData.eyeOff =>
      _eyePath()
        ..moveTo(3, 13)
        ..lineTo(13, 3),
    EgIconData.clipboard => _clipboardPath(),
    EgIconData.timer => _timerPath(),
    EgIconData.sun => _sunPath(),
    EgIconData.note => _notePath(),
    EgIconData.microphone => _microphonePath(),
    EgIconData.track => _trackPath(),
    EgIconData.tray => _trayPath(),
    EgIconData.folder => _folderPath(),
    EgIconData.star => _starPath(),
    // A marca não passa por aqui: ela é pintada antes, direto do desenho
    // do canivete.
    EgIconData.evergreen => Path(),
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

  Path _envelopePath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 3.5, 12, 9),
        const Radius.circular(1.5),
      ),
    )
    // A aba dobrada nasce um pouco abaixo da quina para não encostar no canto
    // arredondado — encostada, ela lê como um risco atravessando o envelope.
    ..moveTo(2.8, 4.6)
    ..lineTo(8, 8.6)
    ..lineTo(13.2, 4.6);

  Path _phonePath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5, 1.5, 7, 13),
        const Radius.circular(1.8),
      ),
    )
    ..moveTo(7, 12.2)
    ..lineTo(9, 12.2);

  Path _identityCardPath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.5, 3.5, 13, 9),
        const Radius.circular(1.5),
      ),
    )
    ..addOval(Rect.fromCircle(center: const Offset(5.6, 7.2), radius: 1.4))
    ..moveTo(9, 6.6)
    ..lineTo(12.2, 6.6)
    ..moveTo(9, 9.4)
    ..lineTo(12.2, 9.4);

  /// Prédio de duas alturas com janelas — a empresa, atrás do CNPJ.
  ///
  /// Mesma gramática do [_identityCardPath]: um contorno arredondado e traços
  /// curtos dentro. As janelas são segmentos, não retângulos — a 13px um
  /// retângulo de um pixel e meio vira borrão, e o traço fica legível.
  Path _buildingPath() => Path()
    // O corpo alto, à esquerda.
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 2.5, 6, 11),
        const Radius.circular(1),
      ),
    )
    // O anexo baixo, à direita, encostado nele.
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8.5, 6.5, 5, 7),
        const Radius.circular(1),
      ),
    )
    ..moveTo(4.6, 5.3)
    ..lineTo(6.4, 5.3)
    ..moveTo(4.6, 8)
    ..lineTo(6.4, 8)
    ..moveTo(4.6, 10.7)
    ..lineTo(6.4, 10.7)
    ..moveTo(10.4, 9.2)
    ..lineTo(11.6, 9.2)
    ..moveTo(10.4, 11.4)
    ..lineTo(11.6, 11.4);

  /// Seta dando a volta — sortear outro.
  ///
  /// A ponta é um chevron de dois traços, e não um triângulo preenchido: no
  /// viewBox de 16px o triângulo pesa mais que o próprio arco, e este ícone
  /// aparece a 13px dentro de uma linha de lista, ao lado de traços finos.
  Path _shufflePath() {
    const center = Offset(8, 8);
    const radius = 5.0;
    const start = -math.pi / 3; // começa às duas horas
    const sweep = 5 * math.pi / 3; // e dá quase a volta inteira
    const end = start + sweep;

    final tip = Offset(
      center.dx + math.cos(end) * radius,
      center.dy + math.sin(end) * radius,
    );

    // Tangente no fim do arco (para onde ele seguiria) e o raio, para abrir as
    // duas asas do chevron simetricamente em volta dela.
    final along = Offset(-math.sin(end), math.cos(end));
    final across = Offset(math.cos(end), math.sin(end));
    final back = tip - along * 2.3;

    return Path()
      ..addArc(Rect.fromCircle(center: center, radius: radius), start, sweep)
      ..moveTo(back.dx + across.dx * 1.3, back.dy + across.dy * 1.3)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(back.dx - across.dx * 1.3, back.dy - across.dy * 1.3);
  }

  Path _searchPath() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(7, 7), radius: 5))
    ..moveTo(11, 11)
    ..lineTo(14.5, 14.5);

  Path _plusPath() => Path()
    ..moveTo(4, 8)
    ..lineTo(12, 8)
    ..moveTo(8, 4)
    ..lineTo(8, 12);

  /// As duas barras da pausa, no mesmo traço do resto da família — e não dois
  /// retângulos cheios, que pesariam mais que qualquer outro glifo ao lado.
  Path _pausePath() => Path()
    ..moveTo(6.2, 4.4)
    ..lineTo(6.2, 11.6)
    ..moveTo(9.8, 4.4)
    ..lineTo(9.8, 11.6);

  /// O triângulo do retomar, fechado: é a única forma que o olho lê como
  /// "toca" — vazado, ele viraria um sinal de "maior que".
  Path _playPath() => Path()
    ..moveTo(5.8, 4.2)
    ..lineTo(12, 8)
    ..lineTo(5.8, 11.8)
    ..close();

  /// O mesmo traço do [_plusPath] girado 45°, e não um "x" desenhado à parte:
  /// os dois convivem na mesma tela (no Leaf) e precisam ter o mesmo peso.
  Path _closePath() => Path()
    ..moveTo(4.6, 4.6)
    ..lineTo(11.4, 11.4)
    ..moveTo(11.4, 4.6)
    ..lineTo(4.6, 11.4);

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

  /// Sino de traço: a cúpula descendo em curva até a aba, e o badalo como um
  /// arco curto embaixo. Sem o pino em cima — em 12px ele vira um ponto solto.
  Path _bellPath() => Path()
    ..moveTo(3.2, 11.5)
    ..lineTo(12.8, 11.5)
    ..moveTo(4.4, 11.5)
    ..lineTo(4.4, 7.4)
    ..cubicTo(4.4, 5.2, 6, 3.2, 8, 3.2)
    ..cubicTo(10, 3.2, 11.6, 5.2, 11.6, 7.4)
    ..lineTo(11.6, 11.5)
    ..moveTo(6.6, 13.3)
    ..quadraticBezierTo(8, 14.6, 9.4, 13.3);

  /// Olho de traço: a amêndoa em duas curvas e a pupila. O riscado
  /// ([EgIconData.eyeOff]) é este com a diagonal por cima — os dois precisam
  /// ter a mesma silhueta para a troca ler como o mesmo botão mudando de
  /// estado.
  Path _eyePath() => Path()
    ..moveTo(1.8, 8)
    ..quadraticBezierTo(8, 1.6, 14.2, 8)
    ..quadraticBezierTo(8, 14.4, 1.8, 8)
    ..addOval(Rect.fromCircle(center: const Offset(8, 8), radius: 2));

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

  /// Microfone de traço: cápsula, berço e pé.
  ///
  /// O berço é uma curva, e não um arco de círculo: no viewBox de 16px um arco
  /// verdadeiro fecha demais nas pontas e encosta na cápsula, o que no tamanho
  /// de 14px da sidebar vira um borrão só.
  Path _microphonePath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 1.5, 4, 7.5),
        const Radius.circular(2),
      ),
    )
    ..moveTo(3.8, 8.4)
    ..quadraticBezierTo(8, 13.2, 12.2, 8.4)
    ..moveTo(8, 11.4)
    ..lineTo(8, 14)
    ..moveTo(5.6, 14)
    ..lineTo(10.4, 14);

  /// Trilha que sobe serpenteando até um marco — o Track.
  ///
  /// O marco solto no fim (e não colado na curva) é o que a distingue de uma
  /// onda: com ele o desenho tem destino, que é o que o módulo faz — reconstrói
  /// o caminho até onde a pessoa está hoje.
  Path _trackPath() => Path()
    ..moveTo(2.6, 13.2)
    ..cubicTo(5.6, 13.2, 4.6, 8.4, 8.0, 8.4)
    ..cubicTo(10.2, 8.4, 10.4, 5.6, 11.3, 4.4)
    ..addOval(Rect.fromCircle(center: const Offset(12.9, 2.9), radius: 1.5));

  /// Bandeja com uma seta entrando — o Nest.
  ///
  /// A seta é o que separa este ícone de uma caixa qualquer: a bandeja sozinha
  /// lê como "arquivo morto", e o módulo é sobre coisas **chegando** e saindo
  /// em seguida. O rebaixo no meio da tampa é o mesmo desenho de caixa de
  /// entrada que o macOS usa — é ele que faz o retângulo virar bandeja em 14px.
  Path _trayPath() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 7, 11, 6.5),
        const Radius.circular(1.5),
      ),
    )
    ..moveTo(2.5, 9.6)
    ..lineTo(5.7, 9.6)
    ..lineTo(6.5, 11)
    ..lineTo(9.5, 11)
    ..lineTo(10.3, 9.6)
    ..lineTo(13.5, 9.6)
    ..moveTo(8, 1.8)
    ..lineTo(8, 5.5)
    ..moveTo(6.2, 3.7)
    ..lineTo(8, 5.5)
    ..lineTo(9.8, 3.7);

  /// Pasta de traço: o corpo e a aba, sem nada dentro.
  ///
  /// Existe separada do [_trayPath] porque as duas aparecem na **mesma lista**
  /// — a bandeja é o módulo, a pasta é o item —, e um desenho servindo aos dois
  /// papéis a três centímetros de distância um do outro não distingue nada.
  Path _folderPath() => Path()
    ..moveTo(2, 12.5)
    ..lineTo(2, 4.2)
    ..arcToPoint(
      const Offset(3.2, 3),
      radius: const Radius.circular(1.2),
      clockwise: true,
    )
    ..lineTo(6.2, 3)
    ..lineTo(7.8, 5)
    ..lineTo(12.8, 5)
    ..arcToPoint(
      const Offset(14, 6.2),
      radius: const Radius.circular(1.2),
      clockwise: true,
    )
    ..lineTo(14, 11.8)
    ..arcToPoint(
      const Offset(12.8, 13),
      radius: const Radius.circular(1.2),
      clockwise: true,
    )
    ..lineTo(3.2, 13)
    ..arcToPoint(
      const Offset(2, 11.8),
      radius: const Radius.circular(1.2),
      clockwise: true,
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

  /// Papel com a ponta de baixo dobrada — o Leaf.
  ///
  /// A dobra é o que distingue este ícone do [_documentPath] (que é o item de
  /// texto do Pin) sem precisar de uma segunda forma: um é uma folha escrita, o
  /// outro é uma folha destacada.
  Path _notePath() => Path()
    ..moveTo(3, 2.8)
    ..lineTo(13, 2.8)
    ..lineTo(13, 9.4)
    ..lineTo(9.4, 13.2)
    ..lineTo(3, 13.2)
    ..close()
    ..moveTo(13, 9.4)
    ..lineTo(9.4, 9.4)
    ..lineTo(9.4, 13.2);

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

import 'package:flutter/foundation.dart';

/// O som que está entrando agora, por banda de frequência.
///
/// Cada número é a energia **medida** de uma faixa do espectro, de 0 (silêncio
/// de sala) a 1 (o teto da escala), da mais grave para a mais aguda. Quem mede
/// é o lado nativo, com uma FFT sobre os últimos 32 ms de cada faixa de áudio,
/// dez vezes por segundo.
///
/// É por isso que o painel tem um equalizador, e não uma fita passando: com um
/// número só por faixa todas as barras teriam a mesma altura, e desenhá-las
/// diferentes seria inventar. Aqui cada barra é uma medida diferente do mesmo
/// instante — as graves da voz, as agudas das consoantes.
///
/// Duas faixas, e não vozes: o Echo grava o microfone e o áudio do Mac, e não
/// separa pessoa por pessoa (ver `Speaker`).
@immutable
class EchoSpectrum {
  const EchoSpectrum({required this.mic, required this.system});

  static const silent = EchoSpectrum(mic: [], system: []);

  /// De quanto em quanto tempo uma medida nova chega do lado nativo.
  ///
  /// É o contrato com o `EchoStreamOutput`, e mora aqui porque é dele que a
  /// tela depende: quem desenha as barras interpola a altura **exatamente**
  /// neste intervalo — mais curto, elas param e esperam; mais longo, ficam
  /// atrasadas em relação ao som. Mudou lá, muda aqui.
  static const interval = Duration(milliseconds: 100);

  /// A sua voz, pelo microfone.
  final List<double> mic;

  /// Todo mundo menos você, pelo áudio do sistema.
  final List<double> system;

  factory EchoSpectrum.fromMap(Map<Object?, Object?> map) => EchoSpectrum(
    mic: _bands(map['mic']),
    system: _bands(map['system']),
  );

  static List<double> _bands(Object? value) => [
    if (value is List)
      for (final band in value)
        ((band as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
  ];

  /// Nada entrando em nenhuma das duas faixas.
  bool get isSilent =>
      mic.every((band) => band <= 0) && system.every((band) => band <= 0);
}

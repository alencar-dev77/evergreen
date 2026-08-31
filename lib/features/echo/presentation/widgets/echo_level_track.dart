import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/echo_spectrum.dart';

/// Uma faixa de áudio enquanto ela está sendo gravada: o nome à esquerda, o
/// equalizador à direita.
///
/// **É um medidor, não um enfeite.** Cada barra é uma banda de frequência
/// medida pelo próprio gravador — uma FFT sobre os últimos 32 ms, dez vezes por
/// segundo (ver `EchoSpectrum`). As barras **não andam para o lado**: elas
/// ficam no lugar e pulam, como um equalizador, porque quem se move é a voz e
/// não o tempo. Uma fita correndo mostraria o passado recente; a pergunta aqui
/// é o agora.
///
/// E a pergunta é cara: faixa muda é o defeito mais caro do módulo, porque só
/// aparece no fim, quando o áudio já foi.
class EchoLevelTrack extends StatelessWidget {
  const EchoLevelTrack({
    super.key,
    required this.label,
    required this.bands,
    required this.color,
  });

  /// "Você", "Sistema" — quem é esta faixa.
  final String label;

  /// A energia de cada banda, de 0 a 1, da mais grave para a mais aguda. Vazio
  /// é a faixa em silêncio (ou a gravação pausada): as barras descansam no
  /// chão, sem sumir.
  final List<double> bands;

  final Color color;

  /// Quantas barras a faixa desenha enquanto não chegou medida nenhuma — o
  /// mesmo número de bandas que o nativo manda, para o equalizador não mudar de
  /// tamanho no primeiro som.
  static const _restingBars = 10;

  /// Largura do nome. Fixa, para as duas faixas começarem no mesmo x — são
  /// duas medidas para comparar, e comparar exige a mesma origem.
  static const _labelColumn = 62.0;

  /// A barra mais baixa possível. Silêncio não some: uma faixa que sumisse da
  /// tela seria indistinguível de uma faixa que nunca existiu.
  static const _floor = 3.0;
  static const _height = 22.0;

  @override
  Widget build(BuildContext context) {
    final values = bands.isEmpty ? List.filled(_restingBars, 0.0) : bands;

    return Semantics(
      label: '$label: ${_loudness(values)}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(width: _labelColumn, child: EgSectionLabel(label)),
          Expanded(
            child: SizedBox(
              height: _height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < values.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xxxs),
                    Expanded(child: _bar(values[i])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double band) {
    return Align(
      alignment: Alignment.center,
      // A altura é animada, e é a única animação do painel: as medidas chegam
      // dez vezes por segundo, e sem interpolação entre elas as barras piscam
      // em degraus — um equalizador que treme em vez de subir. A duração é o
      // intervalo entre duas medidas (`EchoSpectrum.interval`), e não um degrau
      // da escala de movimento do app: o ritmo aqui é o do dado, não o do
      // produto. Assim o movimento termina quando a próxima medida chega.
      //
      // `double.infinity` na largura: o `Align` afrouxa as duas restrições, e
      // uma caixa decorada sem filho debaixo de restrição frouxa se encolhe até
      // zero — a barra existia e media 0 px de largura.
      child: AnimatedContainer(
        duration: EchoSpectrum.interval,
        curve: Curves.linear,
        height: _floor + (_height - _floor) * band.clamp(0.0, 1.0),
        width: double.infinity,
        decoration: BoxDecoration(
          // Silêncio fica como pista: a mesma cor, quase apagada, para a faixa
          // continuar sendo uma linha e não uma sequência de buracos.
          color: color.withValues(alpha: band <= 0.02 ? 0.18 : 1),
          borderRadius: BorderRadius.circular(_floor / 2),
        ),
      ),
    );
  }

  /// O que o leitor de tela diz no lugar das barras: alto, baixo ou nada.
  String _loudness(List<double> values) {
    final peak = values.fold(0.0, (peak, band) => band > peak ? band : peak);
    if (peak <= 0.02) return 'sem som';
    if (peak < 0.25) return 'som fraco';

    return 'entrando som';
  }
}

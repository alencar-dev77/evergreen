import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_background.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_key_cap.dart';
import '../../models/onboarding_step.dart';

/// A apresentação de boas-vindas: um painel do Evergreen por vez, com o print
/// do painel de verdade sobre um palco que vai do preto ao verde da marca.
///
/// Roda uma vez por instalação. Quem decide é o `OnboardingViewModel`; este
/// widget só desenha o passo que recebe e avisa quando alguém avança, volta ou
/// desiste.
///
/// O print entra pelo topo e **vaza pela base do palco**, em vez de ser
/// reduzido até caber inteiro. É o que mantém o texto do painel legível: o do
/// Pin tem 467px de altura, e espremê-lo num palco de 340 transformaria a
/// interface em textura. O que interessa está em cima de qualquer maneira — o
/// cabeçalho, o cronômetro, o campo de busca.
class HubOnboarding extends StatelessWidget {
  const HubOnboarding({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  final OnboardingStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  static const _stageWidth = 620.0;
  static const _stageHeight = 320.0;

  /// Respiro entre a borda do palco e o print. Assimétrico de propósito: o
  /// print encosta na base porque vaza por ela.
  static const _stageInset = EdgeInsets.only(
    left: AppSpacing.huge,
    right: AppSpacing.huge,
    top: AppSpacing.huge,
  );

  bool get _isLast => index == total - 1;

  @override
  Widget build(BuildContext context) {
    return EgBackground(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xxxl,
                  horizontal: AppSpacing.huge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stage(context),
                    const SizedBox(height: AppSpacing.xxxl),
                    _title(context),
                    const SizedBox(height: AppSpacing.md),
                    _line(context),
                    const SizedBox(height: AppSpacing.xxxl),
                    _footer(context),
                  ],
                ),
              ),
            ),
          ),
          EgHintBar(
            hints: [
              const EgHint(keys: ['enter'], label: 'próximo'),
              if (index > 0)
                EgHint(keys: const ['←'], label: 'voltar', onTap: onPrevious),
            ],
            trailing: EgHint(
              keys: const ['esc'],
              label: 'pular',
              onTap: onSkip,
            ),
          ),
        ],
      ),
    );
  }

  /// O palco. É o único lugar do app onde um gradiente deve ser visto como
  /// gradiente — ver `EgGradients.onboardingStage`.
  Widget _stage(BuildContext context) {
    return SizedBox(
      width: _stageWidth,
      height: _stageHeight,
      child: ClipRRect(
        borderRadius: context.eg.shapes.panelAll,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: context.eg.gradients.onboardingStage,
                ),
              ),
            ),
            Positioned(
              left: _stageInset.left,
              right: _stageInset.right,
              top: _topOf(_stageWidth - _stageInset.horizontal),
              // Sem `bottom`: a imagem fica com a altura natural e o recorte do
              // palco corta o excedente.
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: math.min(step.imageWidth, constraints.maxWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Onze, e não um token de raio: este canto é o do
                        // **print**, que já vem arredondado dentro do arquivo.
                        // A sombra precisa acompanhar aquele canto, não o que o
                        // tema em vigor usaria — ela é a sombra da imagem, não
                        // de um painel desenhado aqui.
                        borderRadius: const BorderRadius.all(
                          Radius.circular(11),
                        ),
                        boxShadow: context.eg.elevations.floatingPanel,
                      ),
                      child: Image.asset(
                        step.image,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        // O print é um retrato da interface, não conteúdo: o
                        // leitor de tela ouve o nome e a frase logo abaixo, que
                        // dizem a mesma coisa melhor.
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Onde o print começa dentro do palco.
  ///
  /// Cabendo de pé, ele é centralizado na sobra; não cabendo, encosta no topo e
  /// sangra pela base. É o que evita as duas feiuras opostas: um print curto
  /// colado no teto com um vazio verde embaixo, e um print alto reduzido até a
  /// interface virar textura.
  double _topOf(double available) {
    final escala = math.min(1.0, available / step.imageWidth);
    final altura = step.imageHeight * escala;
    final sobra = _stageHeight - _stageInset.top - altura;
    return _stageInset.top + math.max(0.0, sobra / 2);
  }

  Widget _title(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(step.module.name, style: context.eg.text.screenTitle),
        const SizedBox(width: AppSpacing.md),
        EgKeyCap(step.shortcut),
      ],
    );
  }

  Widget _line(BuildContext context) {
    return SizedBox(
      width: 480,
      child: Text(
        step.line,
        textAlign: TextAlign.center,
        style: context.eg.text.body.copyWith(color: context.eg.colors.textSecondary),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dots(context),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: 200,
          child: EgButton(
            label: _isLast ? 'Começar' : 'Próximo',
            onPressed: onNext,
            expand: true,
            autofocus: true,
          ),
        ),
      ],
    );
  }

  /// Quantos passos faltam. Sem número escrito: numa sequência de cinco, contar
  /// pontos é mais rápido que ler "3 de 5".
  Widget _dots(BuildContext context) {
    return Semantics(
      label: 'Passo ${index + 1} de $total',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxxs + 1,
              ),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                curve: AppDurations.curve,
                width: i == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index
                      ? context.eg.colors.accent
                      : context.eg.colors.pressed,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

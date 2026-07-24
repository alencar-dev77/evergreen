import 'package:flutter/widgets.dart';

/// Paleta "Dark Premium" do Evergreen.
///
/// Fonte da verdade: `docs/design_handoff_pin/README.md`. Nenhuma cor literal
/// deve ser escrita fora deste arquivo — sempre referencie um token daqui.
abstract final class AppColors {
  /// Fundo da janela / overlay.
  static const background = Color(0xFF0B0B0B);

  /// Topo do gradiente de fundo — o mesmo preto com uma leve elevação e um
  /// toque quase imperceptível de verde. Serve só para dar profundidade à
  /// superfície e evitar o "preto blocado"; a diferença de luminância para o
  /// [background] fica na casa de 3–4%, nunca lida como "gradiente".
  static const backgroundTop = Color(0xFF12140F);

  /// Base do gradiente de fundo — um degrau abaixo do [background], para o
  /// fundo escurecer de leve na parte de baixo (vinheta sutil).
  static const backgroundDeep = Color(0xFF080808);

  /// Painel e card principal.
  static const surface = Color(0xFF141414);

  /// Topo do gradiente de superfície do painel flutuante — um degrau acima do
  /// [surface], reforçando a sensação de vidro iluminado por cima.
  static const surfaceTop = Color(0xFF191B17);

  /// Campos, cards internos e badges.
  static const card = Color(0xFF1A1A1A);

  /// Estado de hover / seleção de list item.
  static const hover = Color(0xFF232323);

  /// Bordas sutis de 1px.
  static const border = Color(0xFF262626);

  /// Ação primária, foco e indicador de item fixado.
  static const greenPrimary = Color(0xFF22C55E);

  /// Hover do botão primário e acentos.
  static const greenLight = Color(0xFF4ADE80);

  /// Texto principal.
  static const textPrimary = Color(0xFFF5F5F5);

  /// Metadados, labels e placeholders.
  static const textSecondary = Color(0xFF9CA3AF);

  /// Ações destrutivas.
  static const error = Color(0xFFEF4444);

  /// Alertas.
  static const warning = Color(0xFFF59E0B);

  /// Sombra do painel flutuante: `0 24px 60px rgba(0,0,0,0.55)`.
  static const shadow = Color(0x8C000000);
}

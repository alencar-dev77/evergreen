import 'package:flutter/widgets.dart';

/// A única cor que não é de tema nenhum.
///
/// Todas as outras mudam com a aparência escolhida e moram em
/// `themes/evergreen_tokens.dart` e `themes/apple_tokens.dart` — quem precisa
/// de uma pede ao `context.eg.colors`. Transparente não é uma escolha de
/// paleta: é a ausência de superfície, e vale igual nos dois temas.
abstract final class AppColors {
  static const transparent = Color(0x00000000);
}

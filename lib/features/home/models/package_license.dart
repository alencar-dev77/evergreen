import 'package:flutter/foundation.dart';

/// A licença de um componente que o Evergreen usa — ou a do próprio Evergreen.
@immutable
class PackageLicense {
  const PackageLicense({required this.name, required this.texts});

  /// O nome do pacote, como ele se publica (`flutter_riverpod`, `FluidAudio`).
  final String name;

  /// Um texto por licença. Quase sempre um só; um pacote que embute código de
  /// outro traz as duas.
  final List<String> texts;
}

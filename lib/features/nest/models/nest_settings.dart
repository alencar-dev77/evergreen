import 'nest_destination.dart';
import 'nest_transfer_mode.dart';

/// Preferências do módulo Nest.
class NestSettings {
  const NestSettings({
    this.defaultMode = NestTransferMode.copy,
    this.useShake = true,
    this.destinations = const [],
  });

  /// O que acontece ao mandar um item para um destino, quando nenhuma
  /// modificadora está pressionada.
  final NestTransferMode defaultMode;

  /// Deixar o chacoalhar chamar a prateleira no meio de um arraste.
  ///
  /// Ligado por padrão. Só vale com arquivo na mão — chacoalhar o mouse à toa
  /// não abre nada. Ver `NestShakeMonitor`.
  final bool useShake;

  /// As pastas favoritas, na ordem em que a lista as mostra — que é a ordem dos
  /// atalhos `⌘1..⌘9`.
  final List<NestDestination> destinations;

  /// Quantos destinos o painel alcança pelo teclado.
  ///
  /// Nove porque são nove teclas, o mesmo teto da parede do Leaf e da mesma
  /// natureza: o limite não é técnico, é o número de coisas que se alcança sem
  /// procurar.
  static const maxDestinations = 9;

  bool get isFull => destinations.length >= maxDestinations;

  NestSettings copyWith({
    NestTransferMode? defaultMode,
    bool? useShake,
    List<NestDestination>? destinations,
  }) => NestSettings(
    defaultMode: defaultMode ?? this.defaultMode,
    useShake: useShake ?? this.useShake,
    destinations: destinations ?? this.destinations,
  );
}

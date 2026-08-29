import 'nest_destination.dart';
import 'nest_transfer_mode.dart';

/// Preferências do módulo Nest.
class NestSettings {
  const NestSettings({
    this.defaultMode = NestTransferMode.copy,
    this.useNotch = true,
    this.destinations = const [],
  });

  /// O que acontece ao mandar um item para um destino, quando nenhuma
  /// modificadora está pressionada.
  final NestTransferMode defaultMode;

  /// Deixar o recorte da tela receber arquivos.
  ///
  /// Ligado por padrão, e sem efeito nenhum em Mac que não tem recorte — a
  /// janela invisível simplesmente não nasce, e a linha nem aparece na tela de
  /// preferências. Ver `NestNotchWindow`.
  final bool useNotch;

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
    bool? useNotch,
    List<NestDestination>? destinations,
  }) => NestSettings(
    defaultMode: defaultMode ?? this.defaultMode,
    useNotch: useNotch ?? this.useNotch,
    destinations: destinations ?? this.destinations,
  );
}

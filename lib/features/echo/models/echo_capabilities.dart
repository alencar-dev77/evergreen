/// Se o modelo de resumo existe nesta máquina — e, quando não existe, por quê.
///
/// O motivo importa porque cada um tem uma saída diferente: falta de permissão
/// a pessoa resolve, hardware velho não. Uma tela que só dissesse "indisponível"
/// mandaria todo mundo procurar a mesma solução, e ela só serve para um deles.
enum SummaryAvailability {
  available,

  /// O Mac não tem Apple Intelligence. Não há o que fazer.
  deviceNotEligible,

  /// Tem, mas está desligado nos Ajustes — isso a pessoa liga.
  appleIntelligenceNotEnabled,

  /// Ainda baixando ou preparando o modelo. Tentar de novo mais tarde resolve.
  modelNotReady,

  /// macOS anterior ao 26: nem transcrição nem resumo existem.
  unsupportedOS,

  unavailable;

  static SummaryAvailability fromName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => SummaryAvailability.unavailable,
  );

  bool get isAvailable => this == SummaryAvailability.available;

  /// O que a interface diz quando o resumo não pode acontecer.
  String? get explanation => switch (this) {
    SummaryAvailability.available => null,
    SummaryAvailability.deviceNotEligible =>
      'Este Mac não tem Apple Intelligence, então o resumo não roda aqui. A '
          'transcrição funciona normalmente.',
    SummaryAvailability.appleIntelligenceNotEnabled =>
      'Ligue o Apple Intelligence nos Ajustes do Sistema para resumir.',
    SummaryAvailability.modelNotReady =>
      'O sistema ainda está preparando o modelo. Tente daqui a pouco.',
    SummaryAvailability.unsupportedOS =>
      'O Echo precisa do macOS 26 ou superior.',
    SummaryAvailability.unavailable =>
      'O modelo de resumo não está disponível agora.',
  };
}

/// Estado de uma permissão do macOS.
///
/// A distinção entre "ainda não perguntei" e "já negaram" não é burocracia: ela
/// decide o que o botão faz. Enquanto ninguém respondeu, pedir abre o diálogo
/// do sistema; depois de um "não", pedir não faz **nada** — a API responde na
/// hora, calada, e o único caminho que sobra é abrir os Ajustes.
enum PermissionStatus {
  granted,
  notDetermined,
  denied;

  static PermissionStatus fromName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => PermissionStatus.denied,
  );

  bool get isGranted => this == PermissionStatus.granted;

  /// O verbo do botão: pedir de verdade, ou levar aos Ajustes.
  String get actionLabel =>
      this == PermissionStatus.notDetermined ? 'Permitir' : 'Abrir Ajustes';
}

/// O que esta máquina permite ao Echo, para a interface nunca oferecer o
/// impossível.
class EchoCapabilities {
  const EchoCapabilities({
    this.microphone = PermissionStatus.notDetermined,
    this.screenRecording = PermissionStatus.notDetermined,
    this.summaries = SummaryAvailability.unavailable,
  });

  /// Grava a sua voz. Sem ela, falta você na transcrição.
  final PermissionStatus microphone;

  /// Dá acesso ao áudio que sai do computador — a fala das outras pessoas. Sem
  /// ela faltam todos os outros, o que não é uma reunião.
  ///
  /// Concedê-la **não vale na hora**: o macOS só entrega a captura de tela a um
  /// processo que subiu depois da permissão. Por isso a tela pede para reabrir
  /// o Evergreen em vez de insistir que falta permissão.
  final PermissionStatus screenRecording;

  final SummaryAvailability summaries;

  bool get canRecord => microphone.isGranted && screenRecording.isGranted;

  factory EchoCapabilities.fromMap(Map<Object?, Object?> map) =>
      EchoCapabilities(
        microphone: PermissionStatus.fromName(map['microphone'] as String?),
        screenRecording: PermissionStatus.fromName(
          map['screenRecording'] as String?,
        ),
        summaries: SummaryAvailability.fromName(map['summaries'] as String?),
      );
}

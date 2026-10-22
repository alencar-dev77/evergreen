import '../../shared/utils/byte_size.dart';

/// Uma permissão do macOS, como o diagnóstico a conta.
enum DiagnosticPermission {
  granted('concedida'),
  denied('negada'),
  notDetermined('ainda não pedida'),

  /// O Echo, abaixo do macOS 26: o sistema nem chega a ser perguntado, e
  /// "negada" acusaria quem não negou nada.
  unavailable('não se aplica (macOS abaixo do 26)'),

  /// O canal não respondeu.
  unknown('não deu para saber');

  const DiagnosticPermission(this.label);

  final String label;
}

/// O que se sabe do Evergreen e do Mac no momento do "Copiar diagnóstico".
///
/// Só identidade e estado — versão, sistema, quem está ligado, que permissão
/// existe. Nada do que a pessoa guardou.
class DiagnosticSnapshot {
  const DiagnosticSnapshot({
    required this.appVersion,
    required this.macOS,
    required this.chip,
    required this.modules,
    required this.accessibility,
    required this.microphone,
    required this.screenRecording,
    required this.databaseBytes,
    required this.logTail,
    this.localModel = 'Apple Intelligence',
  });

  final String appVersion;
  final String macOS;
  final String chip;

  /// Nome de cada módulo e se ele está ligado, na ordem da barra lateral.
  final List<(String, bool)> modules;

  final DiagnosticPermission accessibility;
  final DiagnosticPermission microphone;
  final DiagnosticPermission screenRecording;

  /// Nulo quando a medida falhou.
  final int? databaseBytes;

  final List<String> logTail;

  /// Quem escreve os resumos — "Apple Intelligence", "LM Studio · Qwen3.5 4B".
  /// Nome de modelo, nunca texto de quem usa.
  final String localModel;
}

/// O texto que o "Copiar diagnóstico" põe na área de transferência.
///
/// Markdown, porque o destino de costume é uma issue do GitHub: os títulos
/// separam, e o registro vai num bloco de código, que preserva o recuo da
/// pilha.
abstract final class DiagnosticReport {
  static String render(DiagnosticSnapshot snapshot) {
    final buffer = StringBuffer()
      ..writeln('## Diagnóstico do Evergreen')
      ..writeln()
      ..writeln('- Versão: ${_or(snapshot.appVersion)}')
      ..writeln('- macOS: ${_or(snapshot.macOS)}')
      ..writeln('- Chip: ${_or(snapshot.chip)}')
      ..writeln(
        '- Banco: ${snapshot.databaseBytes == null ? 'não deu para medir' : ByteSize.compact(snapshot.databaseBytes!)}',
      )
      ..writeln('- Modelo local: ${snapshot.localModel}')
      ..writeln()
      ..writeln('### Módulos')
      ..writeln();

    for (final (name, isEnabled) in snapshot.modules) {
      buffer.writeln('- $name: ${isEnabled ? 'ligado' : 'desligado'}');
    }

    buffer
      ..writeln()
      ..writeln('### Permissões')
      ..writeln()
      ..writeln('- Acessibilidade: ${snapshot.accessibility.label}')
      ..writeln('- Microfone: ${snapshot.microphone.label}')
      ..writeln('- Gravação de tela: ${snapshot.screenRecording.label}')
      ..writeln()
      ..writeln('### Últimas linhas do registro')
      ..writeln();

    if (snapshot.logTail.isEmpty) {
      buffer.writeln('O registro está vazio.');
    } else {
      buffer
        ..writeln('```')
        ..writeAll(snapshot.logTail, '\n')
        ..writeln()
        ..writeln('```');
    }

    return buffer.toString();
  }

  static String _or(String value) => value.isEmpty ? 'desconhecido' : value;
}

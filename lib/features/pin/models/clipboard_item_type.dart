import '../../../shared/widgets/eg_icon.dart';

/// Tipos de conteúdo que o Pin reconhece na v0.1.
///
/// A classificação é heurística e feita uma única vez, no momento da captura —
/// o resultado é persistido junto do item para que a lista não precise
/// reclassificar nada ao renderizar.
enum ClipboardItemType {
  text('Texto', EgIconData.document),
  link('Link', EgIconData.link),
  command('Comando', EgIconData.terminal);

  const ClipboardItemType(this.label, this.icon);

  /// Rótulo exibido no preview do item.
  final String label;

  /// Ícone do badge de tipo.
  final EgIconData icon;

  static ClipboardItemType fromName(String name) => values.firstWhere(
        (type) => type.name == name,
        orElse: () => ClipboardItemType.text,
      );
}

/// Classifica um conteúdo copiado em [ClipboardItemType].
abstract final class ClipboardItemClassifier {
  /// Executáveis comuns de terminal. Cobre o dia a dia de desenvolvimento sem
  /// tentar ser um parser de shell.
  static const _commandPrefixes = <String>{
    'git', 'flutter', 'dart', 'npm', 'npx', 'yarn', 'pnpm', 'bun',
    'cd', 'ls', 'mkdir', 'rm', 'cp', 'mv', 'cat', 'touch', 'chmod', 'chown',
    'sudo', 'brew', 'docker', 'kubectl', 'ssh', 'scp', 'curl', 'wget',
    'python', 'python3', 'pip', 'pip3', 'node', 'go', 'cargo', 'make',
    'pod', 'xcodebuild', 'open', 'grep', 'find', 'sed', 'awk', 'echo', 'export',
  };

  static final _urlPattern = RegExp(
    r'^(https?://|www\.)[^\s]+$',
    caseSensitive: false,
  );

  static ClipboardItemType classify(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return ClipboardItemType.text;

    if (_urlPattern.hasMatch(trimmed)) return ClipboardItemType.link;

    if (_looksLikeCommand(trimmed)) return ClipboardItemType.command;

    return ClipboardItemType.text;
  }

  static bool _looksLikeCommand(String trimmed) {
    // Comandos são de uma linha só; blocos de várias linhas viram texto.
    if (trimmed.contains('\n')) return false;

    final firstToken = trimmed.split(RegExp(r'\s+')).first;

    // `$ git status` — prompt copiado junto.
    if (firstToken == r'$' || firstToken == '>') return true;

    return _commandPrefixes.contains(firstToken);
  }
}

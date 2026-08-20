import '../../../shared/widgets/eg_icon.dart';

/// Tipos de conteúdo que o Pin reconhece.
///
/// A classificação é heurística e feita uma única vez, no momento da captura —
/// o resultado é persistido junto do item para que a lista não precise
/// reclassificar nada ao renderizar. Quando esta lista muda, o histórico já
/// guardado é reclassificado uma vez (ver [ClipboardItemClassifier.version]).
///
/// A ordem dos valores é a ordem em que os tipos aparecem no filtro do overlay:
/// do mais comum para o mais específico.
enum ClipboardItemType {
  text('Texto', 'Textos', EgIconData.document),
  link('Link', 'Links', EgIconData.link),
  email('E-mail', 'E-mails', EgIconData.envelope),
  phone('Telefone', 'Telefones', EgIconData.phone),
  taxId('CPF', 'CPF', EgIconData.identityCard),
  command('Comando', 'Comandos', EgIconData.terminal);

  const ClipboardItemType(this.label, this.filterLabel, this.icon);

  /// Rótulo exibido no preview do item ("Link · copiado agora").
  final String label;

  /// Rótulo da pílula de filtro.
  ///
  /// Plural porque ali ele nomeia um conjunto ("me mostre os links"), não um
  /// item — menos "CPF", que não pluraliza sem virar gíria de cartório.
  final String filterLabel;

  /// Ícone do badge de tipo.
  final EgIconData icon;

  static ClipboardItemType fromName(String name) => values.firstWhere(
        (type) => type.name == name,
        orElse: () => ClipboardItemType.text,
      );
}

/// Classifica um conteúdo copiado em [ClipboardItemType].
abstract final class ClipboardItemClassifier {
  /// Versão do classificador, gravada junto de cada item.
  ///
  /// Existe porque o tipo é decidido na captura: sem um número para comparar,
  /// tudo que já estava no histórico ficaria com a classificação da versão em
  /// que foi copiado — e um filtro novo nasceria vazio para quem usa o Pin há
  /// meses, que é justamente quem tem histórico. Subir este número faz o
  /// repositório reclassificar o que ficou para trás, uma vez só.
  ///
  /// - **1** — texto, link e comando.
  /// - **2** — e-mail, telefone e CPF.
  static const version = 2;

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

  /// Um arroba no meio, um ponto depois dele e nenhum espaço em lugar nenhum.
  /// Não é a RFC 5322 — é o que distingue um e-mail de uma frase que por acaso
  /// tem arroba.
  static final _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@.]+\.[^\s@]{2,}$',
    caseSensitive: false,
  );

  /// CPF pontuado, exatamente como o site da Receita escreve.
  static final _formattedTaxIdPattern = RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$');

  /// Onze dígitos secos — o CPF "para colar em campo que não aceita ponto".
  static final _bareTaxIdPattern = RegExp(r'^\d{11}$');

  /// Só dígitos e os separadores com que se escreve telefone.
  ///
  /// O ponto fica de fora de propósito: telefone brasileiro não se escreve com
  /// ponto, e aceitá-lo faria `192.168.0.1` — que todo mundo copia — virar
  /// telefone de oito dígitos.
  static final _phoneShapePattern = RegExp(r'^\+?[\d\s()-]+$');

  static final _separatorPattern = RegExp(r'[\s()-]');
  static final _nonDigitPattern = RegExp(r'\D');

  static ClipboardItemType classify(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return ClipboardItemType.text;

    if (_urlPattern.hasMatch(trimmed)) return ClipboardItemType.link;

    if (_emailPattern.hasMatch(trimmed)) return ClipboardItemType.email;

    // CPF antes de telefone, e não o contrário: um celular com DDD tem os
    // mesmos onze dígitos de um CPF sem pontos, e o que desempata é o dígito
    // verificador — que só o CPF tem como provar. Um telefone que por acaso
    // passe na conta é um em cada cem; um CPF classificado como telefone seria
    // a regra, não a exceção.
    if (_looksLikeTaxId(trimmed)) return ClipboardItemType.taxId;

    if (_looksLikePhone(trimmed)) return ClipboardItemType.phone;

    if (_looksLikeCommand(trimmed)) return ClipboardItemType.command;

    return ClipboardItemType.text;
  }

  static bool _looksLikeTaxId(String trimmed) {
    final isFormatted = _formattedTaxIdPattern.hasMatch(trimmed);
    if (!isFormatted && !_bareTaxIdPattern.hasMatch(trimmed)) return false;

    return _hasValidTaxIdCheckDigits(trimmed.replaceAll(_nonDigitPattern, ''));
  }

  /// Os dois dígitos verificadores do CPF, pelo algoritmo da Receita: cada bloco
  /// é a soma ponderada dos dígitos anteriores, módulo 11.
  static bool _hasValidTaxIdCheckDigits(String digits) {
    if (digits.length != 11) return false;

    // `111.111.111-11` e companhia passam na conta dos módulos, mas não são
    // CPF de ninguém — e são exatamente o tipo de sequência que aparece num
    // histórico de área de transferência (senha, código, número de teste).
    if (digits.split('').toSet().length == 1) return false;

    for (var position = 9; position < 11; position++) {
      var sum = 0;
      for (var index = 0; index < position; index++) {
        sum += int.parse(digits[index]) * (position + 1 - index);
      }

      final remainder = (sum * 10) % 11;
      final expected = remainder == 10 ? 0 : remainder;
      if (expected != int.parse(digits[position])) return false;
    }

    return true;
  }

  static bool _looksLikePhone(String trimmed) {
    if (!_phoneShapePattern.hasMatch(trimmed)) return false;

    final digits = trimmed.replaceAll(_nonDigitPattern, '');

    // Com separador (parênteses, hífen, espaço ou o `+` do país) oito dígitos
    // bastam: quem escreve `3456-7890` está escrevendo um telefone. Sem nenhum
    // separador o piso sobe para dez, senão qualquer código de rastreio ou
    // número de nota fiscal viraria telefone.
    final hasSeparator =
        _separatorPattern.hasMatch(trimmed) || trimmed.startsWith('+');
    final minimum = hasSeparator ? 8 : 10;

    // O teto é o formato internacional cheio: `+55 (11) 98765-4321`.
    return digits.length >= minimum && digits.length <= 13;
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

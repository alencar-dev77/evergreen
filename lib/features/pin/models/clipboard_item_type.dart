import '../../../shared/widgets/eg_icon.dart';
import 'tax_id.dart';

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
  cpf('CPF', 'CPF', EgIconData.identityCard),
  cnpj('CNPJ', 'CNPJ', EgIconData.building),
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

/// A qual tipo do Pin cada documento corresponde.
///
/// Mora aqui, e não no `tax_id.dart`, para a dependência andar num sentido só:
/// o modelo dos documentos não precisa saber que existe um histórico de área
/// de transferência, e é o histórico que precisa saber traduzir.
extension TaxIdItemType on TaxIdKind {
  ClipboardItemType get itemType => switch (this) {
    TaxIdKind.cpf => ClipboardItemType.cpf,
    TaxIdKind.cnpj => ClipboardItemType.cnpj,
  };
}

/// E a volta: qual documento vive atrás de um tipo, quando vive algum.
///
/// É o que decide se a pílula tem um gerador dentro dela — e, por ser um lugar
/// só, acrescentar um terceiro documento um dia não deixa metade do app sabendo
/// dele e a outra metade não.
extension ClipboardItemTypeTaxId on ClipboardItemType {
  TaxIdKind? get taxIdKind => switch (this) {
    ClipboardItemType.cpf => TaxIdKind.cpf,
    ClipboardItemType.cnpj => TaxIdKind.cnpj,
    _ => null,
  };
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
  /// - **3** — CNPJ. Sobe porque o tipo é novo: sem isto, todo CNPJ já copiado
  ///   continuaria guardado como texto, e a pílula nasceria vazia justamente
  ///   para quem tem histórico. (O gerador de CPF, que não mexeu em
  ///   classificação nenhuma, deliberadamente não subiu a versão.)
  static const version = 3;

  /// Executáveis comuns de terminal. Cobre o dia a dia de desenvolvimento sem
  /// tentar ser um parser de shell.
  static const _commandPrefixes = <String>{
    'git',
    'flutter',
    'dart',
    'npm',
    'npx',
    'yarn',
    'pnpm',
    'bun',
    'cd',
    'ls',
    'mkdir',
    'rm',
    'cp',
    'mv',
    'cat',
    'touch',
    'chmod',
    'chown',
    'sudo',
    'brew',
    'docker',
    'kubectl',
    'ssh',
    'scp',
    'curl',
    'wget',
    'python',
    'python3',
    'pip',
    'pip3',
    'node',
    'go',
    'cargo',
    'make',
    'pod',
    'xcodebuild',
    'open',
    'grep',
    'find',
    'sed',
    'awk',
    'echo',
    'export',
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

    // CPF e CNPJ antes de telefone, e não o contrário: um celular com DDD tem
    // os mesmos onze dígitos de um CPF sem pontos, e o que desempata é o dígito
    // verificador — que só o documento tem como provar. Um telefone que por
    // acaso passe na conta é um em cada cem; um CPF classificado como telefone
    // seria a regra, não a exceção.
    //
    // O CNPJ seco tem quatorze dígitos e passaria longe do telefone de qualquer
    // forma, mas ele entra pela mesma porta porque a pergunta é uma só: quem
    // decide entre os dois documentos é a própria [TaxId], que conhece as duas
    // contas — a tabela de qual é qual não se repete aqui.
    final kind = TaxId.looksLike(trimmed);
    if (kind != null) return kind.itemType;

    if (_looksLikePhone(trimmed)) return ClipboardItemType.phone;

    if (_looksLikeCommand(trimmed)) return ClipboardItemType.command;

    return ClipboardItemType.text;
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

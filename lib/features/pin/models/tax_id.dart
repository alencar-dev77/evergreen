import 'dart:math' as math;

/// Os dois documentos que o Pin reconhece, valida e sabe sortear.
///
/// O que os separa é só o tamanho e a régua de pesos: a conta do dígito
/// verificador — a soma ponderada módulo 11 da Receita — é literalmente a
/// mesma, e está escrita uma vez só em [TaxId._checkDigit]. Foi para não ter
/// duas cópias dela que o módulo 11 saiu de dentro do classificador; ter duas
/// de novo, uma por documento, desfaria o motivo.
enum TaxIdKind {
  /// Onze dígitos, `000.000.000-00`.
  ///
  /// Os pesos descem de `baseLength + 1` até 2, sem repetir: nove dígitos cabem
  /// inteiros na faixa de 2 a 10, então não há o que ciclar.
  cpf(label: 'CPF', baseLength: 9),

  /// Quatorze dígitos, `00.000.000/0000-00`.
  ///
  /// Aqui os pesos **ciclam** de 2 a 9 e recomeçam: doze dígitos não cabem numa
  /// faixa de oito, e é essa a única diferença de verdade entre as duas contas.
  cnpj(label: 'CNPJ', baseLength: 12);

  const TaxIdKind({required this.label, required this.baseLength});

  /// Como o documento se chama na interface — "Gerar CPF", "Gerar CNPJ".
  final String label;

  /// Quantos dígitos vêm antes dos dois verificadores.
  final int baseLength;

  /// O documento inteiro, verificadores incluídos.
  int get length => baseLength + 2;

  /// O peso do dígito de índice [index] no cálculo do verificador da posição
  /// [position].
  ///
  /// É o único ponto em que CPF e CNPJ discordam.
  int weightAt(int position, int index) => switch (this) {
    // 10, 9, 8, … 2 — e um a mais no segundo dígito, que tem uma casa a mais.
    TaxIdKind.cpf => position + 1 - index,
    // 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 — a mesma descida, dando a volta.
    TaxIdKind.cnpj => ((position - 1 - index) % 8) + 2,
  };
}

/// CPF e CNPJ: reconhecer um, validar os dígitos verificadores e sortear um
/// novo.
///
/// Os três são a mesma conta — a soma ponderada módulo 11 da Receita —, e é por
/// isso que vivem juntos. Ela nasceu privada dentro do
/// `ClipboardItemClassifier`, que só precisava responder "isto é um CPF?"; o
/// gerador precisa da mesma conta ao contrário, para *produzir* os dois dígitos
/// em vez de conferi-los. Duas cópias do mesmo módulo 11 é o tipo de coisa que
/// se desencontra em silêncio: o gerador passaria a produzir números que o
/// próprio Pin classificaria como texto.
///
/// O CNPJ entrou depois, e entrou **por dentro**: um segundo arquivo com a
/// mesma soma escrita de novo seria o mesmo risco de desencontro, só que agora
/// entre dois documentos em vez de entre validar e gerar.
abstract final class TaxId {
  /// As duas maneiras de escrever cada documento: pontuado como a Receita
  /// escreve, e seco para colar em campo que não aceita pontuação.
  static final _patterns = {
    TaxIdKind.cpf: (
      formatted: RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$'),
      bare: RegExp(r'^\d{11}$'),
    ),
    TaxIdKind.cnpj: (
      formatted: RegExp(r'^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$'),
      bare: RegExp(r'^\d{14}$'),
    ),
  };

  static final _nonDigitPattern = RegExp(r'\D');

  /// Qual documento o texto é, ou `null` se não é nenhum dos dois.
  ///
  /// A forma sozinha não basta: onze dígitos são também um celular com DDD, e o
  /// que desempata é justamente a conta.
  static TaxIdKind? looksLike(String trimmed) {
    for (final kind in TaxIdKind.values) {
      final patterns = _patterns[kind]!;
      if (!patterns.formatted.hasMatch(trimmed) &&
          !patterns.bare.hasMatch(trimmed)) {
        continue;
      }

      final digits = trimmed.replaceAll(_nonDigitPattern, '');
      if (isValid(digits, kind)) return kind;
    }

    return null;
  }

  /// Os dígitos formam um documento válido do tipo [kind].
  ///
  /// Espera o número já sem pontuação — quem tem um texto na mão pergunta por
  /// [looksLike].
  static bool isValid(String digits, TaxIdKind kind) {
    if (!_patterns[kind]!.bare.hasMatch(digits)) return false;

    // `111.111.111-11` e companhia passam na conta dos módulos, mas não são
    // documento de ninguém — e são exatamente o tipo de sequência que aparece
    // num histórico de área de transferência (senha, código, número de teste).
    if (_isRepeated(digits)) return false;

    for (var position = kind.baseLength; position < kind.length; position++) {
      if (_checkDigit(digits, position, kind) != int.parse(digits[position])) {
        return false;
      }
    }

    return true;
  }

  /// Sorteia um documento válido do tipo [kind], pontuado.
  ///
  /// Pontuado porque é como a Receita escreve e como um campo com máscara
  /// espera receber — e porque o classificador reconhece as duas formas, o
  /// número volta ao histórico como o tipo certo de qualquer jeito.
  ///
  /// [random] existe para o teste poder fixar a semente: sem ela, "o gerado é
  /// sempre válido" só se verifica por amostragem.
  static String generate(TaxIdKind kind, {math.Random? random}) {
    final rng = random ?? math.Random();

    // Repete enquanto a base for toda de dígitos iguais: dela sai um número
    // inteiro de dígitos iguais, que a própria [isValid] recusa — o documento
    // gerado entraria no histórico classificado como texto.
    String base;
    do {
      base = List.generate(kind.baseLength, (_) => rng.nextInt(10)).join();
    } while (_isRepeated(base));

    var digits = base;
    for (var position = kind.baseLength; position < kind.length; position++) {
      digits += '${_checkDigit(digits, position, kind)}';
    }

    return format(digits, kind);
  }

  /// Escreve os dígitos como a Receita escreve: `000.000.000-00` para o CPF,
  /// `00.000.000/0000-00` para o CNPJ.
  static String format(String digits, TaxIdKind kind) => switch (kind) {
    TaxIdKind.cpf =>
      '${digits.substring(0, 3)}.${digits.substring(3, 6)}'
          '.${digits.substring(6, 9)}-${digits.substring(9)}',
    TaxIdKind.cnpj =>
      '${digits.substring(0, 2)}.${digits.substring(2, 5)}'
          '.${digits.substring(5, 8)}/${digits.substring(8, 12)}'
          '-${digits.substring(12)}',
  };

  /// O dígito verificador da posição [position], calculado sobre tudo o que vem
  /// antes dela.
  ///
  /// É a conta única deste arquivo, e ela **não muda entre CPF e CNPJ** — só os
  /// pesos mudam, e quem os dá é [TaxIdKind.weightAt]. [isValid] compara o
  /// resultado com o que está escrito, [generate] anexa o resultado ao que
  /// ainda não tem.
  ///
  /// O resto vira dígito como `11 - resto`, e não pelo `(soma * 10) % 11` com
  /// que o CPF nasceu aqui: os dois dão exatamente o mesmo número (multiplicar
  /// por dez, módulo onze, é o mesmo que negar), e esta é a forma que a Receita
  /// publica para os dois documentos.
  static int _checkDigit(String digits, int position, TaxIdKind kind) {
    var sum = 0;
    for (var index = 0; index < position; index++) {
      sum += int.parse(digits[index]) * kind.weightAt(position, index);
    }

    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  static bool _isRepeated(String digits) => digits.split('').toSet().length == 1;
}

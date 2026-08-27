import 'dart:math' as math;

/// O CPF: reconhecer um, validar os dígitos verificadores e sortear um novo.
///
/// Os três são a mesma conta — a soma ponderada módulo 11 da Receita —, e é por
/// isso que vivem juntos. Ela nasceu privada dentro do
/// `ClipboardItemClassifier`, que só precisava responder "isto é um CPF?"; o
/// gerador precisa da mesma conta ao contrário, para *produzir* os dois dígitos
/// em vez de conferi-los. Duas cópias do mesmo módulo 11 é o tipo de coisa que
/// se desencontra em silêncio: o gerador passaria a produzir números que o
/// próprio Pin classificaria como texto.
abstract final class TaxId {
  /// CPF pontuado, exatamente como o site da Receita escreve.
  static final _formattedPattern = RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$');

  /// Onze dígitos secos — o CPF "para colar em campo que não aceita ponto".
  static final _barePattern = RegExp(r'^\d{11}$');

  static final _nonDigitPattern = RegExp(r'\D');

  /// Quantos dígitos vêm antes dos dois verificadores.
  static const _baseLength = 9;

  /// O texto tem forma de CPF **e** os dígitos verificadores fecham.
  ///
  /// A forma sozinha não basta: onze dígitos são também um celular com DDD, e o
  /// que desempata é justamente a conta.
  static bool looksLike(String trimmed) {
    if (!_formattedPattern.hasMatch(trimmed) &&
        !_barePattern.hasMatch(trimmed)) {
      return false;
    }

    return isValid(trimmed.replaceAll(_nonDigitPattern, ''));
  }

  /// Os onze dígitos formam um CPF válido.
  ///
  /// Espera o número já sem pontuação — quem tem um texto na mão pergunta por
  /// [looksLike].
  static bool isValid(String digits) {
    if (!_barePattern.hasMatch(digits)) return false;

    // `111.111.111-11` e companhia passam na conta dos módulos, mas não são CPF
    // de ninguém — e são exatamente o tipo de sequência que aparece num
    // histórico de área de transferência (senha, código, número de teste).
    if (_isRepeated(digits)) return false;

    for (var position = _baseLength; position < 11; position++) {
      if (_checkDigit(digits, position) != int.parse(digits[position])) {
        return false;
      }
    }

    return true;
  }

  /// Sorteia um CPF válido, pontuado.
  ///
  /// Pontuado porque é como a Receita escreve e como um campo com máscara
  /// espera receber — e porque o classificador reconhece as duas formas, o
  /// número volta ao histórico como CPF de qualquer jeito.
  ///
  /// [random] existe para o teste poder fixar a semente: sem ela, "o gerado é
  /// sempre válido" só se verifica por amostragem.
  static String generate({math.Random? random}) {
    final rng = random ?? math.Random();

    // Repete enquanto os nove primeiros forem todos iguais: dessa base sai um
    // número de onze dígitos iguais, que a própria [isValid] recusa — o CPF
    // gerado entraria no histórico classificado como texto.
    String base;
    do {
      base = List.generate(_baseLength, (_) => rng.nextInt(10)).join();
    } while (_isRepeated(base));

    var digits = base;
    for (var position = _baseLength; position < 11; position++) {
      digits += '${_checkDigit(digits, position)}';
    }

    return format(digits);
  }

  /// Escreve os onze dígitos como `000.000.000-00`.
  static String format(String digits) =>
      '${digits.substring(0, 3)}.${digits.substring(3, 6)}'
      '.${digits.substring(6, 9)}-${digits.substring(9)}';

  /// O dígito verificador da posição [position] (9 ou 10), calculado sobre tudo
  /// o que vem antes dela.
  ///
  /// É a conta única deste arquivo: [isValid] compara o resultado com o que
  /// está escrito, [generate] anexa o resultado ao que ainda não tem.
  static int _checkDigit(String digits, int position) {
    var sum = 0;
    for (var index = 0; index < position; index++) {
      sum += int.parse(digits[index]) * (position + 1 - index);
    }

    final remainder = (sum * 10) % 11;
    return remainder == 10 ? 0 : remainder;
  }

  static bool _isRepeated(String digits) => digits.split('').toSet().length == 1;
}

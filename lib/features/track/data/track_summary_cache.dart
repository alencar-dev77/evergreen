import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o parágrafo que o modelo local escreveu sobre um dia.
///
/// **Não é uma tabela, e é de propósito.** O Track não escreve no banco: ele é
/// uma leitura sobre o que os outros módulos gravaram, e é essa fronteira que
/// faz cada módulo novo alimentá-lo de graça. O parágrafo não contraria isso
/// porque ele não é dado de ninguém — é derivado do que já está lá e se refaz
/// sozinho. Por isso mora no plist das preferências, com o resto do que é
/// barato de perder, e por isso não entra no backup nem na exportação.
///
/// O que ele evita é gastar o modelo de novo para reescrever a mesma frase: o
/// Hub fecha e abre dezenas de vezes por dia, e a região de leitura de ontem
/// sempre descreve o mesmo ontem — um dia que já passou não muda mais.
class TrackSummaryCache {
  TrackSummaryCache(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'track.summaries';

  /// Quantos dias ficam guardados.
  ///
  /// Duas semanas cobrem os dois recortes da tela ("Hoje" e "Semana") com folga
  /// para a semana anterior ainda estar quente. Sem teto, o plist acumularia um
  /// parágrafo por dia para sempre — e um dia de três meses atrás não tem nem
  /// como ser aberto, porque o histórico do Focus já zerou faz tempo.
  static const maxDays = 14;

  static const _signatureField = 's';
  static const _textField = 't';

  /// O parágrafo guardado para [date], se ele ainda descrever o dia.
  ///
  /// [signature] é a do dia agora (ver `TrackDay.signature`): um resumo escrito
  /// antes da última sessão de foco fala de um dia que não é mais este, e um
  /// resumo que contradiz os números ao lado é pior que resumo nenhum.
  String? read(DateTime date, String signature) {
    final entry = _all()[_dayKey(date)];
    if (entry is! Map) return null;
    if (entry[_signatureField] != signature) return null;

    final text = entry[_textField];
    return text is String && text.trim().isNotEmpty ? text : null;
  }

  Future<void> write(DateTime date, String signature, String text) {
    final all = _all()
      ..[_dayKey(date)] = {_signatureField: signature, _textField: text};

    return _prefs.setString(_key, jsonEncode(_trimmed(all)));
  }

  Map<String, dynamic> _all() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      // Plist mexido à mão ou escrito por uma versão que formatava diferente:
      // é cache, e cache que não se entende se joga fora em silêncio.
      return {};
    }
  }

  /// Os [maxDays] dias mais recentes. As chaves são `aaaa-mm-dd`, então a ordem
  /// alfabética é a cronológica.
  Map<String, dynamic> _trimmed(Map<String, dynamic> all) {
    if (all.length <= maxDays) return all;

    final keys = all.keys.toList()..sort();
    final excess = keys.take(all.length - maxDays);

    return {
      for (final entry in all.entries)
        if (!excess.contains(entry.key)) entry.key: entry.value,
    };
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

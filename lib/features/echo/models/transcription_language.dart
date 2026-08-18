/// Idiomas oferecidos para a transcrição.
///
/// Transcrição no idioma errado não sai pior — sai inútil, porque o modelo
/// tenta encaixar o que ouviu nas palavras do idioma que você escolheu. Por
/// isso a escolha é explícita, e não uma adivinhação a partir do idioma do
/// sistema: reunião em inglês acontece numa máquina em português o tempo todo.
///
/// O sistema suporta cerca de trinta idiomas; estes são os que cabem num
/// seletor sem virar uma lista de rolagem. O modelo de cada um é baixado sob
/// demanda na primeira vez (`EchoChannel.installLanguage`).
enum TranscriptionLanguage {
  ptBR('pt-BR', 'Português (Brasil)'),
  ptPT('pt-PT', 'Português (Portugal)'),
  enUS('en-US', 'Inglês'),
  esES('es-ES', 'Espanhol');

  const TranscriptionLanguage(this.locale, this.label);

  /// Identificador BCP-47, como o `SpeechTranscriber` espera.
  final String locale;

  final String label;

  /// Rótulo curto para o seletor, onde não cabe o nome inteiro.
  String get shortLabel => switch (this) {
    TranscriptionLanguage.ptBR => 'PT-BR',
    TranscriptionLanguage.ptPT => 'PT-PT',
    TranscriptionLanguage.enUS => 'EN',
    TranscriptionLanguage.esES => 'ES',
  };

  static TranscriptionLanguage fromLocale(String locale) => values.firstWhere(
    (language) => language.locale == locale,
    orElse: () => TranscriptionLanguage.ptBR,
  );
}

/// Em que pé está o resumo que o Echo está escrevendo — se está escrevendo um.
///
/// O trabalho acontece no engine da janela flutuante e a tela que o mostra vive
/// no Hub, em outro engine: este objeto é o que atravessa o canal entre os
/// dois. Por isso ele é pequeno, imutável e sabe virar mapa — nada aqui pode
/// depender de estar do mesmo lado de quem o criou.
class EchoSummaryStatus {
  const EchoSummaryStatus({
    this.meetingId,
    this.done = 0,
    this.total = 0,
    this.errorMessage,
  });

  /// A reunião sendo resumida agora, ou `null` quando não há trabalho em curso.
  final int? meetingId;

  /// Bloco atual e total de blocos — "bloco 2 de 4". Um texto que cabe numa
  /// chamada só tem `total` 1, e a tela mostra "Resumindo…" em vez da contagem.
  final int done;
  final int total;

  /// A falha do último resumo pedido, até alguém pedir outro.
  ///
  /// Sobrevive ao fim do trabalho de propósito: quem pediu o resumo pode ter
  /// fechado o Hub e voltado, e a única chance de contar o que deu errado é
  /// quando ele reabre.
  final String? errorMessage;

  bool get isRunning => meetingId != null;

  Map<String, Object?> toMap() => {
    'meetingId': meetingId,
    'done': done,
    'total': total,
    'errorMessage': errorMessage,
  };

  static EchoSummaryStatus fromMap(Map<Object?, Object?> map) {
    return EchoSummaryStatus(
      meetingId: map['meetingId'] as int?,
      done: map['done'] as int? ?? 0,
      total: map['total'] as int? ?? 0,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

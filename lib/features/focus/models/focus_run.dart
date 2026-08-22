import 'package:flutter/foundation.dart';

import 'focus_session_note.dart';

/// O rastro de uma sessão de foco em andamento.
///
/// Existe por uma razão só: o cronômetro do Focus vive na memória do engine da
/// janela flutuante, e o que está na memória morre com o aplicativo. Encerrar o
/// Evergreen aos vinte minutos de uma sessão apagava os vinte minutos — o
/// histórico só era escrito no fim, e o fim nunca chegava. Num módulo cuja
/// única entrega é o registro, essa era a pior perda possível.
///
/// É gravado de tempos em tempos enquanto a sessão corre (ver o batimento no
/// `FocusTimerViewModel`) e lido uma vez, na abertura seguinte do aplicativo.
/// Não é histórico: assim que a sessão termina por um caminho normal, o rastro
/// é apagado.
///
/// Só a fase de **foco** deixa rastro. A pausa não entra no histórico, então
/// uma pausa interrompida não tem o que recuperar.
@immutable
class FocusRun {
  const FocusRun({
    required this.startedAt,
    required this.focused,
    this.activity = '',
    this.notes = const [],
  });

  final DateTime startedAt;

  /// Quanto a sessão tinha corrido no último batimento.
  ///
  /// É tempo **acumulado pelo cronômetro**, não `agora - startedAt`: uma sessão
  /// pausada para de acumular, e o que passou com o Mac dormindo nunca entra.
  /// Por isso a recuperação não precisa saber quando o aplicativo morreu — o
  /// último batimento já é a resposta.
  final Duration focused;

  final String activity;

  final List<FocusSessionNote> notes;
}

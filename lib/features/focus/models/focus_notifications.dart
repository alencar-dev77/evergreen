import '../../../core/system/notification_service.dart';
import '../../../shared/utils/duration_format.dart';
import 'focus_phase.dart';
import 'focus_settings.dart';

/// O aviso de fim de fase do Focus — só quando o tempo acaba sozinho.
///
/// Encerrar pelo botão não avisa: quem encerrou está olhando para o painel.
/// O som é o da própria notificação, quando `playSound` está ligado — era um
/// `NSBeep` à parte, e o aviso chegava mudo: o beep sai pelo dispositivo e pelo
/// volume de *alerta*, que nem sempre é por onde se está ouvindo. O beep só
/// sobrou para quando a notificação não sai (ver `_onFocusFinished`).
abstract final class FocusNotifications {
  /// Um id só para as duas fases: o fim da pausa substitui o aviso do fim do
  /// foco, que a essa altura já não diz nada.
  static const id = 'focus.finished';

  static const startRest = 'focus.start_rest';
  static const startFocus = 'focus.start_focus';

  static EgNotification finished({
    required FocusPhase phase,
    required Duration focused,
    required String activity,
    required FocusSettings settings,
  }) {
    final subject = activity.trim();

    if (phase.isFocus) {
      return EgNotification(
        id: id,
        thread: 'focus',
        title: 'Sessão concluída',
        subtitle: subject,
        sound: settings.playSound,
        body:
            '${DurationFormat.compact(focused)} de foco. '
            'Hora de levantar — a pausa é de ${settings.breakMinutes} min.',
        actions: const [EgNotificationAction(startRest, 'Começar pausa')],
      );
    }

    return EgNotification(
      id: id,
      thread: 'focus',
      title: 'Fim da pausa',
      subtitle: subject,
      sound: settings.playSound,
      body: subject.isEmpty
          ? 'Pronto para mais ${settings.focusMinutes} min de foco?'
          : 'Pronto para mais ${settings.focusMinutes} min em $subject?',
      actions: const [EgNotificationAction(startFocus, 'Começar sessão')],
    );
  }
}

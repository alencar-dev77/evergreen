import '../../../core/system/notification_service.dart';
import '../../../shared/utils/duration_format.dart';
import 'awake_duration.dart';
import 'awake_mode.dart';

/// O aviso de que o prazo do Awake venceu e a trava foi solta.
///
/// Só no prazo vencido: desligar pelo painel é uma decisão que a pessoa acabou
/// de tomar, e avisá-la disso seria repetir o clique dela.
abstract final class AwakeNotifications {
  static const id = 'awake.expired';
  static const again = 'awake.again';

  static EgNotification expired({
    required AwakeDuration duration,
    required AwakeMode mode,
  }) {
    final total = duration.duration;

    return EgNotification(
      id: id,
      thread: 'awake',
      title: 'Awake desligado',
      sound: true,
      subtitle: total == null
          ? ''
          : '${DurationFormat.compact(total)} acordado',
      body: mode.keepsScreenOn
          ? 'O prazo acabou — a tela já pode apagar de novo.'
          : 'O prazo acabou — o Mac já pode dormir de novo.',
      actions: [EgNotificationAction(again, 'Mais ${duration.label}')],
    );
  }
}

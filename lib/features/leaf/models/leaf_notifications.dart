import '../../../core/system/notification_service.dart';
import 'leaf_note.dart';

/// O lembrete de um cartão, como notificação do macOS.
///
/// O id carrega o id da anotação, e não a vaga: a vaga muda quando um cartão
/// de cima é arrancado, e o lembrete precisa continuar apontando para o mesmo
/// recado.
abstract final class LeafNotifications {
  static const _prefix = 'leaf.';
  static const snooze = 'leaf.snooze';

  /// Quanto o "Adiar" empurra.
  static const snoozeBy = Duration(minutes: 30);

  static String idOf(int noteId) => '$_prefix$noteId';

  /// O id da anotação por trás de uma notificação, ou `null` se não for do
  /// Leaf.
  static int? noteIdOf(String id) => id.startsWith(_prefix)
      ? int.tryParse(id.substring(_prefix.length))
      : null;

  /// O texto inteiro no corpo: é ele o lembrete. A primeira linha vira título
  /// quando o cartão tem mais de uma — "Ligar pro Marcos" lido de relance no
  /// canto da tela, o resto embaixo.
  static EgNotification of(LeafNote note) {
    final lines = note.content.split('\n');
    final hasTitle = lines.length > 1;

    return EgNotification(
      id: idOf(note.id),
      thread: 'leaf',
      title: hasTitle ? lines.first.trim() : 'Lembrete',
      body: hasTitle ? lines.skip(1).join('\n').trim() : note.content,
      sound: true,
      actions: const [EgNotificationAction(snooze, 'Adiar 30 min')],
    );
  }
}

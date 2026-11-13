import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'update_service.dart';

/// O aviso de que há uma versão nova do Evergreen.
abstract final class UpdateNotifications {
  static const id = 'app.update';
  static const showNotes = 'app.update.notes';

  static EgNotification available(String version, List<UpdateNote> notes) =>
      EgNotification(
        id: id,
        thread: 'app',
        title: 'Evergreen $version disponível',
        body: body(notes),
        actions: const [EgNotificationAction(showNotes, 'Ver novidades')],
      );

  /// A primeira novidade da lista, e quantas mais há — o que muda para quem
  /// usa é o que faz alguém querer atualizar, e não o número da versão.
  static String body(List<UpdateNote> notes) {
    final items = [
      for (final note in notes)
        if (note.kind == UpdateNoteKind.item) note.text,
    ];
    if (items.isEmpty) return 'Veja o que mudou e atualize quando quiser.';

    final rest = items.length - 1;
    return switch (rest) {
      0 => items.first,
      1 => '${items.first} — e mais 1 novidade.',
      _ => '${items.first} — e mais $rest novidades.',
    };
  }
}

/// Avisa pelo sistema quando o Sparkle acha uma versão nova.
///
/// O menu da barra e a bolinha do Hub já acendem, mas os dois só são vistos
/// por quem vai até eles — e o Evergreen passa o dia escondido na barra de
/// menus. A notificação não instala nada nem traz o app para a frente: o
/// clique leva às novidades, e a pergunta continua sendo a do cartão.
///
/// **Uma vez por versão, e não por procura**: o "Agora não" deixa a versão
/// anunciada, e o Sparkle a acha de novo a cada procura diária — avisar a
/// cada vez seria cobrança. Só uma versão mais nova avisa de novo. A versão
/// avisada fica no plist, então reiniciar o app ou o Mac não repete o aviso.
class UpdateNotifier {
  UpdateNotifier({
    required SharedPreferences preferences,
    required NotificationService notifications,
  }) : _preferences = preferences,
       _notifications = notifications;

  final SharedPreferences _preferences;
  final NotificationService _notifications;

  /// A última versão avisada ("1.1.14").
  static const _key = 'app.update_notified_version';

  UpdatePhase? _previous;

  /// Recebe cada estado que o atualizador avisa à janela 0.
  Future<void> observe(UpdateState state) async {
    final previous = _previous;
    _previous = state.phase;

    // O app vai fechar para instalar: o aviso já não vale, e clicado depois
    // levaria a um cartão de uma versão que já é a instalada.
    if (state.phase == UpdatePhase.installing) {
      await _notifications.cancel(const [UpdateNotifications.id]);
      return;
    }

    final version = state.version;
    if (state.phase != UpdatePhase.available || version == null) return;
    if (_preferences.getString(_key) == version) return;

    // Marcado antes de postar: o estado chega pelo aviso do canal e pela
    // primeira leitura, e os dois não podem avisar duas vezes — o
    // `setString` grava no cache antes de devolver.
    await _preferences.setString(_key, version);

    // Quem clicou em "Procurar" está olhando a resposta no Hub: a versão já
    // está na tela, e o aviso só repetiria o que ela diz.
    if (previous == UpdatePhase.checking) return;

    await _notifications.post(
      UpdateNotifications.available(version, state.notes),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../diagnostics/app_log.dart';

/// Em que passo do ciclo de atualização o Sparkle está.
enum UpdatePhase {
  /// Nada em curso, nada achado.
  idle,

  /// Procurando, a pedido de quem clicou em "Procurar".
  checking,

  /// Há versão nova, esperando o "Atualizar e reiniciar".
  available,

  /// Baixando a versão nova.
  downloading,

  /// Abrindo o `.dmg` baixado e conferindo a assinatura.
  extracting,

  /// O app vai fechar, instalar e abrir de novo.
  installing,

  /// A última procura não achou nada: está em dia.
  upToDate,

  /// A última procura ou instalação falhou.
  error;

  static UpdatePhase fromName(Object? name) =>
      values.firstWhere((phase) => phase.name == name, orElse: () => idle);

  /// A versão nova está sendo baixada ou instalada — a tela mostra o
  /// andamento, e o botão não aceita um segundo clique.
  bool get isBusy =>
      this == downloading || this == extracting || this == installing;
}

/// Uma linha das novidades, como o appcast as traz.
@immutable
class UpdateNote {
  const UpdateNote.heading(this.text) : kind = UpdateNoteKind.heading;
  const UpdateNote.item(this.text) : kind = UpdateNoteKind.item;
  const UpdateNote.paragraph(this.text) : kind = UpdateNoteKind.paragraph;

  final UpdateNoteKind kind;
  final String text;

  /// As notas do appcast, que o `./scripts/release` escreve a partir do
  /// `CHANGELOG.md`: um `<h3>` por versão, uma lista de `<li>` e um `<p>`
  /// solto às vezes. É esse HTML, e só ele, que se lê aqui — o Evergreen não
  /// desenha HTML de mais ninguém.
  static List<UpdateNote> parse(String? html) {
    if (html == null || html.trim().isEmpty) return const [];

    final pattern = RegExp(r'<(h3|li|p)>(.*?)</\1>', dotAll: true);

    return [
      for (final match in pattern.allMatches(html))
        if (_text(match.group(2)!) case final text when text.isNotEmpty)
          switch (match.group(1)) {
            'h3' => UpdateNote.heading(text),
            'li' => UpdateNote.item(text),
            _ => UpdateNote.paragraph(text),
          },
    ];
  }

  static String _text(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .trim();

  @override
  bool operator ==(Object other) =>
      other is UpdateNote && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}: $text';
}

enum UpdateNoteKind { heading, item, paragraph }

/// O que o atualizador sabe agora.
@immutable
class UpdateState {
  const UpdateState({
    this.available = false,
    this.automaticChecks = false,
    this.canCheck = false,
    this.lastCheck,
    this.phase = UpdatePhase.idle,
    this.version,
    this.notes = const [],
    this.progress,
  });

  /// Esta cópia se atualiza? Não numa build de desenvolvimento, nem em teste.
  final bool available;

  /// A procura diária está ligada. Desligada, nada sai do app.
  final bool automaticChecks;

  /// Dá para procurar agora — falso enquanto uma procura está em curso.
  final bool canCheck;

  /// A última vez que o Evergreen perguntou, se já perguntou.
  final DateTime? lastCheck;

  final UpdatePhase phase;

  /// A versão nova ("1.0.3"), quando há uma.
  final String? version;

  /// As novidades da versão nova.
  final List<UpdateNote> notes;

  /// De 0 a 1, enquanto baixa ou prepara; `null` quando não se sabe.
  final double? progress;

  /// Há versão nova anunciada — achada e ainda não instalada. É o que acende
  /// a bolinha e o item do menu.
  bool get hasUpdate =>
      version != null && (phase == UpdatePhase.available || phase.isBusy);

  factory UpdateState.fromMap(Map<Object?, Object?> map) {
    final lastCheckMs = map['lastCheckMs'];
    final progress = map['progress'];
    final version = map['version'];

    return UpdateState(
      available: map['available'] == true,
      automaticChecks: map['automaticChecks'] == true,
      canCheck: map['canCheck'] == true,
      lastCheck: lastCheckMs is int
          ? DateTime.fromMillisecondsSinceEpoch(lastCheckMs)
          : null,
      phase: UpdatePhase.fromName(map['phase']),
      version: version is String && version.isNotEmpty ? version : null,
      notes: UpdateNote.parse(map['notesHtml'] as String?),
      progress: progress is num ? progress.toDouble() : null,
    );
  }

  // Igualdade de valor: o Hub relê o estado de meio em meio segundo enquanto
  // algo anda, e uma releitura igual à anterior não pode redesenhar a tela.
  @override
  bool operator ==(Object other) =>
      other is UpdateState &&
      other.available == available &&
      other.automaticChecks == automaticChecks &&
      other.canCheck == canCheck &&
      other.lastCheck == lastCheck &&
      other.phase == phase &&
      other.version == version &&
      listEquals(other.notes, notes) &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(
    available,
    automaticChecks,
    canCheck,
    lastCheck,
    phase,
    version,
    Object.hashAll(notes),
    progress,
  );

  UpdateState copyWith({bool? automaticChecks}) => UpdateState(
    available: available,
    automaticChecks: automaticChecks ?? this.automaticChecks,
    canCheck: canCheck,
    lastCheck: lastCheck,
    phase: phase,
    version: version,
    notes: notes,
    progress: progress,
  );
}

/// A atualização do Evergreen, pelo Sparkle.
///
/// Interface pelo motivo do `NestFileService`: no relógio falso do teste de
/// widget a resposta do canal nativo nunca chega.
abstract interface class UpdateService {
  Future<UpdateState> state();

  /// Liga ou desliga a procura diária e devolve o estado já com a mudança.
  Future<UpdateState> setAutomaticChecks(bool enabled);

  /// Procura agora. O resultado chega pelo [state] — "está em dia", "não
  /// deu", ou a versão nova.
  Future<UpdateState> checkNow();

  /// Baixa, instala e reabre a versão anunciada.
  Future<UpdateState> install();

  /// Cada mudança que o lado nativo avisa. Só a janela 0 é avisada — ver
  /// `UpdaterChannel.swift`; o Hub pergunta pelo [state].
  Stream<UpdateState> get changes;
}

/// A conversa com o `UpdaterChannel` (`UpdaterChannel.swift`).
///
/// O atualizador é um só no processo, então tanto faz de qual engine se
/// pergunta: a resposta é a mesma.
class ChannelUpdateService implements UpdateService {
  ChannelUpdateService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('updater');

  final MethodChannel _channel;
  StreamController<UpdateState>? _changes;

  @override
  Future<UpdateState> state() => _ask('state');

  @override
  Future<UpdateState> setAutomaticChecks(bool enabled) =>
      _ask('setAutomaticChecks', enabled);

  @override
  Future<UpdateState> checkNow() => _ask('checkNow');

  @override
  Future<UpdateState> install() => _ask('install');

  @override
  Stream<UpdateState> get changes {
    final existing = _changes;
    if (existing != null) return existing.stream;

    final controller = StreamController<UpdateState>.broadcast();
    _changes = controller;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onState') return;
      final raw = call.arguments;
      if (raw is Map<Object?, Object?>) {
        controller.add(UpdateState.fromMap(raw));
      }
    });

    return controller.stream;
  }

  Future<UpdateState> _ask(String method, [Object? arguments]) async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        method,
        arguments,
      );
      return raw == null ? const UpdateState() : UpdateState.fromMap(raw);
    } on PlatformException catch (error) {
      AppLog.channelError('updater', method, error);
      return const UpdateState();
    } on MissingPluginException {
      return const UpdateState();
    }
  }
}

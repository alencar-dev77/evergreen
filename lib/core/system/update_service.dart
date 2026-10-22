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

  /// Pronta para instalar, esperando uma reunião do Echo terminar.
  waiting,

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
      this == downloading ||
      this == extracting ||
      this == waiting ||
      this == installing;
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
    this.resultAt,
  });

  /// Esta cópia se atualiza? Não numa build de desenvolvimento, nem em teste.
  final bool available;

  /// A procura diária está ligada. Desligada, só sai a que a pessoa pedir no
  /// "Procurar".
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

  /// Quando a última procura disse "em dia" ou "não deu".
  final DateTime? resultAt;

  /// O resultado ("em dia", "não deu") ainda é o da procura mais recente?
  ///
  /// Uma procura diária que termina calada (o Sparkle só fala das que acham
  /// algo) anda o [lastCheck] sem trocar a fase — e um "não deu" de três dias
  /// atrás não pode continuar na tela como se fosse o de agora.
  bool get hasFreshResult {
    final result = resultAt;
    final last = lastCheck;
    if (result == null) return false;
    return last == null || !result.isBefore(last);
  }

  /// Há versão nova anunciada — achada e ainda não instalada. É o que acende
  /// a bolinha e o item do menu.
  bool get hasUpdate =>
      version != null && (phase == UpdatePhase.available || phase.isBusy);

  factory UpdateState.fromMap(Map<Object?, Object?> map) {
    final lastCheckMs = map['lastCheckMs'];
    final progress = map['progress'];
    final version = map['version'];
    final resultMs = map['resultMs'];

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
      resultAt: resultMs is int
          ? DateTime.fromMillisecondsSinceEpoch(resultMs)
          : null,
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
      other.progress == progress &&
      other.resultAt == resultAt;

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
    resultAt,
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
    resultAt: resultAt,
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

  /// O Sparkle está pronto para fechar o app e instalar. Só a janela 0 ouve:
  /// ela faz a limpeza do "Encerrar" e responde com [proceedInstall] — ou com
  /// [waitForMeeting], se uma reunião do Echo estiver em curso.
  Stream<void> get installRequests;

  Future<void> proceedInstall();

  Future<UpdateState> waitForMeeting();
}

/// A conversa com o `UpdaterChannel` (`UpdaterChannel.swift`).
///
/// O atualizador é um só no processo, então tanto faz de qual engine se
/// pergunta: a resposta é a mesma.
class ChannelUpdateService implements UpdateService {
  ChannelUpdateService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('updater');

  final MethodChannel _channel;
  final _changes = StreamController<UpdateState>.broadcast();
  final _installRequests = StreamController<void>.broadcast();
  bool _listening = false;

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
    _listen();
    return _changes.stream;
  }

  @override
  Stream<void> get installRequests {
    _listen();
    return _installRequests.stream;
  }

  @override
  Future<void> proceedInstall() async {
    try {
      await _channel.invokeMethod<void>('proceedInstall');
    } on PlatformException catch (error) {
      AppLog.channelError('updater', 'proceedInstall', error);
    } on MissingPluginException {
      // Sem lado nativo: em teste, ou fora do macOS.
    }
  }

  @override
  Future<UpdateState> waitForMeeting() => _ask('waitForMeeting');

  /// Atende o que o lado nativo manda — uma vez só por canal, e só quem
  /// pede os avisos (a janela 0).
  void _listen() {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onState':
          final raw = call.arguments;
          if (raw is Map<Object?, Object?>) {
            _changes.add(UpdateState.fromMap(raw));
          }
        case 'prepareToInstall':
          _installRequests.add(null);
      }
    });
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

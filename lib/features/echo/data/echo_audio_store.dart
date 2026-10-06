import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/echo_audio_retention.dart';
import 'echo_repository.dart';

/// A pasta onde mora o áudio das reuniões.
///
/// Interface pelo motivo do `NestFileService`: teste de widget roda no relógio
/// falso do binding, e nele uma conversa assíncrona com o disco nunca termina.
/// A implementação de verdade é síncrona de propósito — são poucos arquivos,
/// e uma varredura que nunca devolve seria pior que uma que leva um
/// milissegundo.
abstract interface class EchoAudioStore {
  /// O caminho absoluto de um arquivo da pasta — é o que vai ao nativo, que
  /// escreve e toca.
  String pathOf(String fileName);

  bool exists(String fileName);

  void delete(String fileName);

  /// Os nomes que estão na pasta agora.
  List<String> list();
}

/// A pasta `Reuniões`, ao lado de `Backups` e `Exportações`.
///
/// Dentro da pasta do aplicativo pelo mesmo motivo das outras duas: ali o
/// macOS não pede permissão. E **fora do banco**, de propósito — o backup é
/// uma cópia do banco, e o áudio não entra nele.
class LocalEchoAudioStore implements EchoAudioStore {
  LocalEchoAudioStore(this.directory);

  final Directory directory;

  @override
  String pathOf(String fileName) => p.join(directory.path, fileName);

  @override
  bool exists(String fileName) => File(pathOf(fileName)).existsSync();

  @override
  void delete(String fileName) {
    final file = File(pathOf(fileName));
    if (file.existsSync()) file.deleteSync();
  }

  @override
  List<String> list() {
    if (!directory.existsSync()) return const [];

    return [
      for (final entity in directory.listSync())
        if (entity is File) p.basename(entity.path),
    ];
  }
}

/// Quem apaga o áudio que venceu, e o que ficou sem dono.
///
/// Uma regra só, que cobre todos os jeitos de uma reunião perder o áudio:
/// **arquivo que nenhuma linha quer é lixo**. Apagar a reunião, a limpeza do
/// teto de reuniões e o "Limpar histórico" só apagam a linha — o arquivo dela
/// vira órfão e sai na varredura seguinte. Ninguém precisa lembrar de apagar o
/// áudio em cada um desses caminhos.
///
/// O caminho inverso também é tratado: uma linha que aponta para um arquivo
/// que não existe (restauração de backup, que traz o banco e não o áudio) é
/// solta, para a tela não oferecer um player que não tem o que tocar.
class EchoAudioJanitor {
  const EchoAudioJanitor({
    required EchoRepository repository,
    required EchoAudioStore store,
  }) : _repository = repository,
       _store = store;

  final EchoRepository _repository;
  final EchoAudioStore _store;

  void sweep(DateTime now) {
    final wanted = <String>{};

    for (final ref in _repository.audioRefs()) {
      if (EchoAudioRetention.isExpired(ref, now)) {
        _store.delete(ref.fileName);
        _repository.setAudioFile(ref.meetingId, null);
      } else if (!_store.exists(ref.fileName)) {
        _repository.setAudioFile(ref.meetingId, null);
      } else {
        wanted.add(ref.fileName);
      }
    }

    for (final name in _store.list()) {
      if (!wanted.contains(name)) _store.delete(name);
    }
  }
}

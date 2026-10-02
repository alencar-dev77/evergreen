import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/nest_channel.dart';
import '../../data/nest_destinations.dart';
import '../../data/nest_file_service.dart';
import '../../data/nest_settings_repository.dart';
import '../../models/nest_destination.dart';
import '../../models/nest_settings.dart';
import '../../models/nest_transfer_mode.dart';

final nestSettingsViewModelProvider =
    NotifierProvider<NestSettingsViewModel, NestSettings>(
      NestSettingsViewModel.new,
    );

/// Preferências do Nest, com escrita imediata.
///
/// Igual às dos outros módulos: mexer no controle já persiste, sem botão de
/// salvar e sem confirmação de "salvo".
class NestSettingsViewModel extends Notifier<NestSettings> {
  late final NestSettingsRepository _repository;
  late final NestChannel _channel;
  late final NestFileService _files;

  @override
  NestSettings build() {
    _repository = ref.watch(nestSettingsRepositoryProvider);
    _channel = ref.watch(nestChannelProvider);
    _files = ref.watch(nestFileServiceProvider);

    // A conferência é assíncrona e a tela não espera por ela: a lista aparece
    // na hora, com os caminhos como foram gravados, e as pastas que sumiram se
    // marcam um quadro depois. O contrário — segurar a tela até o disco
    // responder — é a armadilha que o `NestFileService` existe para evitar.
    //
    // Os destinos vão por argumento, e não por `state`: aqui dentro do `build`
    // o estado ainda não existe, e lê-lo é erro de provider não inicializado.
    // O `Future` sem atraso é o que põe a conferência depois deste `build`.
    final loaded = _repository.load();
    unawaited(Future(() => _resolveDestinations(loaded.destinations)));

    return loaded;
  }

  /// Marca os favoritos cuja pasta não está mais lá. Ver [NestDestinations].
  Future<void> _resolveDestinations(List<NestDestination> destinations) async {
    final resolved = await NestDestinations.resolve(destinations, _files);
    if (identical(resolved, destinations)) return;

    // A tela pode ter sido fechada enquanto o disco respondia, e escrever no
    // estado de um provider já descartado é um erro, não um não-efeito.
    if (!ref.mounted) return;

    // Só o estado: `isMissing` é do disco, não do favorito, e regravar as
    // preferências por causa dele escreveria no arquivo a cada abertura.
    state = state.copyWith(destinations: resolved);
  }

  Future<void> setDefaultMode(NestTransferMode mode) async {
    state = state.copyWith(defaultMode: mode);
    await _repository.save(state);
  }

  Future<void> setUseShake({required bool enabled}) async {
    state = state.copyWith(useShake: enabled);
    await _repository.save(state);

    // O lado nativo é avisado na hora: quem observa o mouse vive fora de
    // qualquer engine, e esperar o próximo lançamento para desligá-lo deixaria
    // o interruptor mentindo até lá.
    await _channel.setShakeEnabled(enabled: enabled);
  }

  /// Abre o seletor de pasta do sistema e guarda o que voltar.
  ///
  /// Devolve `false` quando nada foi acrescentado — cancelou, a lista está
  /// cheia, ou a pasta já estava lá.
  Future<bool> addDestination() async {
    if (state.isFull) return false;

    final path = await _channel.chooseFolder();
    if (path == null) return false;
    if (state.destinations.any((destination) => destination.path == path)) {
      return false;
    }

    state = state.copyWith(
      destinations: [
        ...state.destinations,
        NestDestination(path: path),
      ],
    );
    await _repository.save(state);

    return true;
  }

  Future<void> removeDestination(int index) async {
    if (index < 0 || index >= state.destinations.length) return;

    final destinations = [...state.destinations]..removeAt(index);
    state = state.copyWith(destinations: destinations);
    await _repository.save(state);
  }

  /// O apelido da pasta — vazio devolve o nome dela.
  Future<void> renameDestination(int index, String alias) async {
    if (index < 0 || index >= state.destinations.length) return;

    final destinations = [...state.destinations];
    destinations[index] = destinations[index].copyWith(alias: alias.trim());

    state = state.copyWith(destinations: destinations);
    await _repository.save(state);
  }
}

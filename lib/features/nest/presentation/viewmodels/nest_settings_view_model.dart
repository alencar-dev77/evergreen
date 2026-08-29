import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/nest_channel.dart';
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

  @override
  NestSettings build() {
    _repository = ref.watch(nestSettingsRepositoryProvider);
    _channel = ref.watch(nestChannelProvider);

    return _repository.load();
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
      destinations: [...state.destinations, NestDestination(path: path)],
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

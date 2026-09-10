import '../models/nest_destination.dart';
import 'nest_file_service.dart';

/// Confere no disco se as pastas favoritas ainda estão onde foram cadastradas.
///
/// Existe fora dos dois ViewModels que a usam — o do painel e o da tela de
/// preferências — porque a pergunta é a mesma nos dois lugares e a resposta
/// precisa ser: uma lista que marca `⌘3` como perdido no painel e não o marca
/// nas preferências é pior que nenhuma das duas.
///
/// O favorito guarda **caminho de texto**, e é isso que torna a conferência
/// necessária: renomear a pasta no Finder não avisa ninguém, e o destino deixa
/// de existir em silêncio. Marcar não é apagar — quem cadastrou uma pasta num
/// disco externo espera encontrá-la de volta ao remontar, e um favorito que se
/// removesse sozinho levaria junto o apelido e a posição no `⌘1..⌘9`.
abstract final class NestDestinations {
  /// Os mesmos destinos, cada um com [NestDestination.isMissing] atualizado.
  ///
  /// Devolve a lista original quando nada mudou: a identidade preservada evita
  /// reconstruir a lista de preferências — cujas linhas guardam o campo de
  /// apelido em edição — a cada abertura de painel.
  static Future<List<NestDestination>> resolve(
    List<NestDestination> destinations,
    NestFileService files,
  ) async {
    if (destinations.isEmpty) return destinations;

    var changed = false;
    final resolved = <NestDestination>[];

    for (final destination in destinations) {
      final isMissing = !await files.exists(destination.path);
      changed = changed || isMissing != destination.isMissing;
      resolved.add(destination.copyWith(isMissing: isMissing));
    }

    return changed ? resolved : destinations;
  }
}

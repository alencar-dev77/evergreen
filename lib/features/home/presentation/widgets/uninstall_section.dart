import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../../shared/widgets/eg_settings_row.dart';

/// Desinstalar o Evergreen, no fim da tela do aplicativo.
///
/// Por último, e no cartão "Sem volta", pela ordem dos tópicos: ação
/// destrutiva vem depois de tudo o que se configura. A outra porta é o item do
/// menu da barra, que cai aqui com a pergunta já aberta — para quem quer tirar
/// o app sem procurar onde.
class UninstallSection extends ConsumerWidget {
  const UninstallSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EgSettingsCard(
      title: 'Sem volta',
      tone: EgCardTone.destructive,
      children: [
        EgSettingsRow(
          label: 'Desinstalar o Evergreen',
          description:
              'Apaga tudo o que ele guardou, tira o app dos Ajustes do '
              'Sistema e manda ele para o Lixo.',
          trailing: EgButton.destructive(
            label: 'Desinstalar',
            onPressed: () => unawaited(confirmUninstall(context, ref)),
          ),
        ),
      ],
    );
  }
}

/// Pergunta e, com o sim, desinstala.
///
/// Fora do widget porque são duas as portas: o botão da seção e o destino do
/// Hub pedido pelo menu da barra (`HubDestination.uninstall`).
///
/// A mensagem lista o que vai, e não um "todos os dados": quem desinstala para
/// reinstalar precisa saber que os backups vão junto — eles moram na pasta do
/// aplicativo —, e é antes da pergunta que se guarda um.
Future<void> confirmUninstall(BuildContext context, WidgetRef ref) async {
  // Uma pergunta só, venha de qual porta vier: o botão com a pergunta aberta
  // e o item do menu clicado por cima empilhariam dois diálogos — e cancelar
  // pediria dois cliques.
  if (_asking) return;
  _asking = true;

  // Antes da pergunta: enquanto ela está aberta, um destino de módulo pode
  // tirar a tela do aplicativo da árvore, e um `ref.read` de widget
  // desmontado lança — o sim não desinstalaria nada.
  final service = ref.read(uninstallServiceProvider);
  try {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Desinstalar o Evergreen?',
      message:
          'O histórico do Pin, as sessões, as anotações, as reuniões, os '
          'backups e as preferências são apagados. O Evergreen sai dos itens '
          'de início e das permissões dos Ajustes do Sistema, vai para o Lixo '
          'e fecha. Para guardar um backup, copie a pasta antes.',
      confirmLabel: 'Desinstalar',
    );
    if (!confirmed) return;

    await service.uninstall();
  } finally {
    _asking = false;
  }
}

/// A pergunta de desinstalar está na tela. Ver [confirmUninstall].
bool _asking = false;

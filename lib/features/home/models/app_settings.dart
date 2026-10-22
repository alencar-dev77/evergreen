import '../../../core/local_model/local_model.dart';

/// Preferências do Evergreen como aplicativo — as que não pertencem a módulo
/// nenhum.
class AppSettings {
  const AppSettings({
    this.userName = '',
    this.launchAtLogin = false,
    this.startMinimized = true,
    this.automaticBackup = true,
    this.localModel = LocalModelChoice.apple,
  });

  /// Como a pessoa se chama.
  ///
  /// É a única preferência do Evergreen que não liga nem desliga nada: ela
  /// existe para o **modelo local** ter como chamar quem está do outro lado.
  /// Sem ela, o resumo da reunião diz "a pessoa" e o parágrafo do Track diz "o
  /// usuário" — texto sobre você escrito por quem não sabe seu nome.
  ///
  /// Vazio é o estado normal de quem nunca preencheu, e tudo continua
  /// funcionando: o rótulo volta a ser "Você" e as instruções voltam a falar de
  /// "a pessoa". Nome não é requisito de nada.
  final String userName;

  /// Iniciar o Evergreen junto com o macOS.
  ///
  /// Começa desligado de propósito: registrar um item de início sem o usuário
  /// pedir seria intrusivo. O valor real é lido do sistema a cada inicialização.
  final bool launchAtLogin;

  /// Abrir minimizado, sem mostrar o Hub.
  final bool startMinimized;

  /// Guardar uma cópia do banco uma vez por semana.
  ///
  /// Começa **ligado**, ao contrário do [launchAtLogin]: registrar um item de
  /// início mexe no sistema da pessoa, enquanto o backup escreve um arquivo na
  /// pasta do próprio aplicativo e não passa de cinco. E o Evergreen não manda
  /// nada para lugar nenhum — se este banco se perder, não há de onde puxar de
  /// volta, então o padrão que protege é o que fica ligado.
  final bool automaticBackup;

  /// Quem escreve o resumo do Echo e o parágrafo do Track.
  ///
  /// Mora aqui, e não na tela do Echo, porque o Track também usa. O padrão é
  /// o Apple Intelligence: quem não mexe em nada não vê diferença.
  final LocalModelChoice localModel;

  AppSettings copyWith({
    String? userName,
    bool? launchAtLogin,
    bool? startMinimized,
    bool? automaticBackup,
    LocalModelChoice? localModel,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      startMinimized: startMinimized ?? this.startMinimized,
      automaticBackup: automaticBackup ?? this.automaticBackup,
      localModel: localModel ?? this.localModel,
    );
  }
}

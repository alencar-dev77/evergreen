/// Uma anotação do Leaf — o equivalente a um post-it colado na parede.
///
/// Curta e descartável de propósito: o Leaf é onde o pensamento é estacionado
/// enquanto a mão está ocupada com outra coisa, não onde ele mora. O que
/// precisa sobreviver a isso vira texto no Pin ou sai do Evergreen.
class LeafNote {
  const LeafNote({
    required this.id,
    required this.slot,
    required this.content,
    required this.createdAt,
  });

  final int id;

  /// Vaga que a anotação ocupa na parede, de 1 a [maxNotes].
  ///
  /// É a vaga que dá o número exibido no cartão e o `⌘N` que o copia. As vagas
  /// são sempre contíguas: apagar a anotação 2 faz a 3 virar 2, a 4 virar 3, e
  /// a parede encolher junto.
  ///
  /// A alternativa — deixar o buraco aberto para que `⌘3` sempre significasse a
  /// mesma anotação — foi tentada e descartada no uso: uma parede furada não
  /// diminui quando se joga coisa fora, e o ganho de memória muscular não paga
  /// olhar para vagas vazias no meio dela. Com nove cartões todos à vista, ler
  /// o número no cartão é mais rápido do que lembrar dele.
  final int slot;

  final String content;
  final DateTime createdAt;

  /// Teto da parede.
  ///
  /// Nove não é limitação técnica, é o produto: um bloco de anotações sem teto
  /// vira depósito, e o teto é o que obriga a jogar fora. Nove também é o
  /// alcance de `⌘1`–`⌘9`, a mesma gramática de atalho numérico do Pin.
  static const maxNotes = 9;

  /// Quantas anotações cabem em cada linha da grade.
  static const columns = 3;

  /// Tamanho máximo do texto.
  ///
  /// Calibrado pelo cartão, não pelo banco: em 240 caracteres corridos a
  /// anotação inteira aparece na grade sem corte, e é isso que sustenta a
  /// promessa de "tudo à vista de uma vez" — uma parede que esconde metade do
  /// que está escrita nela obriga a abrir cartão por cartão, que é justamente o
  /// que ela existe para evitar.
  ///
  /// Dá para o recado de uma reunião ("Marina fecha o contrato até sexta,
  /// cobrar o jurídico antes"), não para uma ata. O que precisa de mais que
  /// isso não é uma anotação rápida, e o Evergreen não é um editor de texto.
  ///
  /// Quebras de linha manuais (`⇧⏎`) gastam o resto da linha em que estão: com
  /// muitas delas o texto pode passar das nove linhas do cartão e ser cortado.
  /// É escolha de quem escreve, e o corte é discreto — o limite duro continua
  /// sendo o de caracteres.
  static const maxLength = 240;

  /// Todas as vagas possíveis, na ordem em que a grade as desenha.
  static const slots = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

  /// Normaliza o que veio do campo.
  ///
  /// Quebras de linha são preservadas — elas chegam por `⇧⏎` e são a forma de
  /// separar dois assuntos dentro do mesmo cartão. A linha em branco entre dois
  /// blocos também é preservada: quem digita `⇧⏎` duas vezes está separando
  /// assuntos de propósito, e engoli-la juntava os dois parágrafos na hora de
  /// guardar. O que some é o excesso: duas ou mais linhas vazias seguidas viram
  /// uma só, porque três linhas vazias no meio de um cartão de nove linhas
  /// gastam um terço do espaço sem dizer nada.
  static String sanitize(String raw) => raw
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  LeafNote copyWith({int? slot, String? content}) => LeafNote(
        id: id,
        slot: slot ?? this.slot,
        content: content ?? this.content,
        createdAt: createdAt,
      );
}

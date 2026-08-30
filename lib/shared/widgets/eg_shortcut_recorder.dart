import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import '../../core/system/shortcut_binding.dart';
import 'eg_button.dart';
import 'eg_key_cap.dart';

/// O controle que troca um atalho global: os key-caps em vigor e o botão que
/// põe a tela à escuta.
///
/// Ele **não decide nada** — não valida, não grava, não fala com o sistema. Ele
/// devolve a combinação que foi apertada e mostra o que mandarem mostrar; quem
/// aceita ou recusa é a `GlobalShortcutSection`, que tem o mapa dos outros
/// atalhos na mão. É a mesma divisão do resto do app: o widget desenha, a
/// ViewModel decide.
///
/// Enquanto grava, ele come **todas** as teclas. Não é zelo: o Hub tem um mapa
/// de atalhos no topo (o Esc que esconde a janela) e um `FocusScope` embaixo
/// dele, então um Esc que passasse reto fecharia a janela em vez de cancelar a
/// gravação — e uma seta moveria a seleção de outro controle enquanto a pessoa
/// tenta gravar `⌘⌥→`.
class EgShortcutRecorder extends StatefulWidget {
  const EgShortcutRecorder({
    super.key,
    required this.binding,
    required this.isRecording,
    required this.onStart,
    required this.onCancel,
    required this.onRecorded,
  });

  /// A combinação em vigor, desenhada em key-caps quando não se está gravando.
  final ShortcutBinding binding;

  final bool isRecording;

  /// "Alterar" foi apertado.
  final VoidCallback onStart;

  /// A gravação terminou sem combinação: Esc, o botão "Cancelar" ou o foco
  /// indo embora.
  final VoidCallback onCancel;

  /// Uma combinação foi apertada. Pode ser recusada por quem recebe — e por
  /// isso a gravação **continua** até alguém dizer que acabou.
  final ValueChanged<ShortcutBinding> onRecorded;

  @override
  State<EgShortcutRecorder> createState() => _EgShortcutRecorderState();
}

class _EgShortcutRecorderState extends State<EgShortcutRecorder> {
  final _focus = FocusNode(debugLabel: 'shortcut-recorder');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EgShortcutRecorder old) {
    super.didUpdateWidget(old);

    // O foco é o que faz as teclas chegarem aqui: sem ele o `onKeyEvent` não é
    // consultado e a gravação ficaria esperando para sempre uma tecla que
    // continua indo para o Hub.
    if (widget.isRecording && !old.isRecording) _focus.requestFocus();
    if (!widget.isRecording && old.isRecording && _focus.hasFocus) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  /// Clicar em outro lugar da tela cancela.
  ///
  /// É a mesma regra do campo de texto que guarda ao perder o foco, com o sinal
  /// trocado: aqui não há nada a guardar, e uma tela que ficasse à escuta
  /// depois de a pessoa ter ido cuidar de outra coisa engoliria o próximo Esc.
  void _onFocusChanged() {
    if (_focus.hasFocus || !widget.isRecording) return;
    widget.onCancel();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.isRecording) return KeyEventResult.ignored;

    // O Tab é a única tecla que sai daqui pelo caminho normal: quem tabula está
    // indo para o controle seguinte, e prender o foco seria prender a pessoa.
    if (event.physicalKey == PhysicalKeyboardKey.tab) {
      widget.onCancel();
      return KeyEventResult.ignored;
    }

    // Tudo o mais é consumido, inclusive o `KeyUpEvent` e a repetição: deixar
    // subir o "soltou o ⌘" de uma combinação que já foi gravada acorda os
    // atalhos do Hub no meio do gesto.
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    if (event.physicalKey == PhysicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }

    // Modificadora sozinha não é combinação — a pessoa está no meio do gesto,
    // segurando ⌘ antes de escolher a letra.
    if (ShortcutKeys.isModifier(event.physicalKey)) {
      return KeyEventResult.handled;
    }

    widget.onRecorded(
      ShortcutBinding(
        key: event.physicalKey,
        modifiers: ShortcutModifier.pressed(),
      ),
    );

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      // Nunca é parada de Tab: quem anda pela tela com o teclado quer o botão
      // ao lado, não uma caixa que não faz nada até ser ligada. Continua
      // podendo receber o foco por programa, que é como a gravação começa.
      //
      // Desligar `descendantsAreFocusable` ao gravar seria o caminho óbvio e
      // está errado: o botão que acabou de ser clicado é um descendente, e
      // arrancar o foco dele derruba o `hasFocus` deste nó — o que este widget
      // lê como "a pessoa foi embora" e cancela a gravação no mesmo quadro em
      // que ela começou.
      skipTraversal: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.isRecording ? _listening(context) : _caps(),
          const SizedBox(width: AppSpacing.md),
          EgButton.secondary(
            label: widget.isRecording ? 'Cancelar' : 'Alterar',
            onPressed: widget.isRecording ? widget.onCancel : widget.onStart,
          ),
        ],
      ),
    );
  }

  Widget _caps() => EgShortcutDisplay(keys: widget.binding.caps);

  /// A vaga do atalho enquanto se espera a combinação.
  ///
  /// Do tamanho de um key-cap e com a mesma moldura: o que muda é o conteúdo,
  /// não a linha — a tela não pode saltar quando a gravação começa.
  Widget _listening(BuildContext context) {
    return Semantics(
      label: 'Gravando atalho. Aperte a combinação, ou Escape para cancelar.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: context.eg.colors.card,
          borderRadius: context.eg.shapes.smallAll,
          border: Border.all(color: context.eg.colors.accent),
        ),
        child: Text(
          'Aperte a combinação',
          style: context.eg.text.monoSmall.copyWith(
            color: context.eg.colors.accent,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/nest_transfer_mode.dart';

/// Uma miniatura pronta, para o caminho que a pediu.
///
/// Chega mais de uma vez pelo mesmo caminho, e é de propósito: o QuickLook
/// responde em degraus (o ícone do tipo, uma prévia grosseira, a boa), e cada
/// resposta substitui a anterior no cartão. É o que faz um PDF de duzentas
/// páginas parecer instantâneo sem mentir sobre o que já foi lido.
@immutable
class NestThumbnail {
  const NestThumbnail({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

/// O que o Nest não consegue fazer em Flutter puro.
///
/// Quatro coisas, e nenhuma tem equivalente em Dart: receber um arraste do
/// Finder (é o delegate da `NSWindow` que recebe), gerar a miniatura de
/// um arquivo qualquer (`QLThumbnailGenerator`), abrir o seletor de pasta do
/// sistema (`NSOpenPanel`) e mandar para o Lixo com direito a desfazer do
/// Finder (`NSWorkspace.recycle`). A implementação está em
/// `macos/Runner/NestChannel.swift`.
///
/// Diferente do `EchoChannel`, nada aqui lança: sem lado nativo — em teste,
/// fora do macOS — cada método responde o vazio dele. O Nest sem o Swift é um
/// painel que não recebe arquivo, e é assim que a suíte de testes o vê.
class NestChannel {
  NestChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'nest';

  final MethodChannel _channel;

  final _dropped = StreamController<List<String>>.broadcast();
  final _dragOver = StreamController<bool>.broadcast();
  final _thumbnails = StreamController<NestThumbnail>.broadcast();
  final _dragOutEnded = StreamController<NestTransferMode?>.broadcast();
  final _shakes = StreamController<void>.broadcast();
  final _notch = StreamController<void>.broadcast();
  final _notchDragEnded = StreamController<void>.broadcast();
  final _pointerInside = StreamController<bool>.broadcast();

  /// Caminhos soltos sobre o painel.
  Stream<List<String>> get onDropped => _dropped.stream;

  /// O arraste entrou (`true`) ou saiu (`false`) da área que recebe.
  ///
  /// Serve para a borda do painel dizer "pode soltar" antes de o botão do mouse
  /// subir — sem isso, soltar num painel que não reagiu é um tiro no escuro.
  Stream<bool> get onDragOver => _dragOver.stream;

  Stream<NestThumbnail> get onThumbnail => _thumbnails.stream;

  /// Alguém chacoalhou um arquivo no meio de um arraste.
  ///
  /// Chega uma vez por aperto de botão: o lado nativo trava depois de avisar,
  /// senão um chacoalhar viraria três aberturas. Ver `NestDragMonitor`.
  Stream<void> get onShake => _shakes.stream;

  /// Alguém parou com um arquivo no notch.
  ///
  /// Uma vez por aperto de botão, como o chacoalhar — e os dois nunca no mesmo
  /// aperto: o primeiro que reconhecer o gesto trava o outro. Ver
  /// `NestDragMonitor`.
  Stream<void> get onNotch => _notch.stream;

  /// O arraste que chamou a prateleira pelo notch terminou — solto nela ou em
  /// qualquer outro lugar.
  Stream<void> get onNotchDragEnded => _notchDragEnded.stream;

  /// O cursor entrou (`true`) ou saiu (`false`) do painel do Nest na tela.
  ///
  /// Com o botão do mouse apertado conta como dentro: no meio de um arraste o
  /// cursor passa por fora do painel a caminho dele. É o que diz à pilha do
  /// notch quando recolher.
  Stream<bool> get onPointerInside => _pointerInside.stream;

  /// O arraste que saiu da prateleira terminou: com o que o destino fez, ou
  /// `null` quando ele foi solto em lugar nenhum.
  Stream<NestTransferMode?> get onDragOutEnded => _dragOutEnded.stream;

  /// Liga a escuta dos avisos do lado nativo. Uma vez, na inicialização.
  void listen() {
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;

      switch (call.method) {
        case 'onDropped':
          final paths = (arguments?['paths'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toList();
          if (paths.isNotEmpty && !_dropped.isClosed) _dropped.add(paths);

        case 'onDragOver':
          final isOver = arguments?['isOver'] as bool? ?? false;
          if (!_dragOver.isClosed) _dragOver.add(isOver);

        case 'onDragOutEnded':
          if (_dragOutEnded.isClosed) return;
          _dragOutEnded.add(switch (arguments?['operation']) {
            'copy' => NestTransferMode.copy,
            'move' => NestTransferMode.move,
            _ => null,
          });

        case 'onShake':
          if (!_shakes.isClosed) _shakes.add(null);

        case 'onNotch':
          if (!_notch.isClosed) _notch.add(null);

        case 'onNotchDragEnded':
          if (!_notchDragEnded.isClosed) _notchDragEnded.add(null);

        case 'onPointerInside':
          final inside = arguments?['inside'] as bool? ?? false;
          if (!_pointerInside.isClosed) _pointerInside.add(inside);

        case 'onThumbnail':
          final path = arguments?['path'] as String?;
          final bytes = arguments?['bytes'] as Uint8List?;
          if (path != null && bytes != null && !_thumbnails.isClosed) {
            _thumbnails.add(NestThumbnail(path: path, bytes: bytes));
          }
      }
    });
  }

  /// Liga ou desliga a detecção do chacoalhar.
  ///
  /// Desligada, o monitor de mouse sai do sistema — não fica um relógio parado
  /// esperando uma preferência que ninguém quer.
  Future<void> setShakeEnabled({required bool enabled}) =>
      _invoke<void>('setShakeEnabled', {'enabled': enabled});

  /// Liga ou desliga a porta do notch. Sem recorte na tela, ligada ou não, ela
  /// não reconhece nada.
  Future<void> setNotchEnabled({required bool enabled}) =>
      _invoke<void>('setNotchEnabled', {'enabled': enabled});

  /// Deixa a janela 0 aceitar arquivos.
  ///
  /// Ligado só enquanto o painel do Nest está à vista: a janela é
  /// compartilhada pelos seis módulos, e soltar um arquivo em cima do Focus
  /// não deve significar nada.
  Future<void> setDropEnabled({required bool enabled}) =>
      _invoke<void>('setDropEnabled', {'enabled': enabled});

  /// Diz onde o painel está desenhado dentro da janela 0 — ou `null` quando ele
  /// sai de cena.
  ///
  /// É o que faz a janela deixar o clique passar em toda a área **fora** do
  /// painel. A janela 0 é bem maior que qualquer painel e o resto dela é
  /// transparente mas ainda captura clique — o que nos outros painéis é o
  /// "clicar fora fecha", e no Nest impedia de clicar na janela do Finder de
  /// onde os arquivos viriam.
  Future<void> setInteractiveRect(Rect? rect) => _invoke<void>(
    'setInteractiveRect',
    rect == null
        ? null
        : {
            'x': rect.left,
            'y': rect.top,
            'width': rect.width,
            'height': rect.height,
          },
  );

  /// Começa a arrastar a prateleira para fora do Evergreen.
  ///
  /// Devolve `false` quando o lado nativo não conseguiu começar — sem o evento
  /// de mouse que originou o gesto não há sessão de arraste. O resultado chega
  /// depois, por [onDragOutEnded]. Com [move], o arraste sai como promessa de
  /// arquivo e quem move é o lado nativo — o destino só escolhe a pasta.
  Future<bool> beginDragOut(List<String> paths, {required bool move}) async =>
      await _invoke<bool>('beginDrag', {'paths': paths, 'move': move}) ?? false;

  /// Pede a miniatura de um arquivo. A resposta chega por [onThumbnail], em
  /// degraus.
  Future<void> requestThumbnail(String path, {double size = 96}) =>
      _invoke<void>('thumbnail', {'path': path, 'size': size});

  /// Abre o seletor de pasta do sistema. `null` quando a pessoa cancelou.
  Future<String?> chooseFolder() => _invoke<String>('chooseFolder');

  Future<void> revealInFinder(String path) =>
      _invoke<void>('revealInFinder', {'path': path});

  /// Manda para o Lixo — com o desfazer do Finder, e não `File.delete`, que
  /// apaga de verdade e não volta.
  Future<bool> moveToTrash(String path) async =>
      await _invoke<bool>('moveToTrash', {'path': path}) ?? false;

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      // O lado nativo recusou — pasta que sumiu entre o clique e a chamada,
      // arquivo sem permissão. Quem chama já trata o vazio, e derrubar o painel
      // por causa de um arquivo seria pior que não fazer nada.
      return null;
    } on MissingPluginException {
      // Sem lado nativo: em teste, ou fora do macOS.
      return null;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _dropped.close();
    _dragOutEnded.close();
    _shakes.close();
    _notch.close();
    _notchDragEnded.close();
    _pointerInside.close();
    _dragOver.close();
    _thumbnails.close();
  }
}

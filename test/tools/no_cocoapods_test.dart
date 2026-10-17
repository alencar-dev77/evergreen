import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A build macOS é só Swift Package Manager, e o CocoaPods volta sem avisar:
/// basta um `flutter pub get` que não ache o Xcode para o Flutter recriar o
/// `Podfile` e religar o Pods nos xcconfig e no projeto. O build seguinte
/// passa, com `pod install` no meio, e ninguém repara. Este teste é o aviso.
void main() {
  const fix =
      'O CocoaPods voltou. Apague macos/Podfile, Podfile.lock e Pods/, e '
      'restaure macos/Flutter/*.xcconfig e o project.pbxproj pelo git.';

  /// O que só a integração do CocoaPods escreve. A palavra solta "Pods" não
  /// serve: casaria com "AirPods" num comentário qualquer.
  const markers = [
    'Pods-Runner',
    'Pods_Runner',
    '[CP] ',
    'Target Support Files',
    'Pods.xcodeproj',
  ];

  test('não há Podfile, Podfile.lock nem Pods/ no projeto macOS', () {
    expect(File('macos/Podfile').existsSync(), isFalse, reason: fix);
    expect(File('macos/Podfile.lock').existsSync(), isFalse, reason: fix);
    expect(Directory('macos/Pods').existsSync(), isFalse, reason: fix);
  });

  for (final path in [
    'macos/Flutter/Flutter-Debug.xcconfig',
    'macos/Flutter/Flutter-Release.xcconfig',
    'macos/Runner.xcodeproj/project.pbxproj',
    'macos/Runner.xcworkspace/contents.xcworkspacedata',
  ]) {
    test('$path não tem integração do Pods', () {
      final text = File(path).readAsStringSync();
      for (final marker in markers) {
        expect(text, isNot(contains(marker)), reason: '$marker. $fix');
      }
    });
  }
}

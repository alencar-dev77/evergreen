# hotkey_manager_macos (vendorizado)

Cópia do [`hotkey_manager_macos` 0.2.0](https://github.com/leanflutter/hotkey_manager/tree/main/packages/hotkey_manager_macos)
(MIT, ver `LICENSE`) com um `Package.swift` no lugar do `.podspec`.

A 0.2.0 é a última versão publicada e só tem suporte a CocoaPods. O suporte a
Swift Package Manager precisa vir de dentro do plugin, e por isso ele mora
aqui. O `pubspec.yaml` do app o puxa por `dependency_overrides`.

O código Swift em `macos/hotkey_manager_macos/Sources/` é o do autor, com uma
linha a mais: o `import Cocoa` de `HotKeyExtension+NSEventModifierFlags.swift`,
que no CocoaPods chegava pelo módulo e no SPM precisa estar no arquivo.

**Quando sair uma versão do pub.dev com `Package.swift`**, apague esta pasta e
o `dependency_overrides`: confira com `flutter pub outdated`.

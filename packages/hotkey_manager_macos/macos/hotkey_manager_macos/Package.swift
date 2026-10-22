// swift-tools-version: 5.9

import PackageDescription

// O `hotkey_manager_macos` 0.2.0 do pub.dev só traz `.podspec`, e era o último
// plugin que segurava o CocoaPods no Evergreen. Este manifesto é a única coisa
// nossa no pacote: o código Swift é o do autor (ver o README, há uma linha a
// mais).
//
// O HotKey vai travado na mesma versão que o CocoaPods resolvia (0.2.1).
let package = Package(
    name: "hotkey_manager_macos",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "hotkey-manager-macos", targets: ["hotkey_manager_macos"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/soffes/HotKey.git", exact: "0.2.1"),
    ],
    targets: [
        .target(
            name: "hotkey_manager_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "HotKey", package: "HotKey"),
            ]
        )
    ]
)

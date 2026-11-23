// swift-tools-version: 6.2
import PackageDescription

// 画面に依存しない中心のロジック（シェイクの判定・棚の位置の計算・棚のデータ）をまとめたパッケージ
let package = Package(
    name: "PinshelfCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PinshelfCore", targets: ["PinshelfCore"]),
    ],
    targets: [
        .target(name: "PinshelfCore"),
        .testTarget(name: "PinshelfCoreTests", dependencies: ["PinshelfCore"]),
    ]
)

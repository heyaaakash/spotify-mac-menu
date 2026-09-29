// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpotMenu",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SpotMenu", targets: ["SpotMenu"])],
    targets: [.executableTarget(name: "SpotMenu", path: "Sources/SpotMenu")]
)

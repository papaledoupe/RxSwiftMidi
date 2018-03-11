// swift-tools-version:4.0

import PackageDescription

let package = Package(
        name: "RxSwiftMidi",
        products: [
            .library(name: "RxSwiftMidi", targets: ["RxSwiftMidi"])
        ],
        dependencies: [
            .package(url: "https://github.com/ReactiveX/RxSwift.git", "4.0.0"..<"5.0.0")
        ],
        targets: [
            .target(name: "RxSwiftMidi", dependencies: ["RxSwift"])
        ]
)

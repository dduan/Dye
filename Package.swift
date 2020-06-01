// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Dye",
    products: [.library(name: "Dye", targets: ["Dye"])],
    targets: [
        .target(name: "Dye"),
        .target(name: "example", dependencies: ["Dye"], path: "Examples", sources: ["main.swift"]),
    ]
)

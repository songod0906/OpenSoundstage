// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "OpenSoundstage",
    platforms: [.macOS("14.4")],
    products: [
        .library(name: "OpenSoundstageDSP", targets: ["OpenSoundstageDSP"]),
        .library(name: "OpenSoundstageCore", targets: ["OpenSoundstageCore"]),
        .executable(name: "OpenSoundstage", targets: ["OpenSoundstageApp"]),
    ],
    targets: [
        .target(name: "OpenSoundstageDSP"),
        .target(
            name: "OpenSoundstageCore",
            dependencies: ["OpenSoundstageDSP"],
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
            ]
        ),
        .executableTarget(
            name: "OpenSoundstageApp",
            dependencies: ["OpenSoundstageCore", "OpenSoundstageDSP"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "OpenSoundstageDSPTests",
            dependencies: ["OpenSoundstageDSP"]
        ),
    ]
)

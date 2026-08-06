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
    .target(
      name: "OpenSoundstageRealtime",
      publicHeadersPath: "include"
    ),
    .target(
      name: "OpenSoundstageDSP",
      linkerSettings: [.linkedFramework("Accelerate")]
    ),
    .target(
      name: "OpenSoundstageCore",
      dependencies: ["OpenSoundstageDSP", "OpenSoundstageRealtime"],
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
    .testTarget(
      name: "OpenSoundstageCoreTests",
      dependencies: ["OpenSoundstageCore", "OpenSoundstageDSP"]
    ),
  ]
)

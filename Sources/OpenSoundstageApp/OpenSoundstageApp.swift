// SPDX-License-Identifier: MIT

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.regular)
  }
}

@main
struct OpenSoundstageApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
    }
    .defaultSize(width: 1_020, height: 800)
    .windowResizability(.contentMinSize)

    MenuBarExtra("OpenSoundstage", systemImage: "waveform") {
      MenuContent(model: model)
    }
  }
}

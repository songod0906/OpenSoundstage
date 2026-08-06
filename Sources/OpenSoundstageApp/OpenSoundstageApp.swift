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
    .windowResizability(.contentSize)

    MenuBarExtra("OpenSoundstage", systemImage: "waveform") {
      MenuContent(model: model)
    }
  }
}

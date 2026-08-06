// SPDX-License-Identifier: MIT

import OpenSoundstageDSP
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            GroupBox("Sound") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Preset", selection: $model.preset) {
                        ForEach(SoundPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .disabled(model.isRunning)

                    control("Width", value: $model.settings.width, range: 1.0...1.65, format: "%.2f×")
                    control("Body", value: $model.settings.lowShelfDB, range: 0...4, format: "%+.1f dB")
                    control("Presence", value: $model.settings.presenceDB, range: -1...3, format: "%+.1f dB")
                    control("Air", value: $model.settings.airDB, range: 0...3, format: "%+.1f dB")
                    control("Controlled boost", value: $model.settings.inputGainDB, range: 0...5, format: "%+.1f dB")

                    HStack {
                        Button("Reset preset") { model.resetPreset() }
                            .disabled(model.isRunning)
                        Spacer()
                        Text(model.isRunning ? "Stop sound to change controls." : "Changes apply when sound starts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }

            GroupBox("Route") {
                HStack {
                    Image(systemName: model.isRunning ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.isRunning ? .green : .secondary)
                    VStack(alignment: .leading) {
                        Text(model.status)
                        Text(model.outputName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.isRunning ? "Stop sound" : "Start sound") {
                        model.toggle()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(8)
            }

            Text("Do not run Boom or another system audio enhancer at the same time. OpenSoundstage uses a temporary private route and removes it when you stop the app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(22)
        .frame(minWidth: 510, minHeight: 570)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenSoundstage")
                    .font(.title2.bold())
                Text("Wide sound. One coherent mix. No permanent driver.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func control(
        _ label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .disabled(model.isRunning)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.status)
        Text(model.outputName)
            .foregroundStyle(.secondary)
        Divider()
        Button(model.isRunning ? "Stop sound" : "Start sound") {
            model.toggle()
        }
        Button("Show OpenSoundstage") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

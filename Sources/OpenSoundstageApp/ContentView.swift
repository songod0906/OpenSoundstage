// SPDX-License-Identifier: MIT

import OpenSoundstageCore
import OpenSoundstageDSP
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(spacing: 16) {
          WaveformPanel(monitor: model.waveformMonitor, isRunning: model.isRunning)
          EqualizerPanel(model: model)
          lowerControls
          routeNote
        }
        .padding(20)
      }
    }
    .frame(minWidth: 900, idealWidth: 1_020, minHeight: 720, idealHeight: 800)
    .background(Color(nsColor: .windowBackgroundColor))
    .sheet(isPresented: $model.showsProductHealth) {
      ProductHealthView(model: model)
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(.blue.gradient)
        Image(systemName: "waveform.path")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 2) {
        Text("OpenSoundstage")
          .font(.title2.weight(.semibold))
        Text("System-wide sound, shaped on this Mac")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 8) {
        Circle()
          .fill(model.isRunning ? Color.green : Color.secondary.opacity(0.45))
          .frame(width: 8, height: 8)
        VStack(alignment: .trailing, spacing: 1) {
          Text(model.status)
            .font(.subheadline.weight(.medium))
          Text(model.outputName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Button {
        model.showsProductHealth = true
      } label: {
        Image(systemName: "chart.bar.xaxis")
      }
      .buttonStyle(.borderless)
      .help("Product health")

      Button(model.isRunning ? "Stop sound" : "Start sound") {
        model.toggle()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
  }

  private var lowerControls: some View {
    HStack(alignment: .top, spacing: 16) {
      settingsCard
      signalCard
    }
  }

  private var settingsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Soundstage", systemImage: "speaker.wave.3")
        .font(.headline)
      horizontalControl(
        "Stereo width", value: $model.settings.width, range: 1...1.65, format: "%.2f×"
      )
      horizontalControl(
        "Input gain", value: $model.settings.inputGainDB, range: 0...5, format: "%+.1f dB"
      )
    }
    .panelStyle()
    .disabled(model.isRunning)
  }

  private var signalCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Signal chain", systemImage: "point.3.connected.trianglepath.dotted")
        .font(.headline)
      Text("EQ → width → dynamics → -1 dBFS limiter")
        .font(.subheadline)
      Text(
        model.isRunning
          ? "Controls are locked to prevent filter changes inside an audio session."
          : "Settings apply when you start sound."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panelStyle()
  }

  private var routeNote: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let error = model.errorMessage {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .textSelection(.enabled)
      }
      Label(
        "Use one system audio processor at a time. The temporary route is removed when sound stops or the app quits.",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func horizontalControl(
    _ label: String,
    value: Binding<Float>,
    range: ClosedRange<Float>,
    format: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label)
          .font(.subheadline)
        Spacer()
        Text(String(format: format, value.wrappedValue))
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      Slider(value: value, in: range)
    }
  }
}

private struct EqualizerPanel: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("10-band equalizer")
            .font(.headline)
          Text("The curve is calculated from the same EQ coefficients as the audio engine.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Picker("Preset", selection: $model.preset) {
          ForEach(SoundPreset.allCases) { preset in
            Text(preset.rawValue).tag(preset)
          }
        }
        .labelsHidden()
        .frame(width: 130)
        .disabled(model.isRunning)
        Button("Flat") { model.flattenEqualizer() }
          .disabled(model.isRunning)
        Button("Reset") { model.resetPreset() }
          .disabled(model.isRunning)
      }

      FrequencyResponseView(settings: model.settings, sampleRate: model.sampleRate)
        .frame(height: 122)

      HStack(alignment: .top, spacing: 10) {
        ForEach(EqualizerBand.allCases) { band in
          VStack(spacing: 7) {
            Text(String(format: "%+.1f", model.settings[band]))
              .font(.caption2.monospacedDigit())
              .foregroundStyle(model.settings[band] == 0 ? .secondary : .primary)
            VerticalEQSlider(value: model.gainBinding(for: band), range: DSPSettings.equalizerRange)
              .frame(height: 152)
              .disabled(model.isRunning)
            Text(band.label)
              .font(.caption.monospacedDigit())
            Text("Hz")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .accessibilityElement(children: .contain)

      HStack {
        Text("−12 dB")
        Spacer()
        Text("Q 1.1 · \(model.sampleRate / 1_000, specifier: "%.1f") kHz engine rate")
        Spacer()
        Text("+12 dB")
      }
      .font(.caption2)
      .foregroundStyle(.tertiary)
    }
    .panelStyle()
  }
}

private struct VerticalEQSlider: View {
  @Binding var value: Float
  let range: ClosedRange<Float>
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    GeometryReader { proxy in
      let height = max(proxy.size.height - 14, 1)
      let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
      let knobY = 7 + height * (1 - progress)
      let zeroProgress = CGFloat((0 - range.lowerBound) / (range.upperBound - range.lowerBound))
      let zeroY = 7 + height * (1 - zeroProgress)

      ZStack {
        Capsule()
          .fill(.quaternary)
          .frame(width: 4, height: height)
        Rectangle()
          .fill(Color.secondary.opacity(0.45))
          .frame(width: 14, height: 1)
          .position(x: proxy.size.width / 2, y: zeroY)
        Capsule()
          .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.4))
          .frame(width: 4, height: abs(knobY - zeroY))
          .position(x: proxy.size.width / 2, y: (knobY + zeroY) / 2)
        Circle()
          .fill(isEnabled ? Color.accentColor : Color.secondary)
          .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
          .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
          .frame(width: 14, height: 14)
          .position(x: proxy.size.width / 2, y: knobY)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { gesture in
          guard isEnabled else { return }
          let position = min(max(gesture.location.y - 7, 0), height)
          let fraction = Float(1 - position / height)
          let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
          value = (raw * 2).rounded() / 2
        }
      )
    }
    .frame(minWidth: 24)
    .accessibilityElement()
    .accessibilityLabel("Equalizer gain")
    .accessibilityValue(String(format: "%+.1f decibels", value))
    .accessibilityAdjustableAction { direction in
      let step: Float = direction == .increment ? 0.5 : -0.5
      value = min(max(value + step, range.lowerBound), range.upperBound)
    }
  }
}

private struct FrequencyResponseView: View {
  let settings: DSPSettings
  let sampleRate: Float

  var body: some View {
    Canvas { context, size in
      let plot = CGRect(x: 35, y: 8, width: size.width - 45, height: size.height - 24)

      for decibels in stride(from: -12, through: 12, by: 6) {
        let y = yPosition(Float(decibels), in: plot)
        var line = Path()
        line.move(to: CGPoint(x: plot.minX, y: y))
        line.addLine(to: CGPoint(x: plot.maxX, y: y))
        context.stroke(
          line,
          with: .color(decibels == 0 ? .secondary.opacity(0.45) : .secondary.opacity(0.16)),
          lineWidth: decibels == 0 ? 1 : 0.5
        )
        context.draw(
          Text(decibels == 0 ? "0" : String(format: "%+d", decibels))
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary),
          at: CGPoint(x: 15, y: y)
        )
      }

      for frequency: Float in [20, 100, 1_000, 10_000, 20_000] {
        let x = xPosition(frequency, in: plot)
        var line = Path()
        line.move(to: CGPoint(x: x, y: plot.minY))
        line.addLine(to: CGPoint(x: x, y: plot.maxY))
        context.stroke(line, with: .color(.secondary.opacity(0.12)), lineWidth: 0.5)
      }

      var fill = Path()
      var curve = Path()
      for point in 0...320 {
        let fraction = Float(point) / 320
        let frequency = 20 * powf(1_000, fraction)
        let response = DSPPipeline.equalizerResponseDB(
          at: frequency,
          sampleRate: sampleRate,
          settings: settings
        )
        let position = CGPoint(
          x: plot.minX + CGFloat(fraction) * plot.width,
          y: yPosition(response, in: plot)
        )
        if point == 0 {
          curve.move(to: position)
          fill.move(to: CGPoint(x: position.x, y: yPosition(0, in: plot)))
        }
        curve.addLine(to: position)
        fill.addLine(to: position)
        if point == 320 {
          fill.addLine(to: CGPoint(x: position.x, y: yPosition(0, in: plot)))
          fill.closeSubpath()
        }
      }
      context.fill(
        fill,
        with: .linearGradient(
          Gradient(colors: [.blue.opacity(0.26), .blue.opacity(0.02)]),
          startPoint: CGPoint(x: 0, y: plot.minY),
          endPoint: CGPoint(x: 0, y: plot.maxY)
        ))
      context.stroke(curve, with: .color(.blue), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    }
    .background(
      Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 8)
    )
    .accessibilityLabel("Equalizer frequency response")
  }

  private func xPosition(_ frequency: Float, in rect: CGRect) -> CGFloat {
    rect.minX + CGFloat(log10f(frequency / 20) / 3) * rect.width
  }

  private func yPosition(_ decibels: Float, in rect: CGRect) -> CGFloat {
    let clipped = min(max(decibels, -12), 12)
    return rect.midY - CGFloat(clipped / 24) * rect.height
  }
}

private struct WaveformPanel: View {
  @ObservedObject var monitor: WaveformMonitor
  let isRunning: Bool

  private var snapshot: WaveformSnapshot { monitor.snapshot }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Post-DSP waveform")
            .font(.headline)
          Text("Actual output samples · fixed ±1.0 full-scale · no visual normalization")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        channelKey("L", color: .cyan, peak: snapshot.leftPeakDBFS, rms: snapshot.leftRMSDBFS)
        channelKey("R", color: .purple, peak: snapshot.rightPeakDBFS, rms: snapshot.rightRMSDBFS)
      }

      WaveformCanvas(snapshot: snapshot)
        .frame(height: 128)
        .overlay(alignment: .center) {
          if !isRunning {
            Text("Start sound to monitor the processed output")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.regularMaterial, in: Capsule())
          }
        }
    }
    .panelStyle()
  }

  private func channelKey(_ label: String, color: Color, peak: Float, rms: Float) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(label).font(.caption.weight(.semibold))
      Text(String(format: "P %.1f  R %.1f dBFS", peak, rms))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
  }
}

private struct WaveformCanvas: View {
  let snapshot: WaveformSnapshot

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 8)
      for amplitude: Float in [-1, -0.5, 0, 0.5, 1] {
        let y = rect.midY - CGFloat(amplitude) * rect.height / 2
        var line = Path()
        line.move(to: CGPoint(x: rect.minX, y: y))
        line.addLine(to: CGPoint(x: rect.maxX, y: y))
        context.stroke(
          line,
          with: .color(.secondary.opacity(amplitude == 0 ? 0.32 : 0.12)),
          lineWidth: amplitude == 0 ? 1 : 0.5
        )
      }
      draw(samples: snapshot.left, color: .cyan, in: rect, context: &context)
      draw(samples: snapshot.right, color: .purple.opacity(0.85), in: rect, context: &context)
    }
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.28), Color.black.opacity(0.15)],
        startPoint: .top,
        endPoint: .bottom
      ),
      in: RoundedRectangle(cornerRadius: 8)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityLabel("Live post-DSP stereo waveform")
  }

  private func draw(
    samples: [Float],
    color: Color,
    in rect: CGRect,
    context: inout GraphicsContext
  ) {
    guard samples.count > 1 else { return }
    var path = Path()
    for index in samples.indices {
      let x = rect.minX + CGFloat(index) / CGFloat(samples.count - 1) * rect.width
      let sample = min(max(samples[index], -1), 1)
      let y = rect.midY - CGFloat(sample) * rect.height / 2
      let point = CGPoint(x: x, y: y)
      index == samples.startIndex ? path.move(to: point) : path.addLine(to: point)
    }
    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
  }
}

private struct PanelStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(16)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(.separator.opacity(0.55), lineWidth: 0.5)
      )
  }
}

extension View {
  fileprivate func panelStyle() -> some View {
    modifier(PanelStyle())
  }
}

struct ProductHealthView: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Product health")
        .font(.title2.bold())
      Text("These metrics stay on this Mac. OpenSoundstage does not send analytics or audio.")
        .foregroundStyle(.secondary)

      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
        metric("App launches", value: "\(model.metrics.launchCount)")
        metric("Successful starts", value: "\(model.metrics.successfulStarts)")
        metric(
          "Start success",
          value: model.metrics.startAttempts == 0
            ? "—"
            : model.metrics.startSuccessRate.formatted(
              .percent.precision(.fractionLength(0))
            )
        )
        metric(
          "Enhanced time",
          value: Duration.seconds(model.metrics.enhancedSeconds).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated)
          )
        )
        metric("Route failures", value: "\(model.metrics.failedStarts)")
        metric("Output changes", value: "\(model.metrics.outputChanges)")
      }

      HStack {
        Button("Copy local report") { model.copyMetricsReport() }
        Button("Reset local metrics", role: .destructive) {
          model.resetMetrics()
        }
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 480)
  }

  private func metric(_ label: String, value: String) -> some View {
    GridRow {
      Text(label)
        .foregroundStyle(.secondary)
      Text(value)
        .monospacedDigit()
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

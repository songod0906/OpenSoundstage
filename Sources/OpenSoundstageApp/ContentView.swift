// SPDX-License-Identifier: MIT

import OpenSoundstageCore
import OpenSoundstageDSP
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    GeometryReader { proxy in
      let layout = MixerLayout(size: proxy.size)

      VStack(spacing: 0) {
        MixerHeader(model: model, compact: layout.isCompact)
        mixerConsole(layout: layout)
      }
      .background(MixerBackground())
    }
    .frame(minWidth: 760, idealWidth: 1_120, minHeight: 560, idealHeight: 720)
    .sheet(isPresented: $model.showsProductHealth) {
      ProductHealthView(model: model)
    }
  }

  private func mixerConsole(layout: MixerLayout) -> some View {
    VStack(spacing: layout.gap) {
      HStack(spacing: layout.gap) {
        WaveformDeck(
          monitor: model.waveformMonitor,
          isRunning: model.isRunning,
          compact: layout.isCompact
        )
        .frame(maxWidth: .infinity)

        ResponseDeck(
          settings: model.settings,
          sampleRate: model.sampleRate,
          compact: layout.isCompact
        )
        .frame(width: layout.responseWidth)
      }
      .frame(height: layout.analysisHeight)

      HStack(spacing: layout.gap) {
        EqualizerDeck(model: model, compact: layout.isCompact)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        MasterStrip(model: model, compact: layout.isCompact)
          .frame(width: layout.masterWidth)
          .frame(maxHeight: .infinity)
      }
      .frame(maxHeight: .infinity)
    }
    .padding(layout.padding)
  }
}

private struct MixerLayout {
  let isCompact: Bool
  let padding: CGFloat
  let gap: CGFloat
  let analysisHeight: CGFloat
  let responseWidth: CGFloat
  let masterWidth: CGFloat

  init(size: CGSize) {
    isCompact = size.width < 940 || size.height < 650
    padding = isCompact ? 12 : 18
    gap = isCompact ? 10 : 14
    analysisHeight = min(max((size.height - 64) * 0.28, 126), 206)
    responseWidth = min(max(size.width * 0.36, 260), 460)
    masterWidth = min(max(size.width * 0.23, 202), 286)
  }
}

private struct MixerBackground: View {
  var body: some View {
    ZStack {
      Color(nsColor: .windowBackgroundColor)
      LinearGradient(
        colors: [Color.accentColor.opacity(0.08), .clear, Color.purple.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    .ignoresSafeArea()
  }
}

private struct MixerHeader: View {
  @ObservedObject var model: AppModel
  let compact: Bool

  var body: some View {
    HStack(spacing: compact ? 10 : 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.accentColor.gradient)
        Image(systemName: "waveform.path.ecg")
          .font(.system(size: compact ? 18 : 21, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: compact ? 38 : 42, height: compact ? 38 : 42)

      VStack(alignment: .leading, spacing: 1) {
        Text("OpenSoundstage")
          .font((compact ? Font.headline : Font.title3).weight(.semibold))
        if !compact {
          Text("Native system-audio mixer")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 8)

      HStack(spacing: 7) {
        Circle()
          .fill(model.isRunning ? Color.green : Color.secondary.opacity(0.5))
          .frame(width: 8, height: 8)
          .shadow(color: model.isRunning ? .green.opacity(0.7) : .clear, radius: 4)
        VStack(alignment: .trailing, spacing: 0) {
          Text(model.status)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          if !compact {
            Text(model.outputName)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }

      Button {
        model.showsProductHealth = true
      } label: {
        Image(systemName: "chart.bar.xaxis")
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.borderless)
      .help("Product health")

      Button(model.isRunning ? "Stop" : "Start") {
        model.toggle()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(compact ? .regular : .large)
      .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, compact ? 12 : 18)
    .frame(height: compact ? 54 : 64)
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
  }
}

private struct WaveformDeck: View {
  @ObservedObject var monitor: WaveformMonitor
  let isRunning: Bool
  let compact: Bool

  private var snapshot: WaveformSnapshot { monitor.snapshot }

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 6 : 9) {
      HStack(spacing: 10) {
        MixerTitle("LIVE OUTPUT", systemImage: "waveform")
        Spacer()
        Text("POST DSP · ±1.0 FS")
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }

      WaveformCanvas(snapshot: snapshot)
        .overlay(alignment: .center) {
          if !isRunning {
            Text("START TO MONITOR")
              .font(.caption2.weight(.bold))
              .tracking(0.8)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(.regularMaterial, in: Capsule())
          }
        }

      StereoMeter(snapshot: snapshot)
        .frame(height: compact ? 22 : 28)
    }
    .mixerPanel(compact: compact)
  }
}

private struct StereoMeter: View {
  let snapshot: WaveformSnapshot

  var body: some View {
    HStack(spacing: 8) {
      meter(label: "L", peak: snapshot.leftPeakDBFS, rms: snapshot.leftRMSDBFS, color: .cyan)
      meter(label: "R", peak: snapshot.rightPeakDBFS, rms: snapshot.rightRMSDBFS, color: .purple)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      String(
        format: "Left peak %.1f RMS %.1f, right peak %.1f RMS %.1f decibels full scale",
        snapshot.leftPeakDBFS,
        snapshot.leftRMSDBFS,
        snapshot.rightPeakDBFS,
        snapshot.rightRMSDBFS
      )
    )
  }

  private func meter(label: String, peak: Float, rms: Float, color: Color) -> some View {
    HStack(spacing: 5) {
      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundStyle(color)
      GeometryReader { proxy in
        let rmsWidth = proxy.size.width * level(rms)
        let peakX = proxy.size.width * level(peak)
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule()
            .fill(
              LinearGradient(
                colors: [color.opacity(0.65), color, .orange],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: rmsWidth)
          Rectangle()
            .fill(peak > -1 ? Color.red : Color.white.opacity(0.9))
            .frame(width: 2)
            .offset(x: max(0, peakX - 1))
        }
      }
      Text(String(format: "%5.1f", peak))
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 34, alignment: .trailing)
    }
  }

  private func level(_ decibels: Float) -> CGFloat {
    CGFloat(min(max((decibels + 60) / 60, 0), 1))
  }
}

private struct ResponseDeck: View {
  let settings: DSPSettings
  let sampleRate: Float
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 6 : 9) {
      HStack {
        MixerTitle("RESPONSE", systemImage: "chart.xyaxis.line")
        Spacer()
        Text("Q 1.1")
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }
      FrequencyResponseView(settings: settings, sampleRate: sampleRate)
      HStack {
        Text("20 Hz")
        Spacer()
        Text("1 kHz")
        Spacer()
        Text("20 kHz")
      }
      .font(.caption2.monospacedDigit())
      .foregroundStyle(.tertiary)
    }
    .mixerPanel(compact: compact)
  }
}

private struct EqualizerDeck: View {
  @ObservedObject var model: AppModel
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 12) {
      HStack(spacing: 8) {
        MixerTitle("10-BAND EQ", systemImage: "slider.vertical.3")
        Text("\(model.sampleRate / 1_000, specifier: "%.1f") kHz")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
        Spacer()
        Button("Flat") { model.flattenEqualizer() }
          .controlSize(.small)
          .disabled(model.isRunning)
        Button {
          model.resetPreset()
        } label: {
          Image(systemName: "arrow.counterclockwise")
        }
        .controlSize(.small)
        .disabled(model.isRunning)
        .help("Reset the current preset")
      }

      HStack(alignment: .top, spacing: compact ? 3 : 8) {
        ForEach(EqualizerBand.allCases) { band in
          VStack(spacing: compact ? 4 : 6) {
            Text(String(format: "%+.1f", model.settings[band]))
              .font(.caption2.monospacedDigit())
              .foregroundStyle(model.settings[band] == 0 ? .secondary : .primary)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
            VerticalEQSlider(value: model.gainBinding(for: band), range: DSPSettings.equalizerRange)
              .disabled(model.isRunning)
            Text(band.label)
              .font((compact ? Font.caption2 : Font.caption).monospacedDigit().weight(.semibold))
            if !compact {
              Text("HZ")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .accessibilityElement(children: .contain)

      HStack {
        Text("−12 DB")
        Spacer()
        Text(model.isRunning ? "LOCKED DURING PLAYBACK" : "DRAG FADERS · 0.5 DB STEPS")
        Spacer()
        Text("+12 DB")
      }
      .font(.system(size: compact ? 8 : 9, weight: .medium, design: .monospaced))
      .foregroundStyle(.tertiary)
    }
    .mixerPanel(compact: compact)
  }
}

private struct MasterStrip: View {
  @ObservedObject var model: AppModel
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 12) {
      HStack {
        MixerTitle("MASTER", systemImage: "dial.medium")
        Spacer()
        Circle()
          .fill(model.isRunning ? Color.green : Color.secondary.opacity(0.35))
          .frame(width: 7, height: 7)
      }

      Picker("Sound profile", selection: $model.preset) {
        ForEach(SoundPreset.allCases) { preset in
          Text(preset.rawValue).tag(preset)
        }
      }
      .pickerStyle(.menu)
      .labelsHidden()
      .frame(maxWidth: .infinity)
      .disabled(model.isRunning)

      HStack(spacing: compact ? 5 : 10) {
        RotaryDial(
          title: "WIDTH",
          value: $model.settings.width,
          range: 1...1.65,
          format: "%.2f×",
          accent: .cyan,
          compact: compact
        )
        RotaryDial(
          title: "BOOST",
          value: $model.settings.inputGainDB,
          range: 0...5,
          format: "%+.1f dB",
          accent: .orange,
          compact: compact
        )
        RotaryDial(
          title: "DRIVE",
          value: $model.settings.saturation,
          range: 0...0.2,
          format: "%.0f%%",
          displayScale: 500,
          accent: .purple,
          compact: compact
        )
      }
      .disabled(model.isRunning)

      Divider()

      VStack(alignment: .leading, spacing: 5) {
        chainItem("EQ", active: true)
        chainItem("STEREO", active: model.settings.width > 1.001)
        chainItem("DYNAMICS", active: true)
        chainItem("LIMIT −1 DBFS", active: true)
      }

      Spacer(minLength: 0)

      if let error = model.errorMessage {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption2)
          .foregroundStyle(.red)
          .lineLimit(2)
          .textSelection(.enabled)
      } else {
        Text(
          model.isRunning
            ? "Controls locked for a pop-free session"
            : "Settings engage when sound starts"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
      }
    }
    .mixerPanel(compact: compact)
  }

  private func chainItem(_ title: String, active: Bool) -> some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(active ? Color.green : Color.secondary.opacity(0.3))
        .frame(width: 4, height: 11)
      Text(title)
        .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(active ? .primary : .secondary)
      Spacer()
    }
  }
}

private struct RotaryDial: View {
  let title: String
  @Binding var value: Float
  let range: ClosedRange<Float>
  let format: String
  var displayScale: Float = 1
  let accent: Color
  let compact: Bool
  @Environment(\.isEnabled) private var isEnabled
  @State private var dragStart: Float?

  var body: some View {
    VStack(spacing: compact ? 3 : 5) {
      Text(title)
        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
        .foregroundStyle(.secondary)
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [Color(nsColor: .controlColor), Color.black.opacity(0.82)],
              center: .topLeading,
              startRadius: 1,
              endRadius: compact ? 38 : 48
            )
          )
          .overlay(Circle().stroke(.separator.opacity(0.8), lineWidth: 1))
          .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
        Capsule()
          .fill(isEnabled ? accent : Color.secondary)
          .frame(width: 2.5, height: compact ? 13 : 16)
          .offset(y: compact ? -13 : -16)
          .rotationEffect(.degrees(angle))
      }
      .frame(width: compact ? 42 : 52, height: compact ? 42 : 52)
      .contentShape(Circle())
      .gesture(dragGesture)
      Text(String(format: format, value * displayScale))
        .font(.system(size: compact ? 9 : 10, weight: .medium, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement()
    .accessibilityLabel(title)
    .accessibilityValue(String(format: format, value * displayScale))
    .accessibilityAdjustableAction { direction in
      let step = (range.upperBound - range.lowerBound) / 20
      let delta: Float = direction == .increment ? step : -step
      value = min(max(value + delta, range.lowerBound), range.upperBound)
    }
  }

  private var angle: Double {
    let fraction = Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    return -135 + fraction * 270
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        guard isEnabled else { return }
        if dragStart == nil { dragStart = value }
        guard let dragStart else { return }
        let span = range.upperBound - range.lowerBound
        let candidate = dragStart - Float(gesture.translation.height / 120) * span
        value = min(max(candidate, range.lowerBound), range.upperBound)
      }
      .onEnded { _ in dragStart = nil }
  }
}

private struct VerticalEQSlider: View {
  @Binding var value: Float
  let range: ClosedRange<Float>
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    GeometryReader { proxy in
      let travel = max(proxy.size.height - 20, 1)
      let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
      let knobY = 10 + travel * (1 - progress)
      let zeroY = 10 + travel / 2

      ZStack {
        ForEach(0..<9, id: \.self) { tick in
          Rectangle()
            .fill(tick == 4 ? Color.secondary.opacity(0.7) : Color.secondary.opacity(0.25))
            .frame(width: tick == 4 ? 22 : 13, height: 1)
            .position(
              x: proxy.size.width / 2,
              y: 10 + travel * CGFloat(tick) / 8
            )
        }
        Capsule()
          .fill(Color.black.opacity(0.68))
          .overlay(Capsule().stroke(.separator.opacity(0.7), lineWidth: 0.5))
          .frame(width: 7, height: travel)
        Capsule()
          .fill(isEnabled ? Color.accentColor.opacity(0.9) : Color.secondary.opacity(0.35))
          .frame(width: 4, height: abs(knobY - zeroY))
          .position(x: proxy.size.width / 2, y: (knobY + zeroY) / 2)
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .fill(isEnabled ? Color(nsColor: .controlColor) : Color.secondary.opacity(0.75))
          .overlay(
            VStack(spacing: 2) {
              Rectangle().fill(.white.opacity(0.5)).frame(height: 1)
              Rectangle().fill(.black.opacity(0.55)).frame(height: 1)
            }
            .padding(.horizontal, 4)
          )
          .overlay(RoundedRectangle(cornerRadius: 3).stroke(.separator, lineWidth: 0.7))
          .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
          .frame(width: min(max(proxy.size.width - 8, 22), 34), height: 18)
          .position(x: proxy.size.width / 2, y: knobY)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { gesture in
          guard isEnabled else { return }
          let position = min(max(gesture.location.y - 10, 0), travel)
          let fraction = Float(1 - position / travel)
          let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
          value = (raw * 2).rounded() / 2
        }
      )
    }
    .frame(minWidth: 24, maxHeight: .infinity)
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
      let plot = CGRect(
        x: 27, y: 6, width: max(size.width - 32, 1), height: max(size.height - 10, 1))

      for decibels in stride(from: -12, through: 12, by: 6) {
        let y = yPosition(Float(decibels), in: plot)
        var line = Path()
        line.move(to: CGPoint(x: plot.minX, y: y))
        line.addLine(to: CGPoint(x: plot.maxX, y: y))
        context.stroke(
          line,
          with: .color(decibels == 0 ? .secondary.opacity(0.5) : .secondary.opacity(0.16)),
          lineWidth: decibels == 0 ? 1 : 0.5
        )
        context.draw(
          Text(decibels == 0 ? "0" : String(format: "%+d", decibels))
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.secondary),
          at: CGPoint(x: 11, y: y)
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
          Gradient(colors: [.cyan.opacity(0.3), .cyan.opacity(0.015)]),
          startPoint: CGPoint(x: 0, y: plot.minY),
          endPoint: CGPoint(x: 0, y: plot.maxY)
        )
      )
      context.stroke(
        curve,
        with: .color(.cyan),
        style: StrokeStyle(lineWidth: 2, lineJoin: .round)
      )
    }
    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
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

private struct WaveformCanvas: View {
  let snapshot: WaveformSnapshot

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 6)
      for amplitude: Float in [-1, -0.5, 0, 0.5, 1] {
        let y = rect.midY - CGFloat(amplitude) * rect.height / 2
        var line = Path()
        line.move(to: CGPoint(x: rect.minX, y: y))
        line.addLine(to: CGPoint(x: rect.maxX, y: y))
        context.stroke(
          line,
          with: .color(.secondary.opacity(amplitude == 0 ? 0.34 : 0.13)),
          lineWidth: amplitude == 0 ? 1 : 0.5
        )
      }
      draw(samples: snapshot.left, color: .cyan, in: rect, context: &context)
      draw(samples: snapshot.right, color: .purple.opacity(0.9), in: rect, context: &context)
    }
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.45), Color.black.opacity(0.24)],
        startPoint: .top,
        endPoint: .bottom
      ),
      in: RoundedRectangle(cornerRadius: 7)
    )
    .clipShape(RoundedRectangle(cornerRadius: 7))
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

private struct MixerTitle: View {
  let title: String
  let systemImage: String

  init(_ title: String, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 11, weight: .bold, design: .rounded))
      .tracking(0.6)
  }
}

private struct MixerPanelStyle: ViewModifier {
  let compact: Bool

  func body(content: Content) -> some View {
    content
      .padding(compact ? 10 : 14)
      .background(
        LinearGradient(
          colors: [
            Color(nsColor: .controlBackgroundColor).opacity(0.96), Color.black.opacity(0.12),
          ],
          startPoint: .top,
          endPoint: .bottom
        ),
        in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous)
          .stroke(.separator.opacity(0.7), lineWidth: 0.6)
      )
      .shadow(color: .black.opacity(0.12), radius: 7, y: 3)
  }
}

extension View {
  fileprivate func mixerPanel(compact: Bool) -> some View {
    modifier(MixerPanelStyle(compact: compact))
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

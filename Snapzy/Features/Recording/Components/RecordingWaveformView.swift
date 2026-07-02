//
//  RecordingWaveformView.swift
//  Snapzy
//
//  Ambient ocean-style waveform rendered behind the recording status bar. Amplitude
//  is driven by the live audio level (0...1); the wave flattens when silent and
//  freezes when inactive (paused). Pure-render Canvas — no @State mutation, no
//  .drawingGroup()/.blur(), capped at ~30fps to protect recording performance.
//

import SwiftUI

struct RecordingWaveformView: View {
  /// Smoothed audio level in `0...1` from `RecordingAudioLevelMeter`.
  let level: Float
  /// When false (paused / not recording), the wave flattens and stops travelling.
  var isActive: Bool = true

  @Environment(\.colorScheme) private var colorScheme

  /// Fraction of height the tallest peak may occupy (keeps controls legible).
  private let maxAmplitudeFraction: CGFloat = 0.35
  // Baseline sits low so the glow rises from the bottom edge of the bar.
  private let baselineFraction: CGFloat = 0.72
  private let step: CGFloat = 3

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
      Canvas { context, size in
        let t = timeline.date.timeIntervalSinceReferenceDate
        let amp = isActive ? CGFloat(level) : 0
        let path = wavePath(in: size, time: t, amplitude: amp)
        let baseline = size.height * baselineFraction
        context.fill(
          path,
          with: .linearGradient(
            waveGradient,
            startPoint: CGPoint(x: 0, y: baseline - size.height * maxAmplitudeFraction),
            endPoint: CGPoint(x: 0, y: size.height)
          )
        )
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  // MARK: - Geometry

  private func wavePath(in size: CGSize, time: Double, amplitude: CGFloat) -> Path {
    let baseline = size.height * baselineFraction
    let peak = size.height * maxAmplitudeFraction
    var path = Path()
    path.move(to: CGPoint(x: 0, y: baseline))

    var x: CGFloat = 0
    while x <= size.width {
      let xNorm = size.width > 0 ? x / size.width : 0
      let y = baseline - waveHeight(xNorm, time: time, amplitude: amplitude) * peak
      path.addLine(to: CGPoint(x: x, y: y))
      x += step
    }
    // Ensure the final sample lands exactly on the trailing edge.
    let lastNorm: CGFloat = 1
    let lastY = baseline - waveHeight(lastNorm, time: time, amplitude: amplitude) * peak
    path.addLine(to: CGPoint(x: size.width, y: lastY))

    // Close down to the bottom for a filled glow.
    path.addLine(to: CGPoint(x: size.width, y: size.height))
    path.addLine(to: CGPoint(x: 0, y: size.height))
    path.closeSubpath()
    return path
  }

  /// Superimposed travelling sines → organic ocean interference. Scaled by amplitude.
  private func waveHeight(_ xNorm: CGFloat, time: Double, amplitude: CGFloat) -> CGFloat {
    let twoPi = CGFloat.pi * 2
    let t = CGFloat(time)
    let w1 = sin(xNorm * twoPi * 1.0 + t * 1.6) * 0.60
    let w2 = sin(xNorm * twoPi * 2.3 + t * 2.1 + 1.2) * 0.30
    let w3 = sin(xNorm * twoPi * 3.7 + t * 2.7 + 2.4) * 0.10
    return (w1 + w2 + w3) * amplitude
  }

  // MARK: - Theming

  private var waveGradient: Gradient {
    colorScheme == .dark
      ? Gradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.02)])
      : Gradient(colors: [Color.accentColor.opacity(0.24), Color.accentColor.opacity(0.04)])
  }
}

#if DEBUG
  private struct RecordingWaveformPreview: View {
    @State private var level: Double = 0.5
    @State private var isActive = true

    var body: some View {
      VStack(spacing: 16) {
        ForEach([ColorScheme.light, ColorScheme.dark], id: \.self) { scheme in
          RecordingWaveformView(level: Float(level), isActive: isActive)
            .frame(width: 340, height: 36)
            .background(scheme == .dark ? Color.black : Color.white)
            .overlay(Text("00:12  ●  Stop").font(.system(size: 13)))
            .cornerRadius(14)
            .environment(\.colorScheme, scheme)
        }
        Slider(value: $level, in: 0 ... 1)
        Toggle("Active", isOn: $isActive)
      }
      .padding()
      .frame(width: 380)
    }
  }

  #Preview {
    RecordingWaveformPreview()
  }
#endif

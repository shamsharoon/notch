import SwiftUI

private let rowHeight: CGFloat = 30
private let rowSpacing: CGFloat = 2
private let rowInset: CGFloat = 8

/// The Mixer rows, shared by the notch tab and the menu bar panel.
/// It fills the height it is given (the open notch) and otherwise sizes to
/// its rows (the menu bar panel), scrolling past 360 points.
struct MixerList: View {
    @ObservedObject var model = MixerModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.visibleApps.isEmpty {
                Text("Nothing is playing")
                    .font(.callout)
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                let count = CGFloat(model.visibleApps.count)
                ScrollView {
                    VStack(spacing: rowSpacing) {
                        ForEach(model.visibleApps) { app in
                            MixerRow(app: app, setting: model.setting(for: app.id))
                                .transition(rowTransition)
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(idealHeight: count * rowHeight + (count - 1) * rowSpacing, maxHeight: 360)
                // Hover highlights reach past the edge; row content stays aligned.
                .padding(.horizontal, -rowInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.mixerEntrance, value: model.visibleApps.map(\.id))
    }

    private var rowTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity)
    }
}

private struct MixerRow: View {
    let app: AudioApp
    let setting: MixerSetting
    @State private var dragging = false
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var percent: Int {
        return Int((setting.volume * 100).rounded())
    }

    private var percentOpacity: Double {
        if dragging {
            return 0.85
        }
        if setting.volume < 1 {
            return 0.55
        }
        return 0.4
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 18, height: 18)

                HStack(spacing: 5) {
                    Text(app.name)
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineLimit(1)
                    PlayingIndicator(isPlaying: app.isPlaying)
                }
                .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                    return min(width * 0.34, 160)
                }

                MixerSlider(value: setting.volume, dragging: $dragging) { value in
                    MixerModel.shared.setVolume(value, for: app.id)
                }

                Text("\(percent)%")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(percent)))
                    .foregroundStyle(Color.primary.opacity(percentOpacity))
                    .frame(width: 32, alignment: .trailing)
                    .onTapGesture(count: 2) {
                        withAnimation(.mixerEntrance) {
                            MixerModel.shared.setVolume(1, for: app.id)
                        }
                    }
                    .help("Double-click for 100%")
            }
            .opacity(setting.muted ? 0.45 : 1)

            Button {
                MixerModel.shared.toggleMute(app.id)
            } label: {
                Image(systemName: setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary.opacity(setting.muted ? 0.85 : 0.55))
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HoverPressStyle(cornerRadius: 13, pressedScale: 0.88))
            .help(setting.muted ? "Unmute" : "Mute")
        }
        .font(.callout)
        .padding(.horizontal, rowInset)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(hovering ? 0.05 : 0))
        )
        .onHover { hovering = $0 }
        .animation(.mixerHover, value: hovering)
        .animation(.mixerHover, value: setting.muted)
        .animation(.mixerHover, value: dragging)
        .onChange(of: setting.volume) { oldValue, newValue in
            if dragging && newValue == 1 && oldValue < 1 {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }
}

/// Fades out during the grace period after the app goes quiet.
private struct PlayingIndicator: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.green)
            .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isPlaying && !reduceMotion)
            .opacity(isPlaying ? 1 : 0)
    }
}

/// The notch's CustomSlider look, but thinner at rest because the Mixer
/// stacks several sliders.
private struct MixerSlider: View {
    let value: Double
    @Binding var dragging: Bool
    let onChange: (Double) -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trackHeight: CGFloat {
        if dragging {
            return 8
        }
        if hovering {
            return 6
        }
        return 4
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: width * min(max(value, 0), 1))
            }
            .frame(height: trackHeight)
            .clipShape(Capsule())
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        dragging = true
                        onChange(min(max(gesture.location.x / width, 0), 1))
                    }
                    .onEnded { _ in
                        dragging = false
                    }
            )
        }
        .frame(height: 20)
        .onHover { hovering = $0 }
        .pointingHand()
        .animation(reduceMotion ? nil : .mixerHover, value: trackHeight)
    }
}

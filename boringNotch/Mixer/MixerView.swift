import SwiftUI

private let rowHeight: CGFloat = 30
private let rowSpacing: CGFloat = 4

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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.mixerEntrance, value: model.visibleApps.map(\.id))
    }

    /// Rows rise 6 points as they fade in, and only fade under Reduce Motion.
    private var rowTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity)
    }
}

extension Animation {
    static let mixerEntrance = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.2)
}

private struct MixerRow: View {
    let app: AudioApp
    let setting: MixerSetting
    @State private var dragging = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 18, height: 18)

            HStack(spacing: 4) {
                Text(app.name)
                    .lineLimit(1)
                if app.isPlaying {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .help("Playing sound")
                }
            }
            .frame(width: 100, alignment: .leading)

            Text(setting.muted ? "Muted" : "\(Int((setting.volume * 100).rounded()))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            CustomSlider(
                value: Binding(
                    get: { setting.volume },
                    set: { MixerModel.shared.setVolume($0, for: app.id) }
                ),
                range: 0...1,
                color: .primary,
                dragging: $dragging,
                lastDragged: .constant(Date.distantPast)
            )
            .frame(height: 10)
            .disabled(setting.muted)
            .opacity(setting.muted ? 0.4 : 1)

            HoverButton(icon: setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                MixerModel.shared.toggleMute(app.id)
            }
            .help(setting.muted ? "Unmute" : "Mute")
        }
        .font(.callout)
        .frame(height: rowHeight)
        .opacity(app.isPlaying ? 1 : 0.75)
    }
}

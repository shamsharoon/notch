import SwiftUI

extension Animation {
    static let mixerHover = Animation.easeOut(duration: 0.15)
    static let mixerEntrance = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.2)
}

/// Soft hover background, press feedback, and a pointing-hand cursor, shared
/// by the Mixer's mute buttons and the menu bar panel's rows.
struct HoverPressStyle: ButtonStyle {
    var cornerRadius: CGFloat
    var pressedScale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        HoverPressBody(configuration: configuration, cornerRadius: cornerRadius, pressedScale: pressedScale)
    }
}

private struct HoverPressBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let pressedScale: CGFloat
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0))
            )
            .scaleEffect(pressed && !reduceMotion ? pressedScale : 1)
            .opacity(pressed ? 0.7 : 1)
            .onHover { hovering = $0 }
            .pointingHand()
            .animation(.mixerHover, value: hovering)
            .animation(.mixerHover, value: pressed)
    }
}

extension View {
    /// SwiftUI pointer styles need macOS 15. On 14 the cursor stays an arrow.
    @ViewBuilder
    func pointingHand() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.link)
        } else {
            self
        }
    }
}

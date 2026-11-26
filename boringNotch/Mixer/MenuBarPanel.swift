import SwiftUI

struct MenuBarPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MixerList()

            Divider()

            VStack(spacing: 0) {
                PanelButton(title: "Settings") {
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.showWindow()
                    }
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)

                PanelButton(title: "Restart Notch") {
                    ApplicationRelauncher.restart()
                }

                PanelButton(title: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(KeyEquivalent("q"), modifiers: .command)
            }
            .padding(.horizontal, -8)
        }
        .padding(14)
        .frame(width: 360)
    }
}

private struct PanelButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    hovering ? Color.primary.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

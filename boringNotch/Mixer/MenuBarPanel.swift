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
        .frame(width: 380)
    }
}

private struct PanelButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverPressStyle(cornerRadius: 6))
    }
}

import SwiftUI

@main
struct KnobApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Knob", systemImage: appState.status.icon) {
            Text(appState.status.label)
            Divider()
            Text("Model: small.en")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: DisplayStateViewModel
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.toggle()
            } label: {
                Text(viewModel.isInternalDisplayOff ? "Turn On Built-in Display" : "Turn Off Built-in Display")
            }

            if let error = viewModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                }

            Divider()

            Button("Quit Blackout") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

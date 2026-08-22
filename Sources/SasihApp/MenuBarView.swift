import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: DisplayStateViewModel
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    private var statusColor: Color {
        viewModel.isInternalDisplayOff ? .orange : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.isInternalDisplayOff ? "Internal display is off" : "Internal display is on")
                    .font(.subheadline)
            }

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

            Button("Quit Sasih") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

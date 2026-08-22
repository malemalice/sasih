import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: DisplayStateViewModel
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { !viewModel.isInternalDisplayOff },
            set: { _ in viewModel.toggle() }
        )
    }

    /// Turning the display off requires an external one connected; turning
    /// it back on is always safe, so only the off-direction gets blocked.
    private var toggleDisabled: Bool {
        !viewModel.isInternalDisplayOff && !viewModel.hasExternalDisplay
    }

    private var statusCaption: String {
        viewModel.isInternalDisplayOff ? "Built-in display is off" : "Built-in display is on"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            displayRow

            if toggleDisabled {
                Text("Connect an external display to turn this off.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else if let error = viewModel.lastError {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            Divider()

            launchAtLoginRow

            Divider()
                .padding(.vertical, 4)

            MenuRow(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit Sasih")
                    .font(.system(size: 13))
            }
            .padding(.bottom, 4)
        }
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sasih")
                    .font(.system(size: 13, weight: .semibold))
                Text(statusCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var displayRow: some View {
        HStack {
            Text("Built-in Display")
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(toggleDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var launchAtLoginRow: some View {
        HStack {
            Text("Launch at Login")
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $launchAtLoginEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: launchAtLoginEnabled) { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// A full-width row that highlights on hover, matching how native macOS
/// menu items behave — plain SwiftUI Buttons don't do this on their own.
private struct MenuRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                content()
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

import SwiftUI

@main
struct SasihApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: appDelegate.viewModel)
        } label: {
            MenuBarIcon(viewModel: appDelegate.viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIcon: View {
    @ObservedObject var viewModel: DisplayStateViewModel

    var body: some View {
        // Full moon when the internal display is on, dark/new moon when it's
        // off — mirrors the toggle state the way the app's name already does.
        Image(systemName: viewModel.isInternalDisplayOff ? "moon" : "moon.fill")
            .accessibilityLabel(viewModel.isInternalDisplayOff ? "Sasih — internal display off" : "Sasih — internal display on")
    }
}

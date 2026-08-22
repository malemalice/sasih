import SwiftUI

@main
struct BlackoutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Blackout", systemImage: "moon.fill") {
            MenuBarView(viewModel: appDelegate.viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

import AppKit
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
        // Same gibbous-moon silhouette as the app icon — filled when the
        // display is on, outlined/hollow when it's off. The full, rounded
        // shape (vs. a thin crescent) keeps it from reading as the system
        // Do Not Disturb status icon while still matching the app's brand.
        Image(nsImage: MenuBarIcon.image(off: viewModel.isInternalDisplayOff))
            .accessibilityLabel(viewModel.isInternalDisplayOff ? "Sasih — internal display off" : "Sasih — internal display on")
    }

    private static func image(off: Bool) -> NSImage {
        let name = off ? "MenuBarIcon-off" : "MenuBarIcon-on"
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let image = NSImage(contentsOfFile: path) else {
            return NSImage()
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }
}

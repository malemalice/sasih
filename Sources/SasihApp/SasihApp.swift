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
        // A laptop glyph with the screen either outlined (display on) or
        // filled solid (display off) — a plain moon/crescent would be easy
        // to mistake for the system Do Not Disturb status icon, so the
        // status-bar glyph stays literal about what's being toggled while
        // the moon motif lives on the app icon instead.
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

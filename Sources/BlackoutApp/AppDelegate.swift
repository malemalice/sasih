import AppKit
import BlackoutCore
import CoreGraphics

private func displayReconfigurationCallback(
    display: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    // Ignore intermediate "begin configuration" events — only act once a
    // reconfiguration has actually settled, mirroring the reference
    // implementation's approach to avoid racing macOS's own display changes.
    guard !flags.contains(.beginConfigurationFlag) else { return }
    Task { @MainActor in
        delegate.handleDisplayReconfiguration()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let displayManager: DisplayManager
    let viewModel: DisplayStateViewModel

    private var backstopTimer: Timer?

    override init() {
        let manager = DisplayManager(
            configurer: PrivateAPIDisplayConfigurer(),
            infoProvider: CGDisplayInfoProvider(),
            idStore: DisplayIDStore()
        )
        self.displayManager = manager
        self.viewModel = DisplayStateViewModel(manager: manager)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Recover from a crash/force-quit that left the internal display off
        // in a previous session — before the user interacts with anything.
        displayManager.restoreOnLaunchIfNeeded()
        viewModel.refresh()

        registerDisplayReconfigurationCallback()
        registerSleepWakeObservers()
        startBackstopTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        displayManager.restoreBeforeQuit()
    }

    // MARK: - Safety nets

    private func registerDisplayReconfigurationCallback() {
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, userInfo)
    }

    private func registerSleepWakeObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func startBackstopTimer() {
        // Safety net: catches the case where the reconfiguration callback is
        // missed for any reason. Only meaningful while the internal display
        // is off, so a 10s interval is fine — no need to wake the CPU while idle.
        backstopTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleDisplayReconfiguration()
            }
        }
    }

    func handleDisplayReconfiguration() {
        displayManager.performEmergencyCheckIfNeeded()
        viewModel.refresh()
    }

    @objc private func handleWake() {
        // Give macOS a moment to finish its own display reconfiguration after
        // wake (it re-enables all displays as part of that) before re-applying
        // our state on top of it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.displayManager.handleWake()
            self?.viewModel.refresh()
        }
    }
}

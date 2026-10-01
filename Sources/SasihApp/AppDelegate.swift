import AppKit
import SasihCore
import CoreGraphics
import os

// See DisplayManager's logger note: every interpolated value needs
// `privacy: .public` or the unified log redacts it.
private let appDelegateLogger = Logger(subsystem: "com.adaptivid.sasih", category: "AppDelegate")

private func displayReconfigurationCallback(
    display: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    appDelegateLogger.notice("displayReconfigurationCallback: display=\(display, privacy: .public) flags=\(flags.rawValue, privacy: .public) beginFlag=\(flags.contains(.beginConfigurationFlag), privacy: .public)")
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
    private let touchBarRecovery: TouchBarRecovering
    private let stayAwake: StayAwake
    private let logger = appDelegateLogger

    private var backstopTimer: Timer?

    /// True while macOS has the screens in display sleep. No display is
    /// drawable in that state (including a perfectly healthy external), so
    /// emergency checks are deferred until the screens wake — otherwise every
    /// display-sleep cycle would read as "no external present" and silently
    /// cancel blackout.
    private var screensAreAsleep = false

    override init() {
        let manager = DisplayManager(
            configurer: PrivateAPIDisplayConfigurer(),
            infoProvider: CGDisplayInfoProvider(),
            idStore: DisplayIDStore()
        )
        self.displayManager = manager
        self.touchBarRecovery = TouchBarRecovery()
        self.stayAwake = StayAwake()
        self.viewModel = DisplayStateViewModel(manager: manager, touchBarRecovery: touchBarRecovery, stayAwake: stayAwake)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("applicationDidFinishLaunching")
        // Recover from a crash/force-quit that left the internal display off
        // in a previous session — before the user interacts with anything.
        displayManager.restoreOnLaunchIfNeeded()
        viewModel.refresh()
        stayAwake.applyPersistedPreference()

        registerDisplayReconfigurationCallback()
        registerSleepWakeObservers()
        startBackstopTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.notice("applicationWillTerminate")
        displayManager.restoreBeforeQuit()
        stayAwake.releaseIfNeeded()
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
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreensDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        registerDiagnosticObservers()
    }

    /// Purely diagnostic — these handlers only log. `didWakeNotification` fires
    /// for full *system* sleep only, so when the internal display's off-state is
    /// lost after a plain display sleep, we need to know which notifications (if
    /// any) actually fired. Nothing here may touch display state: adding state
    /// logic to these paths is a behavior change, and this build is meant to
    /// isolate exactly one.
    private func registerDiagnosticObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(logWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(logScreenLocked),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(logScreenUnlocked),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    private func startBackstopTimer() {
        // Safety net: catches the case where the reconfiguration callback is
        // missed for any reason. Only meaningful while the internal display
        // is off, so a 10s interval is fine — no need to wake the CPU while idle.
        backstopTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logger.notice("backstopTimer fired")
                self?.handleDisplayReconfiguration()
            }
        }
    }

    func handleDisplayReconfiguration() {
        displayManager.performEmergencyCheckIfNeeded(screensAreAsleep: screensAreAsleep)
        viewModel.refresh()
    }

    @objc private func handleScreensDidSleep() {
        screensAreAsleep = true
        logger.notice("screensDidSleepNotification: deferring emergency checks until screens wake")
    }

    @objc private func handleScreensDidWake() {
        screensAreAsleep = false
        logger.notice("screensDidWakeNotification: re-evaluating display state")
        // Give macOS a moment to finish waking the displays before reading the
        // active list; the reconfiguration callbacks firing around this time
        // pick the state up as well.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.handleDisplayReconfiguration()
        }
    }

    @objc private func logWillSleep() {
        logger.notice("willSleepNotification: isInternalDisplayOff=\(self.displayManager.isInternalDisplayOff, privacy: .public) externalDisplayCount=\(self.displayManager.externalDisplayCount, privacy: .public)")
    }

    @objc private func logScreenLocked() {
        logger.notice("screenIsLocked: isInternalDisplayOff=\(self.displayManager.isInternalDisplayOff, privacy: .public) externalDisplayCount=\(self.displayManager.externalDisplayCount, privacy: .public)")
    }

    @objc private func logScreenUnlocked() {
        logger.notice("screenIsUnlocked: isInternalDisplayOff=\(self.displayManager.isInternalDisplayOff, privacy: .public) externalDisplayCount=\(self.displayManager.externalDisplayCount, privacy: .public)")
    }

    @objc private func handleWake() {
        logger.notice("didWakeNotification received")
        // Defensive: screensDidWake usually precedes this, but never leave the
        // deferral flag stuck on across a system wake.
        screensAreAsleep = false
        // Give macOS a moment to finish its own display reconfiguration after
        // wake (it re-enables all displays as part of that) before re-applying
        // our state on top of it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.displayManager.handleWake()
            self?.viewModel.refresh()
            // Deliberately NOT nudging the Touch Bar here. TouchBarRecovery
            // works by shelling out to `pmset displaysleepnow` + `caffeinate`,
            // i.e. it synthesizes a display sleep/wake cycle — which in an app
            // driven by display-reconfiguration events feeds our own callbacks
            // back to us mid-wake. The nudge stays on the user-initiated toggle
            // path (DisplayStateViewModel.toggle), where it can't race the
            // automatic wake handling. Trade-off: after an *automatic* re-enable
            // the Touch Bar may stay blank until the user toggles once manually.
        }
    }
}

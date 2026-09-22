import CoreGraphics
import os

/// Single source of truth for "is the internal display off." All dependencies
/// are constructor-injected so this class is fully unit-testable with fakes —
/// it never calls dlopen/dlsym or queries real display hardware directly.
public final class DisplayManager {
    private let configurer: DisplayConfiguring
    private let infoProvider: DisplayInfoProviding
    private let idStore: DisplayIDPersisting

    // Diagnostics for the sleep/wake state-loss class of bug: every decision
    // point here is timing-dependent and impossible to reproduce under test,
    // so the unified log is the only way to see what actually happened.
    // Note: every interpolated value needs `privacy: .public` — without it the
    // log redacts them (arrays show up as `<private>`), which makes the output
    // useless for exactly the questions we need answered.
    private let logger = Logger(subsystem: "com.adaptivid.sasih", category: "DisplayManager")

    public private(set) var isInternalDisplayOff: Bool
    public private(set) var lastError: String?

    private var cachedInternalDisplayID: CGDirectDisplayID?

    /// True when the internal display is currently on only because we fell
    /// back to it (no external present when we needed to decide), not because
    /// the user chose it. Drives whether `performEmergencyCheckIfNeeded` may
    /// automatically turn it off again once an external display reappears.
    /// In-memory only — a fresh launch has no fallback to reconcile.
    private var internalOnIsFallback = false

    /// User preference: automatically restore "internal off" once an external
    /// display reconnects after we fell back to the internal display.
    public var autoRevertOnReconnectEnabled: Bool {
        get { idStore.loadAutoRevertOnReconnect() }
        set { idStore.saveAutoRevertOnReconnect(newValue) }
    }

    public init(
        configurer: DisplayConfiguring,
        infoProvider: DisplayInfoProviding,
        idStore: DisplayIDPersisting
    ) {
        self.configurer = configurer
        self.infoProvider = infoProvider
        self.idStore = idStore
        self.cachedInternalDisplayID = idStore.load()
        self.isInternalDisplayOff = idStore.loadOffState()
        logger.notice("init: cachedInternalDisplayID=\(String(describing: self.cachedInternalDisplayID), privacy: .public) isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public)")
    }

    public var externalDisplayCount: Int {
        infoProvider.externalDisplayCount()
    }

    /// Externals the user can actually see: online *and* drawable. This is the
    /// predicate every blackout/restore decision uses (see
    /// `DisplayInfoProviding.usableExternalDisplayCount`).
    public var usableExternalDisplayCount: Int {
        infoProvider.usableExternalDisplayCount()
    }

    @discardableResult
    public func disableInternalDisplay() -> Bool {
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let activeIDs = infoProvider.activeDisplayIDs()
        let usableExternalCount = infoProvider.usableExternalDisplayCount()
        logger.notice("disableInternalDisplay: onlineIDs=\(onlineIDs, privacy: .public) activeIDs=\(activeIDs, privacy: .public) usableExternalCount=\(usableExternalCount, privacy: .public)")

        // Already off — e.g. macOS dropped the panel across a sleep/wake, or a
        // previous session left it off. Never issue a hardware call for a
        // display that isn't online; just make the recorded state agree.
        guard isInternalDisplayOnline(in: onlineIDs) else {
            isInternalDisplayOff = true
            idStore.saveOffState(true)
            lastError = nil
            logger.notice("disableInternalDisplay: internal display already offline — recording off state")
            return true
        }

        guard DisplayGuards.canDisableInternal(usableExternalDisplayCount: usableExternalCount) else {
            lastError = "No external display detected."
            logger.notice("disableInternalDisplay: refused — no drawable external display (onlineIDs=\(onlineIDs, privacy: .public) activeIDs=\(activeIDs, privacy: .public))")
            return false
        }
        guard !DisplayGuards.isLastActiveDisplay(activeDisplayCount: activeIDs.count) else {
            lastError = "Refusing to disable the last active display."
            logger.notice("disableInternalDisplay: refused — would be the last active display")
            return false
        }
        guard let internalID = resolveInternalDisplayID(from: onlineIDs) else {
            lastError = "Could not find internal display ID."
            logger.notice("disableInternalDisplay: failed — could not resolve internal display ID")
            return false
        }

        idStore.save(internalID)
        cachedInternalDisplayID = internalID

        guard configurer.setDisplay(internalID, enabled: false) else {
            lastError = "Failed to disable internal display."
            logger.notice("disableInternalDisplay: internalID=\(internalID, privacy: .public) setDisplay(false) FAILED")
            return false
        }

        isInternalDisplayOff = true
        idStore.saveOffState(true)
        lastError = nil
        logger.notice("disableInternalDisplay: internalID=\(internalID, privacy: .public) disabled successfully")
        return true
    }

    @discardableResult
    public func enableInternalDisplay() -> Bool {
        guard let internalID = cachedInternalDisplayID ?? idStore.load() else {
            lastError = "Internal display ID unknown — cannot restore."
            logger.notice("enableInternalDisplay: failed — internal display ID unknown")
            return false
        }

        guard configurer.setDisplay(internalID, enabled: true) else {
            lastError = "Failed to enable internal display."
            logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) setDisplay(true) FAILED")
            return false
        }

        isInternalDisplayOff = false
        idStore.saveOffState(false)
        lastError = nil
        logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) enabled successfully")
        return true
    }

    public func toggle() {
        logger.notice("toggle: isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public) (before)")
        // A manual toggle is always a deliberate choice — it overrides
        // whatever fallback state we were tracking.
        internalOnIsFallback = false
        if isInternalDisplayOff {
            enableInternalDisplay()
        } else {
            disableInternalDisplay()
        }
    }

    /// Call periodically (safety-net timer) and on every display-reconfiguration
    /// event. If the internal display is off and no *drawable* external is
    /// present, restore immediately — this is the top-priority correctness
    /// guarantee of the app. Also the counterpart reconciliation: if the
    /// internal display is only on because we fell back to it, and a drawable
    /// external has since reappeared, turn it back off — subject to the user's
    /// auto-revert preference.
    ///
    /// `screensAreAsleep` must be true while macOS has the screens in display
    /// sleep: then *no* display is drawable (including a perfectly healthy
    /// external), and acting on that snapshot would cancel blackout on every
    /// display-sleep cycle. AppDelegate tracks it via the screensDidSleep/Wake
    /// notifications and re-runs this check right after the screens wake.
    ///
    /// Note on the zero-count case: an empty online list is the *intended*
    /// signature of a genuine unplug (see CGDisplayInfoProvider — WindowServer
    /// leaves only a synthetic placeholder, which is filtered out). It can also
    /// occur transiently mid-reconfiguration, so the logging below records the
    /// lists that drove the decision.
    public func performEmergencyCheckIfNeeded(screensAreAsleep: Bool = false) {
        // One snapshot, so the logged lists and the counts that drive the
        // decision below can never disagree about which instant they describe.
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let usableExternalCount = infoProvider.usableExternalDisplayCount()
        logger.notice("performEmergencyCheckIfNeeded: isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public) internalOnIsFallback=\(self.internalOnIsFallback, privacy: .public) screensAreAsleep=\(screensAreAsleep, privacy: .public) onlineIDs=\(onlineIDs, privacy: .public) usableExternalCount=\(usableExternalCount, privacy: .public) cachedInternalDisplayID=\(String(describing: self.cachedInternalDisplayID), privacy: .public)")

        guard !screensAreAsleep else {
            logger.notice("performEmergencyCheckIfNeeded: screens asleep — deferring (no state change)")
            return
        }

        // The panel being absent from the online list is ground truth that it
        // is off. Record that instead of trusting the recorded on-state: the
        // reapply-off below would otherwise call disableInternalDisplay() for
        // an already-off panel, the last-active-display guard would refuse it
        // forever, and the fallback flag would never clear. A drawable external
        // outside the fallback window is still ignored, since the online list
        // can transiently omit the panel mid-reconfiguration — but a merely
        // listed (non-drawable) external must not hold the recorded state on.
        if !isInternalDisplayOnline(in: onlineIDs), !isInternalDisplayOff,
           (usableExternalCount == 0 || internalOnIsFallback) {
            logger.notice("performEmergencyCheckIfNeeded: panel offline while state said on — reconciling to off")
            isInternalDisplayOff = true
            idStore.saveOffState(true)
            internalOnIsFallback = false
        }

        if isInternalDisplayOff {
            guard usableExternalCount == 0 else {
                logger.notice("performEmergencyCheckIfNeeded: drawable external present — nothing to do")
                return
            }
            logger.notice("performEmergencyCheckIfNeeded: no drawable external present — restoring internal")
            internalOnIsFallback = true
            enableInternalDisplay()
            return
        }

        guard internalOnIsFallback, autoRevertOnReconnectEnabled, usableExternalCount > 0 else { return }
        logger.notice("performEmergencyCheckIfNeeded: drawable external reconnected after fallback — reapplying off")
        if disableInternalDisplay() {
            internalOnIsFallback = false
        }
    }

    /// Call on wake from sleep. Reads the persisted off-state rather than a
    /// caller-supplied snapshot, since disable/enable already keep that state
    /// current at all times.
    public func handleWake() {
        let wasOff = idStore.loadOffState()
        // A drawable external is required to re-apply blackout: a stale/ghost
        // entry in the online list must not black out the panel macOS just
        // restored. If the external enumerates late, this falls back to
        // `leaveOn` and auto-revert re-applies once it is actually drawable.
        let usableExternalCount = infoProvider.usableExternalDisplayCount()
        let externalPresent = usableExternalCount > 0
        let action = SleepWakeDecision.wakeAction(wasOffBeforeSleep: wasOff, externalPresentOnWake: externalPresent)
        logger.notice("handleWake: wasOff=\(wasOff, privacy: .public) usableExternalCount=\(usableExternalCount, privacy: .public) externalPresent=\(externalPresent, privacy: .public) action=\(String(describing: action), privacy: .public)")
        switch action {
        case .reapplyOff:
            disableInternalDisplay()
        case .leaveOn:
            internalOnIsFallback = true
            if isInternalDisplayOnline(in: infoProvider.onlineDisplayIDs()) {
                isInternalDisplayOff = false
                idStore.saveOffState(false)
            } else {
                // macOS re-enables displays as part of wake, but not always
                // reliably — the exact state-loss case this app exists for.
                // Restore it ourselves; if that fails, leave the off-state
                // recorded so the emergency check and launch restore keep
                // retrying rather than trusting an assumption.
                logger.notice("handleWake: macOS did not restore the internal display — restoring explicitly")
                enableInternalDisplay()
            }
        case .doNothing:
            break
        }
    }

    /// Call once at app startup, before any UI is shown. Recovers from a
    /// crash/force-quit that left the internal display off in a previous session.
    public func restoreOnLaunchIfNeeded() {
        guard idStore.loadOffState() else { return }
        logger.notice("restoreOnLaunchIfNeeded: previous session left internal off — restoring")
        cachedInternalDisplayID = idStore.load()
        enableInternalDisplay()
    }

    /// Call before the app quits normally — never leave the internal display off.
    public func restoreBeforeQuit() {
        guard isInternalDisplayOff else { return }
        logger.notice("restoreBeforeQuit: restoring internal display before quit")
        enableInternalDisplay()
    }

    private func isInternalDisplayOnline(in onlineIDs: [CGDirectDisplayID]) -> Bool {
        onlineIDs.contains(where: infoProvider.isBuiltin)
    }

    private func resolveInternalDisplayID(from onlineIDs: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        onlineIDs.first(where: infoProvider.isBuiltin) ?? cachedInternalDisplayID
    }
}
